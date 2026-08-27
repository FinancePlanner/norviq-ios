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
    cardContent(response)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func cardContent(_ response: WhyMovedResponse) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Text("Today")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        if let change = response.portfolioChangePercent {
          Text("\(change >= 0 ? "+" : "")\(change, specifier: "%.2f")% today")
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(change >= 0 ? WhyMovedPalette.gain(for: scheme) : WhyMovedPalette.loss(for: scheme))
        }
      }

      // Names the differentiator and its recency. Omitted entirely when no
      // sentiment was covered, so the card never implies coverage it lacks.
      if let source = response.sentimentSource, source.postsAnalyzed > 0 {
        Text(sentimentSourceLine(source))
          .font(.caption2.weight(.semibold).monospaced())
          .foregroundStyle(AppTheme.Colors.secondaryText(for: scheme))
      } else {
        Text("Why it moved · Hermes signals")
          .font(.caption2.weight(.semibold).monospaced())
          .foregroundStyle(AppTheme.Colors.secondaryText(for: scheme))
      }

      if let capacity = viewModel.capacity, let units = capacity.surplusUnits {
        Text("Leftover \(capacity.surplusAmount.formatted(.currency(code: capacity.currencyCode))) → \(units.formatted(.number.precision(.fractionLength(2)))) \(capacity.symbol). Equivalent at last price — not an order.")
          .font(.caption)
          .foregroundStyle(AppTheme.Colors.secondaryText(for: scheme))
      }

      if let summary = response.aiSummary {
        Text(summary.text)
          .font(.subheadline)
          .fixedSize(horizontal: false, vertical: true)
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
                .foregroundStyle(index.changePercent >= 0 ? WhyMovedPalette.gain(for: scheme) : WhyMovedPalette.loss(for: scheme))
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.secondaryText(for: scheme))
          }
          Spacer()
        }
      }
    }
  }

  private func sentimentSourceLine(_ source: WhyMovedSentimentSource) -> String {
    var line = "\(source.postsAnalyzed) X posts across \(source.symbolsCovered) holdings"
    if let raw = source.lastPostAt, let posted = MacroNewsDateFormatting.parse(raw) {
      let formatter = RelativeDateTimeFormatter()
      formatter.unitsStyle = .abbreviated
      line += " · newest \(formatter.localizedString(for: posted, relativeTo: Date()))"
    }
    return line
  }

  private func moverChip(_ mover: WhyMovedMover) -> some View {
    HStack(spacing: 6) {
      Text(mover.symbol)
        .font(.caption.weight(.bold).monospaced())
      Text("\(mover.changePercent >= 0 ? "+" : "")\(mover.changePercent, specifier: "%.2f")%")
        .font(.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(mover.changePercent >= 0 ? WhyMovedPalette.gain(for: scheme) : WhyMovedPalette.loss(for: scheme))
      if let sentiment = mover.sentiment {
        Text("\(sentiment.label) · \(sentiment.postCount)")
          .font(.caption2.weight(.bold).monospaced())
          .textCase(.uppercase)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(WhyMovedPalette.sentimentTone(sentiment.label, scheme: scheme).opacity(0.14), in: Capsule())
          .foregroundStyle(WhyMovedPalette.sentimentTone(sentiment.label, scheme: scheme))
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(
      Capsule()
        .fill(AppTheme.Colors.elevatedCardBackground(for: scheme))
        .overlay(
          Capsule()
            .stroke(AppTheme.Colors.tint(for: scheme).opacity(0.28), lineWidth: 1)
        )
    )
  }
}

enum WhyMovedPalette {
  // These defer entirely to the app-wide status tokens, which already switch on
  // ColorScheme. The brand check that used to live here only
  // intercepted Classic and substituted a fixed literal, so Classic rendered the
  // same colour in light and dark — gains and losses picked for a light card,
  // drawn on a dark one.
  static func gain(for scheme: ColorScheme) -> Color {
    AppTheme.Colors.successText(for: scheme)
  }

  static func loss(for scheme: ColorScheme) -> Color {
    AppTheme.Colors.dangerText(for: scheme)
  }

  static func sentimentTone(_ label: String, scheme: ColorScheme) -> Color {
    switch label.lowercased() {
    case "bullish", "positive": gain(for: scheme)
    case "bearish", "negative": loss(for: scheme)
    default: .secondary
    }
  }
}

@MainActor
@Observable
final class WhyMovedViewModel {
  var response: WhyMovedResponse?
  var capacity: SpendToUnitsCapacityWire?
  private var hasLoaded = false

  private let dashboardService: any DashboardServicing
  private let expensesService: any ExpensesServicing

  init(
    dashboardService: any DashboardServicing = Container.shared.dashboardService(),
    expensesService: any ExpensesServicing = Container.shared.expensesService()
  ) {
    self.dashboardService = dashboardService
    self.expensesService = expensesService
  }

  func loadIfNeeded() async {
    guard !hasLoaded else { return }
    hasLoaded = true
    async let why = dashboardService.getWhyMoved()
    async let units = expensesService.getDcaCapacity()
    response = try? await why
    capacity = try? await units
  }
}
