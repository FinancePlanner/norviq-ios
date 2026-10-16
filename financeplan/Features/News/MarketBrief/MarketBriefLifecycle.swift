import Factory
import SwiftUI

/// Loads and refreshes the market brief for the view it is attached to, and
/// hands it pushes and links from `MarketBriefRouter`.
///
/// It sits on the dashboard column rather than on the card, because the card
/// renders nothing until a brief exists and a task on nothing never runs.
struct MarketBriefLifecycle: ViewModifier {
  let viewModel: MarketBriefViewModel

  @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
  @Environment(\.scenePhase) private var scenePhase
  @InjectedObservable(\Container.marketBriefRouter) private var router

  /// Two briefs a day; a quarter of an hour keeps a long-open app current
  /// without polling.
  private let refreshInterval: TimeInterval = 15 * 60

  private var language: String {
    AppLanguage.from(appLanguageRawValue).rawValue
  }

  func body(content: Content) -> some View {
    content
      .task(id: language) {
        await viewModel.loadIfNeeded(language: language)
        await viewModel.refreshIfStale(maxAge: refreshInterval)
      }
      .onChange(of: router.pendingRequest, initial: true) { _, request in
        guard request != nil, let pending = router.consume() else { return }
        Task { await viewModel.handle(pending) }
      }
      .onChange(of: router.publishedCount) {
        Task { await viewModel.refresh() }
      }
      .onChange(of: scenePhase) { _, phase in
        guard phase == .active else { return }
        Task { await viewModel.refreshIfStale(maxAge: refreshInterval) }
      }
  }
}

extension View {
  func marketBriefLifecycle(_ viewModel: MarketBriefViewModel) -> some View {
    modifier(MarketBriefLifecycle(viewModel: viewModel))
  }
}
