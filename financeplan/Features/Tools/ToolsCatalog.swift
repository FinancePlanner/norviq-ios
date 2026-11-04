import Foundation

/// The tools the hub lists, and the screens it can open. A separate route from
/// `PortfolioRootRoute` so the hub works on any stack, not only Portfolio's.
enum ToolsRoute: Hashable {
  case hub
  case grow
  case retire
  case terminalPositions
  case simulator
  case rebalancingRules
}

struct ToolEntry: Identifiable {
  let route: ToolsRoute
  let title: String
  let question: String
  let systemImage: String
  let requiresPro: Bool

  var id: ToolsRoute { route }
}

enum ToolsCatalog {
  /// Titles and icons match the labels `PortfolioRoot` already shows. Dividends
  /// stays out until its server-side numbers are real.
  static let entries: [ToolEntry] = [
    ToolEntry(
      route: .grow,
      title: "Grow",
      question: "How much will I have in X years?",
      systemImage: "chart.line.uptrend.xyaxis",
      requiresPro: false
    ),
    ToolEntry(
      route: .retire,
      title: "Retire",
      question: "How much do I need to retire?",
      systemImage: "beach.umbrella",
      requiresPro: false
    ),
    ToolEntry(
      route: .terminalPositions,
      title: "Terminal position sizing",
      question: "How many shares does my target position take?",
      systemImage: "scope",
      requiresPro: false
    ),
    ToolEntry(
      route: .simulator,
      title: "Portfolio simulator",
      question: "What would a different portfolio look like?",
      systemImage: "slider.horizontal.below.square.filled.and.square",
      requiresPro: false
    ),
    ToolEntry(
      route: .rebalancingRules,
      title: "Rebalancing rules",
      question: "How far has my portfolio drifted?",
      systemImage: "scale.3d",
      requiresPro: true
    ),
  ]
}
