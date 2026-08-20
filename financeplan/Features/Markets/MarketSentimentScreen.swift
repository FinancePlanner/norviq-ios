import StockPlanShared
import SwiftUI

/// Market-wide view of what retail is talking about.
///
/// Reached from Markets rather than owning a tab: `HomeEnums` documents that a
/// tab listed in neither `primaryTabs` nor `moreMenuTabs` ships invisible, and
/// this is a way of browsing the market rather than a separate section.
struct MarketSentimentScreen: View {
  @State private var viewModel = MarketSentimentViewModel()

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
        if let board = viewModel.board, board.asOfDate != nil {
          sentimentSection(
            "Most discussed",
            subtitle: "Loudest relative to their own normal volume.",
            entries: board.mostDiscussed
          )
          sentimentSection(
            "Biggest swings",
            subtitle: "Largest day-over-day change in tone.",
            entries: board.biggestSwings
          )
          sentimentSection(
            "Most bullish",
            subtitle: "Where the conversation leans positive.",
            entries: board.bullish
          )
          sentimentSection(
            "Most bearish",
            subtitle: "Where the conversation leans negative.",
            entries: board.bearish
          )

          Text("Sentiment reflects what retail investors are posting, not whether they are right. Not investment advice.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.top, AppTheme.Spacing.sm)
        } else if viewModel.isLoading {
          ProgressView()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 48)
        } else {
          emptyState
        }
      }
      .padding()
    }
    .navigationTitle("Retail sentiment")
    .navigationBarTitleDisplayMode(.inline)
    .task { await viewModel.load() }
    .refreshable { await viewModel.load(force: true) }
  }

  @ViewBuilder
  private var emptyState: some View {
    ContentUnavailableView {
      Label("No sentiment yet", systemImage: "bubble.left.and.bubble.right")
    } description: {
      if viewModel.isAwaitingFirstRun {
        // A pipeline that has not run yet is a different situation from one
        // that is broken, and saying which avoids a support ticket.
        Text("The daily run hasn't produced results yet. Check back later.")
      } else if let errorMessage = viewModel.errorMessage {
        Text(errorMessage)
      } else {
        Text("Sentiment data isn't available right now.")
      }
    }
    .padding(.top, 48)
  }

  @ViewBuilder
  private func sentimentSection(
    _ title: String,
    subtitle: String,
    entries: [TrendingSentimentEntry]
  ) -> some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.headline)
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if entries.isEmpty {
        Text("Nothing to show yet.")
          .font(.caption)
          .foregroundStyle(.tertiary)
      } else {
        // Rows are intentionally not tappable. StockDetailScreen is keyed on a
        // portfolio stockId, and a trending symbol is usually one the user does
        // not hold — there is no symbol-only detail route to send them to, and a
        // link that 404s is worse than no link. Reaching detail from here needs
        // a symbol-lookup flow, which is its own piece of work.
        VStack(spacing: 0) {
          ForEach(entries) { entry in
            TrendingSentimentRow(entry: entry)

            if entry.id != entries.last?.id {
              Divider()
            }
          }
        }
      }
    }
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }
}

private struct TrendingSentimentRow: View {
  let entry: TrendingSentimentEntry

  /// Renders the z-score as plain language. "2.7σ" means nothing to someone
  /// checking their portfolio over coffee.
  private var volumeText: String {
    guard let z = entry.volumeZ else { return "Baseline forming" }
    switch z {
    case 3...: return "Far above normal"
    case 1.5 ..< 3: return "Well above normal"
    case 0.5 ..< 1.5: return "Above normal"
    case ...(-1.5): return "Much quieter"
    case -1.5 ..< -0.5: return "Quieter than usual"
    default: return "Normal volume"
    }
  }

  private var display: RetailSentimentDisplay {
    guard let score = entry.score else { return .none }
    return RetailSentimentDisplay(
      hasReading: true,
      label: entry.label.capitalized,
      scoreText: String(format: "%+.0f", score * 100),
      deltaText: entry.delta1d.flatMap { abs($0) >= 0.01 ? String(format: "%+.2f", $0) : nil },
      deltaUp: (entry.delta1d ?? 0) > 0,
      postText: RetailSentimentDisplay.postLabel(entry.postCount)
    )
  }

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(entry.symbol)
          .font(.subheadline.weight(.semibold))
        Text("\(volumeText) · \(RetailSentimentDisplay.postLabel(entry.postCount))")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Spacer()
      RetailSentimentBadge(display: display)
    }
    .padding(.vertical, 8)
    .contentShape(Rectangle())
  }
}
