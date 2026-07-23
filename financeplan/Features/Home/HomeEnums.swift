import SwiftUI

enum HomeTab: Hashable {
  case dashboard
  case portfolio
  case economy
  case crypto
  case expenses
  case reports
  case tax
  case insights

  var title: String {
    switch self {
    case .dashboard:
      return String(localized: "Home")
    case .portfolio:
      return String(localized: "Portfolio")
    case .economy:
      return String(localized: "Economy")
    case .crypto:
      return String(localized: "Crypto")
    case .expenses:
      return String(localized: "Expenses")
    case .reports:
      return String(localized: "Reports")
    case .tax:
      return String(localized: "Tax")
    case .insights:
      return String(localized: "Insights")
    }
  }

  var systemImage: String {
    switch self {
    case .dashboard:
      return "house"
    case .portfolio:
      return "chart.line.uptrend.xyaxis"
    case .economy:
      return "chart.bar.xaxis"
    case .crypto:
      return "bitcoinsign.circle"
    case .expenses:
      return "creditcard"
    case .reports:
      return "chart.bar.doc.horizontal"
    case .tax:
      return "building.columns"
    case .insights:
      return "sparkles"
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
