import Foundation

extension Notification.Name {
  static let portfolioDataDidChange = Notification.Name("portfolioDataDidChange")
  static let stalePositionPurged = Notification.Name("stalePositionPurged")
  static let openStockFromPushNotification = Notification.Name("openStockFromPushNotification")
  static let openPortfolioFromPushNotification = Notification.Name("openPortfolioFromPushNotification")
  static let openTaxFromPushNotification = Notification.Name("openTaxFromPushNotification")
}
