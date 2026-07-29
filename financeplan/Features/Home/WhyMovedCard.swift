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
        Text("AGENTIC INTELLIGENCE FEED")
          .vigilOverline()
          .foregroundStyle(AppTheme.Colors.tint(for: scheme))
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

      if let summary = response.aiSummary {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "sparkles")
            .font(.footnote)
            .foregroundStyle(AppTheme.Colors.tint(for: scheme))
            .shadow(color: AppTheme.Colors.tint(for: scheme).opacity(0.55), radius: 6)
          Text(summary.text)
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 4)
        .overlay(alignment: .leading) {
          Rectangle()
            .fill(
              LinearGradient(
                colors: [
                  AppTheme.Colors.tint(for: scheme),
                  AppTheme.Colors.secondaryTint(for: scheme)
                ],
                startPoint: .top,
                endPoint: .bottom
              )
            )
            .frame(width: 2)
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
                .foregroundStyle(index.changePercent >= 0 ? WhyMovedPalette.gain(for: scheme) : WhyMovedPalette.loss(for: scheme))
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.secondaryText(for: scheme))
          }
          Spacer()
        }
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .vigilGlassCard(cornerRadius: 16)
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
          .font(.system(size: 9, weight: .bold).monospaced())
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
            .stroke(AppTheme.Colors.tint(for: scheme).opacity(BrandTheme.current == .vigil ? 0.28 : 0), lineWidth: 1)
        )
    )
  }
}

enum WhyMovedPalette {
  static func gain(for scheme: ColorScheme) -> Color {
    BrandTheme.current == .vigil
      ? AppTheme.Colors.successText(for: scheme)
      : Color(red: 0.03, green: 0.60, blue: 0.51)
  }

  static func loss(for scheme: ColorScheme) -> Color {
    BrandTheme.current == .vigil
      ? AppTheme.Colors.dangerText(for: scheme)
      : Color(red: 0.95, green: 0.21, blue: 0.27)
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
