import Foundation

/// Static demo data used by Screens 10 (swipe-to-build) and 11 (value reveal).
/// Sparkline values are synthetic — we deliberately do NOT call the live stock service
/// during onboarding (no auth yet, must work offline-first, must feel instant).
struct OnboardingDemoTicker: Identifiable, Equatable {
  let id: String
  let symbol: String
  let name: String
  let blurb: String
  let tags: [String]
  let sparkline: [Double]
  let glyphSystemName: String

  /// Nominal "as-if" current price used purely to render the sparkline axis.
  var lastValue: Double { sparkline.last ?? 0 }
}

enum OnboardingDemoTickers {
  static let all: [OnboardingDemoTicker] = [
    OnboardingDemoTicker(
      id: "AAPL",
      symbol: "AAPL",
      name: "Apple",
      blurb: "The iPhone, Mac, and a services business that quietly prints money.",
      tags: ["Tech", "Mega-cap"],
      sparkline: [172, 175, 171, 178, 184, 182, 188, 192, 195, 191, 198, 204],
      glyphSystemName: "applelogo"
    ),
    OnboardingDemoTicker(
      id: "MSFT",
      symbol: "MSFT",
      name: "Microsoft",
      blurb: "Cloud (Azure), enterprise software, and AI infrastructure.",
      tags: ["Tech", "Mega-cap"],
      sparkline: [340, 345, 342, 351, 358, 362, 369, 374, 380, 376, 388, 396],
      glyphSystemName: "cube.transparent.fill"
    ),
    OnboardingDemoTicker(
      id: "NVDA",
      symbol: "NVDA",
      name: "NVIDIA",
      blurb: "The company quietly powering most of AI.",
      tags: ["Tech", "Semis"],
      sparkline: [410, 432, 458, 471, 502, 538, 572, 611, 648, 692, 731, 778],
      glyphSystemName: "cpu.fill"
    ),
    OnboardingDemoTicker(
      id: "GOOG",
      symbol: "GOOG",
      name: "Alphabet",
      blurb: "Search, YouTube, Cloud, Android — all under one roof.",
      tags: ["Tech", "Mega-cap"],
      sparkline: [128, 130, 132, 135, 138, 141, 139, 144, 148, 145, 152, 156],
      glyphSystemName: "magnifyingglass.circle.fill"
    ),
    OnboardingDemoTicker(
      id: "AMZN",
      symbol: "AMZN",
      name: "Amazon",
      blurb: "E-commerce + AWS — the original two-engine business.",
      tags: ["Tech", "E-com"],
      sparkline: [142, 145, 141, 148, 152, 156, 154, 159, 163, 160, 168, 174],
      glyphSystemName: "shippingbox.fill"
    ),
    OnboardingDemoTicker(
      id: "TSLA",
      symbol: "TSLA",
      name: "Tesla",
      blurb: "EVs, energy storage, and the volatility that comes with both.",
      tags: ["Auto", "Volatile"],
      sparkline: [248, 261, 232, 245, 218, 240, 258, 235, 264, 241, 256, 272],
      glyphSystemName: "bolt.car.fill"
    ),
    OnboardingDemoTicker(
      id: "VTI",
      symbol: "VTI",
      name: "Vanguard Total Stock Market ETF",
      blurb: "Owns ~all of the US stock market in one ticker.",
      tags: ["ETF", "Diversified"],
      sparkline: [228, 230, 233, 236, 239, 242, 245, 248, 251, 254, 257, 261],
      glyphSystemName: "chart.line.uptrend.xyaxis"
    ),
    OnboardingDemoTicker(
      id: "VOO",
      symbol: "VOO",
      name: "Vanguard S&P 500 ETF",
      blurb: "Tracks the S&P 500. The default \"I just want the market.\"",
      tags: ["ETF", "Index"],
      sparkline: [415, 419, 423, 427, 432, 437, 441, 445, 450, 455, 459, 464],
      glyphSystemName: "chart.bar.fill"
    )
  ]

  /// Reorder cards so categories the user prefers (Screen 8a) surface first.
  /// Stable order preserved within each tier.
  static func ordered(forHoldings holdings: Set<OnboardingHoldingType>) -> [OnboardingDemoTicker] {
    guard !holdings.isEmpty else { return all }

    let prefersETF = holdings.contains(.indexFunds)
    let prefersIndividual = holdings.contains(.individualStocks)
    let prefersDividend = holdings.contains(.dividendPayers)

    return all.sorted { lhs, rhs in
      score(for: lhs, prefersETF: prefersETF, prefersIndividual: prefersIndividual, prefersDividend: prefersDividend)
        > score(for: rhs, prefersETF: prefersETF, prefersIndividual: prefersIndividual, prefersDividend: prefersDividend)
    }
  }

  /// Fallback picks when the user swipes left on every demo card.
  static let fallbackPicks: [String] = ["VTI", "AAPL", "MSFT"]

  private static func score(
    for ticker: OnboardingDemoTicker,
    prefersETF: Bool,
    prefersIndividual: Bool,
    prefersDividend: Bool
  ) -> Int {
    var score = 0
    let isETF = ticker.tags.contains("ETF")
    if prefersETF, isETF { score += 2 }
    if prefersIndividual, !isETF { score += 1 }
    if prefersDividend, ["VOO", "VTI", "MSFT", "AAPL"].contains(ticker.symbol) { score += 1 }
    return score
  }
}
