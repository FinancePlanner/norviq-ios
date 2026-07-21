import Foundation

enum AutomationNavigationDestination: Identifiable, Hashable {
  case smartScreen(String?)
  case rebalancing(String?)

  var id: String {
    switch self {
    case let .smartScreen(id): "smart-screen-\(id ?? "")"
    case let .rebalancing(id): "rebalancing-\(id ?? "")"
    }
  }
}

extension Notification.Name {
  static let portfolioDataDidChange = Notification.Name("portfolioDataDidChange")
  static let stalePositionPurged = Notification.Name("stalePositionPurged")
  static let openStockFromPushNotification = Notification.Name("openStockFromPushNotification")
  static let openPortfolioFromPushNotification = Notification.Name("openPortfolioFromPushNotification")
  static let openTaxFromPushNotification = Notification.Name("openTaxFromPushNotification")
  static let openBudgetFromPushNotification = Notification.Name("openBudgetFromPushNotification")
  static let openThesisWatchFromPushNotification = Notification.Name("openThesisWatchFromPushNotification")
}
