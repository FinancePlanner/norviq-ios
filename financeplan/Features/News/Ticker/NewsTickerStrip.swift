import StockPlanShared
import SwiftUI

/// The dashboard ticker: one glass card, headlines cycling one at a time.
/// Reduce Motion turns the cycle into a short static list. Tapping opens the
/// publisher; nothing is republished here.
struct NewsTickerStrip: View {
  @Bindable var viewModel: NewsTickerViewModel
  @Environment(\.openURL) private var openURL
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var index = 0

  private let rotation: TimeInterval = 6
  private let refreshInterval: TimeInterval = 300

  var body: some View {
    Group {
      if viewModel.shouldShow {
        GlassCard {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
              Image(systemName: "dot.radiowaves.left.and.right")
                .font(.caption)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
              Text(LocalizedStringKey("Breaking news"))
                .typography(.nano, weight: .semibold)
                .foregroundStyle(.secondary)
              if viewModel.isStale {
                Text(LocalizedStringKey("Updated earlier"))
                  .typography(.nano)
                  .foregroundStyle(.tertiary)
              }
              Spacer()
              NavigationLink {
                NewsTickerSettingsView(viewModel: viewModel)
              } label: {
                Image(systemName: "slider.horizontal.3")
                  .font(.caption)
                  .foregroundStyle(.tertiary)
              }
              .buttonStyle(.plain)
              .accessibilityLabel(Text(LocalizedStringKey("News ticker settings")))
            }

            if reduceMotion {
              VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.items.prefix(3)) { item in
                  headlineRow(item)
                }
              }
            } else if let item = current {
              headlineRow(item)
                .id(item.id)
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
            }
          }
        }
        .appAnimation(AppMotion.state, value: index)
        .task(id: viewModel.items.count) {
          guard !reduceMotion, viewModel.items.count > 1 else { return }
          while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(rotation))
            guard !viewModel.items.isEmpty else { return }
            index = (index + 1) % viewModel.items.count
          }
        }
      }
    }
    .task {
      await viewModel.loadFromCache()
      await viewModel.refreshIfStale(maxAge: refreshInterval)
    }
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(refreshInterval))
        await viewModel.refreshIfStale(maxAge: refreshInterval)
      }
    }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task { await viewModel.refreshIfStale(maxAge: refreshInterval) }
    }
  }

  private var current: NewsTickerItem? {
    guard !viewModel.items.isEmpty else { return nil }
    return viewModel.items[index % viewModel.items.count]
  }

  @ViewBuilder
  private func headlineRow(_ item: NewsTickerItem) -> some View {
    Button {
      if let raw = item.url, let url = URL(string: raw) {
        openURL(url)
      }
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        Text(item.title)
          .typography(.small, weight: .semibold)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        Text(meta(for: item))
          .typography(.nano)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityHint(Text(LocalizedStringKey("Opens the publisher")))
  }

  private func meta(for item: NewsTickerItem) -> String {
    guard let date = ISO8601DateFormatter().date(from: item.publishedAt) else { return item.source }
    let ago = date.formatted(.relative(presentation: .numeric, unitsStyle: .narrow))
    return "\(item.source) · \(ago)"
  }
}
