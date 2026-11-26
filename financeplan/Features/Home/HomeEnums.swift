import SwiftUI

/// The five tabs of the app shell, in order.
nonisolated enum AppTab: Hashable, CaseIterable, Sendable {
  case today
  case money
  case wealth
  case plan
  case more

  var title: LocalizedStringResource {
    switch self {
    case .today: "Today"
    case .money: "Money"
    case .wealth: "Wealth"
    case .plan: "Plan"
    case .more: "More"
    }
  }

  var systemImage: String {
    switch self {
    case .today: "sun.max"
    case .money: "creditcard"
    case .wealth: "chart.line.uptrend.xyaxis"
    case .plan: "target"
    case .more: "ellipsis.circle"
    }
  }
}

nonisolated extension AppTab {
  /// What a Pro tap on Q summarises when the screen on top sets no scope of
  /// its own. Plan and More have no one thing to summarise, so Q opens the
  /// card there; Tax sets its own scope.
  var assistantScope: AIViewScope? {
    switch self {
    case .today: .home
    case .money: .expenses
    case .wealth: .portfolio
    case .plan, .more: nil
    }
  }

  /// The guided-start tab this one is, for the spotlight.
  var guidedTab: GuidedTab? {
    switch self {
    case .today: .dashboard
    case .money: .expenses
    case .wealth: .portfolio
    case .plan, .more: nil
    }
  }

  /// The tab a guided step asks for. The Goals cover sits on Today until P4.
  init(guided tab: GuidedTab) {
    switch tab {
    case .dashboard, .goalPlanning: self = .today
    case .portfolio: self = .wealth
    case .expenses: self = .money
    }
  }
}

enum PortfolioSegment: String, CaseIterable, Identifiable {
  case holdings
  case allocation
  case watchlist
  case earnings
  case news

  var id: String { rawValue }

  var isProOnly: Bool {
    switch self {
    case .allocation, .earnings:
      return true
    case .holdings, .watchlist, .news:
      return false
    }
  }

  var title: String {
    switch self {
    case .holdings:
      return String(localized: "Holdings")
    case .allocation:
      return String(localized: "Allocation")
    case .watchlist:
      return String(localized: "Watchlist")
    case .earnings:
      return String(localized: "Earnings")
    case .news:
      return String(localized: "News")
    }
  }
}
