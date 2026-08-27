import Factory
import StoreKit
import SwiftUI

/// The only place in the app that calls `requestReview()`.
///
/// The coordinator decides *whether* to ask; this decides *when* on screen. Keeping
/// StoreKit here means the decision logic stays free of UI dependencies and can be unit
/// tested.
private struct ReviewPromptPresenter: ViewModifier {
  @Environment(\.requestReview) private var requestReview
  @Injected(\.reviewPromptCoordinator) private var coordinator
  @Injected(\.authSessionStore) private var authSessionStore

  func body(content: Content) -> some View {
    content
      .onChange(of: coordinator.pendingPrompt) { _, isPending in
        guard isPending else { return }

        // Let the moment that earned the prompt finish rendering — the celebratory card,
        // the streak animation — before the system sheet covers it.
        Task {
          try? await Task.sleep(for: .seconds(1.2))
          let userID = await authSessionStore.currentUserID
          guard !userID.isEmpty, coordinator.pendingPrompt else { return }
          requestReview()
          coordinator.markPromptShown(userID: userID)
        }
      }
  }
}

extension View {
  /// Attach once, to the root tab view. Presents the system review prompt whenever the
  /// coordinator has decided one has been earned.
  func reviewPromptPresenter() -> some View {
    modifier(ReviewPromptPresenter())
  }
}
