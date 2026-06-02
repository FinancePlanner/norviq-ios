import SwiftUI

enum HomeTab: Hashable {
  case dashboard
  case portfolio
  case expenses
  case reports
  case insights

  var title: String {
    switch self {
    case .dashboard:
      return String(localized: "Home")
    case .portfolio:
      return String(localized: "Portfolio")
    case .expenses:
      return String(localized: "Expenses")
    case .reports:
      return String(localized: "Reports")
    case .insights:
      return String(localized: "Insights")
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
    case .allocation, .earnings, .news:
      return true
    case .holdings, .watchlist:
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
