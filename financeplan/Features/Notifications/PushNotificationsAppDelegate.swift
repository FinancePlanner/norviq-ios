import Factory
import OSLog
import UIKit
import UserNotifications

final class PushNotificationsAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "PushNotificationsUX"
  )

  private enum ActionID {
    static let viewStock = "VIEW_TARGET_STOCK"
    static let openPortfolio = "OPEN_PORTFOLIO"
  }

  private enum CategoryID {
    static let targetAlert = "TARGET_ALERT"
  }

  func application(
    _: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    registerNotificationCategories()

    if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      let route = PushNotificationPayloadParser.parse(userInfo: remoteNotification)
      logger.info(
        "push.analytics delivered source=launch kind=\(route?.kind.rawValue ?? "unknown", privacy: .public) symbol=\(route?.symbol ?? "-", privacy: .public)"
      )
      if let route {
        Task { @MainActor in
          Container.shared.pushNotificationsCoordinator().handleIncomingRoute(route)
        }
      }
    }

    return true
  }

  func application(
    _: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Task { @MainActor in
      Container.shared.pushNotificationsCoordinator().didRegisterForRemoteNotifications(deviceTokenData: deviceToken)
    }
  }

  func application(
    _: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: any Error
  ) {
    Task { @MainActor in
      Container.shared.pushNotificationsCoordinator().didFailToRegisterForRemoteNotifications(error: error)
    }
  }

  nonisolated func userNotificationCenter(
    _: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let route = PushNotificationPayloadParser.parse(userInfo: notification.request.content.userInfo)
    logger.info(
      "push.analytics delivered source=foreground kind=\(route?.kind.rawValue ?? "unknown", privacy: .public) symbol=\(route?.symbol ?? "-", privacy: .public)"
    )
    if let route {
      Task { @MainActor in
        Container.shared.pushNotificationsCoordinator().handleIncomingRoute(route)
      }
    }
    completionHandler([.banner, .list, .sound])
  }

  nonisolated func userNotificationCenter(
    _: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let route = PushNotificationPayloadParser.parse(userInfo: response.notification.request.content.userInfo)
    logger.info(
      "push.analytics tapped action_id=\(response.actionIdentifier, privacy: .public) kind=\(route?.kind.rawValue ?? "unknown", privacy: .public) symbol=\(route?.symbol ?? "-", privacy: .public)"
    )

    let userAction: PushNotificationUserAction? = {
      switch response.actionIdentifier {
      case UNNotificationDefaultActionIdentifier, ActionID.viewStock:
        .openStock
      case ActionID.openPortfolio:
        .openPortfolio
      case UNNotificationDismissActionIdentifier:
        nil
      default:
        nil
      }
    }()

    if let userAction, let route {
      Task { @MainActor in
        Container.shared.pushNotificationsCoordinator().handleIncomingRoute(
          route,
          userAction: userAction
        )
      }
    }
    completionHandler()
  }

  private func registerNotificationCategories() {
    let viewAction = UNNotificationAction(
      identifier: ActionID.viewStock,
      title: "View Stock",
      options: [.foreground]
    )
    let portfolioAction = UNNotificationAction(
      identifier: ActionID.openPortfolio,
      title: "Open Portfolio",
      options: [.foreground]
    )

    let targetCategory = UNNotificationCategory(
      identifier: CategoryID.targetAlert,
      actions: [viewAction, portfolioAction],
      intentIdentifiers: [],
      options: [.customDismissAction]
    )
    UNUserNotificationCenter.current().setNotificationCategories([targetCategory])
  }
}
