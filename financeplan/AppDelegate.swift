import OSLog
import UserNotifications
import UIKit

private let appDelegateLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "finplanner",
  category: "AppDelegate"
)

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self

    return true
  }

  func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    appDelegateLogger.info("APNs token registered: \(token.prefix(8), privacy: .public)...")
  }

  func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    appDelegateLogger.error("Failed to register for remote notifications: \(error.localizedDescription, privacy: .public)")
  }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let content = notification.request.content
    appDelegateLogger.info("Push notification received in foreground: \(content.title, privacy: .public)")

    // Decide what to show (none, banner, sound, etc.)
    completionHandler([])
  }

  func userNotificationCenter(
    _: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let content = response.notification.request.content
    appDelegateLogger.info("Push notification tapped: \(content.title, privacy: .public)")

    completionHandler()
  }
}
