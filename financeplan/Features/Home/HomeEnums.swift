import SwiftUI

enum HomeTab: Hashable {
  case dashboard
  case portfolio
  case expenses
  case reports

  func title(language: AppLanguage) -> String {
    switch self {
    case .dashboard:
      language.localized(english: "Home", portuguese: "Início")
    case .portfolio:
      language.localized(english: "Portfolio", portuguese: "Portefólio")
    case .expenses:
      language.localized(english: "Expenses", portuguese: "Despesas")
    case .reports:
      language.localized(english: "Reports", portuguese: "Relatórios")
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

  func title(language: AppLanguage) -> String {
    switch self {
    case .holdings:
      return language.localized(english: "Holdings", portuguese: "Posições")
    case .allocation:
      return language.localized(english: "Allocation", portuguese: "Alocação")
    case .watchlist:
      return language.localized(english: "Watchlist", portuguese: "Lista de seguimento")
    case .earnings:
      return language.localized(english: "Earnings", portuguese: "Resultados")
    case .news:
      return language.localized(english: "News", portuguese: "Notícias")
    }
  }
}
