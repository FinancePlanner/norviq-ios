import Factory
import Observation
import StockPlanShared
import SwiftUI

@MainActor @Observable
final class TerminalSummaryCardModel {
  enum State: Equatable {
    case loading
    /// The request failed: no card at all (also covers a backend without the route yet).
    case hidden
    /// No rows: a compact prompt instead of an empty summary.
    case empty
    case summary(TerminalPositionsSummaryResponse)
  }

  private(set) var state: State = .loading
  private let service: any TerminalPositionsServicing

  init(service: any TerminalPositionsServicing) {
    self.service = service
  }

  func load() async {
    do {
      let summary = try await service.summary()
      state = summary.positionCount == 0 ? .empty : .summary(summary)
    } catch {
      guard !TerminalPositionsErrorText.isCancellation(error) else { return }
      // A refresh failure keeps what was shown; only a first failure hides the card.
      if case .loading = state { state = .hidden }
    }
  }
}

struct TerminalDashboardCard: View {
  @Environment(\.colorScheme) private var colorScheme
  @AppStorage(TerminalPreferences.roundDownKey) private var roundDown = false
  @State private var model = TerminalSummaryCardModel(service: Container.shared.terminalPositionsService())
  let action: () -> Void

  var body: some View {
    Group {
      switch model.state {
      case .loading:
        card { prompt }
          .redacted(reason: .placeholder)
      case .hidden:
        EmptyView()
      case .empty:
        card { prompt }
      case let .summary(summary):
        card { summaryContent(summary) }
      }
    }
    .task { await model.load() }
  }

  private var prompt: some View {
    VStack(alignment: .leading, spacing: 4) {
      Label("Plan a terminal position", systemImage: "scope")
        .font(.headline)
      Text("Set a future market cap and see how many shares your target takes.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
    }
  }

  private func summaryContent(_ summary: TerminalPositionsSummaryResponse) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Terminal positions", systemImage: "scope")
        .font(.headline)
      Text("Value wanted: \(TerminalFormat.money(summary.totalValueWanted, currency: summary.currency))")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      ForEach(summary.topPositions) { position in
        VStack(alignment: .leading, spacing: 3) {
          HStack {
            Text(verbatim: position.ticker)
              .font(.subheadline.weight(.semibold))
            Spacer()
            if let needed = position.sharesNeeded {
              Text(TerminalFormat.shares(needed, roundDown: roundDown))
                .font(.subheadline.monospacedDigit())
            }
          }
          ProgressView(value: min(max(position.progress ?? 0, 0), 1))
            .tint(AppTheme.Colors.tint(for: colorScheme))
        }
      }
      if summary.monthlyAutobuyTotal > 0 {
        Text("Autobuys: \(TerminalFormat.money(summary.monthlyAutobuyTotal, currency: summary.currency)) a month")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text(TerminalCopy.disclaimer)
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
  }

  private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: 16) {
        content()
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .foregroundStyle(.tertiary)
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        AppTheme.Colors.cardBackground(for: colorScheme),
        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
      )
    }
    .buttonStyle(.plain)
    .accessibilityHint(Text("Open terminal positions"))
  }
}
