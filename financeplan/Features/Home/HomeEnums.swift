import SwiftUI

enum HomeTab: Hashable, CaseIterable {
  case dashboard
  case portfolio
  case economy
  case markets
  case crypto
  case expenses
  case reports
  case tax
  case insights

  /// Always-visible iPhone tabs, registered first so the system bar shows
  /// these before overflow. iPad sidebar still lists every destination.
  static let primaryTabs: [HomeTab] = [.dashboard, .portfolio, .expenses, .crypto]

  /// Destinations that sit after the primary four. On iPhone they land in
  /// More; on iPad they appear in the sidebar. A tab in neither list is
  /// unreachable — which is how Markets shipped invisible once already.
  static let moreMenuTabs: [HomeTab] = [.markets, .economy, .reports, .tax, .insights]

  var title: String {
    switch self {
    case .dashboard:
      return String(localized: "Home")
    case .portfolio:
      return String(localized: "Portfolio")
    case .economy:
      return String(localized: "Economy")
    case .markets:
      return String(localized: "Markets")
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
      return "house.fill"
    case .portfolio:
      return "chart.line.uptrend.xyaxis"
    case .economy:
      return "chart.bar.fill"
    case .markets:
      return "square.grid.3x3.fill"
    case .crypto:
      return "bitcoinsign.circle.fill"
    case .expenses:
      return "creditcard.fill"
    case .reports:
      return "chart.bar.doc.horizontal.fill"
    case .tax:
      return "building.columns.fill"
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
