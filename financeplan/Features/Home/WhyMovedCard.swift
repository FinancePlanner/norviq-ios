import Factory
import SwiftUI

/// The moat hero: why the portfolio moved today — top contributors joined
/// with Hermes X-sentiment, market context, and a cached AI sentence.
/// Self-loading; hidden entirely when there is nothing to say.
struct WhyMovedCard: View {
  @Environment(\.colorScheme) private var scheme
  @State private var viewModel = WhyMovedViewModel()

  var body: some View {
    Group {
      if let response = viewModel.response,
         !(response.movers.isEmpty && response.aiSummary == nil) {
        card(response)
      }
    }
    .task {
      await viewModel.loadIfNeeded()
    }
  }

  private func card(_ response: WhyMovedResponse) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Text("WHY YOUR PORTFOLIO MOVED")
          .font(.caption.weight(.bold))
          .tracking(1.1)
          .foregroundStyle(AppTheme.Colors.ember(for: scheme))
        Spacer()
        if let change = response.portfolioChangePercent {
          Text("\(change >= 0 ? "+" : "")\(change, specifier: "%.2f")% today")
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(change >= 0 ? WhyMovedPalette.gain : WhyMovedPalette.loss)
        }
      }

      if let summary = response.aiSummary {
        HStack(alignment: .top, spacing: 6) {
          Image(systemName: "sparkles")
            .font(.footnote)
            .foregroundStyle(AppTheme.Colors.tint(for: scheme))
          Text(summary.text)
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      if !response.movers.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            // Chips are informational in v1: StockDetailScreen needs a
            // portfolio stockId which the movers payload doesn't carry.
            ForEach(response.movers.prefix(6)) { mover in
              moverChip(mover)
            }
          }
        }
      }

      if !response.context.indices.isEmpty {
        HStack(spacing: 12) {
          ForEach(response.context.indices.prefix(3)) { index in
            HStack(spacing: 4) {
              Text(index.label)
              Text("\(index.changePercent >= 0 ? "+" : "")\(index.changePercent, specifier: "%.2f")%")
                .monospacedDigit()
                .foregroundStyle(index.changePercent >= 0 ? WhyMovedPalette.gain : WhyMovedPalette.loss)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          }
          Spacer()
        }
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }

  private func moverChip(_ mover: WhyMovedMover) -> some View {
    HStack(spacing: 6) {
      Text(mover.symbol)
        .font(.caption.weight(.bold).monospaced())
      Text("\(mover.changePercent >= 0 ? "+" : "")\(mover.changePercent, specifier: "%.2f")%")
        .font(.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(mover.changePercent >= 0 ? WhyMovedPalette.gain : WhyMovedPalette.loss)
      if let sentiment = mover.sentiment {
        Text("\(sentiment.label) · \(sentiment.postCount)")
          .font(.system(size: 9, weight: .bold))
          .textCase(.uppercase)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(WhyMovedPalette.sentimentTone(sentiment.label).opacity(0.14), in: Capsule())
          .foregroundStyle(WhyMovedPalette.sentimentTone(sentiment.label))
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(AppTheme.Colors.elevatedCardBackground(for: scheme), in: Capsule())
  }
}

enum WhyMovedPalette {
  static let gain = Color(red: 0.03, green: 0.60, blue: 0.51)
  static let loss = Color(red: 0.95, green: 0.21, blue: 0.27)

  static func sentimentTone(_ label: String) -> Color {
    switch label.lowercased() {
    case "bullish", "positive": gain
    case "bearish", "negative": loss
    default: .secondary
    }
  }
}

@MainActor
@Observable
final class WhyMovedViewModel {
  var response: WhyMovedResponse?
  private var hasLoaded = false

  private let dashboardService: any DashboardServicing

  init(dashboardService: any DashboardServicing = Container.shared.dashboardService()) {
    self.dashboardService = dashboardService
  }

  func loadIfNeeded() async {
    guard !hasLoaded else { return }
    hasLoaded = true
    response = try? await dashboardService.getWhyMoved()
  }
}
