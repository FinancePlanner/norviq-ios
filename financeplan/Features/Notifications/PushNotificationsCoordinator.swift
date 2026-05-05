import Combine
import Foundation
import OSLog
import StockPlanShared
import UIKit
import UserNotifications

struct PushNotificationRoute: Equatable, Sendable {
  enum Kind: String, Equatable, Sendable {
    case targetHit = "target_hit"
    case earningsReminder = "earnings_reminder"
    case openPortfolio = "open_portfolio"
  }

  let kind: Kind
  let symbol: String?
  let scenario: String?
  let targetID: String?
  let earningsDate: String?
  let leadDays: Int?
  let deepLink: String?

  nonisolated init(
    kind: Kind,
    symbol: String?,
    scenario: String? = nil,
    targetID: String? = nil,
    earningsDate: String? = nil,
    leadDays: Int? = nil,
    deepLink: String? = nil
  ) {
    self.kind = kind
    self.symbol = symbol
    self.scenario = scenario
    self.targetID = targetID
    self.earningsDate = earningsDate
    self.leadDays = leadDays
    self.deepLink = deepLink
  }
}

enum PushNotificationPayloadParser {
  nonisolated static func parse(userInfo: [AnyHashable: Any]) -> PushNotificationRoute? {
    let root = normalizeDictionary(userInfo)
    let payload = (root["payload"] as? [String: Any]) ?? root

    let rawType = stringValue(for: ["type", "notificationType"], in: payload) ?? PushNotificationRoute.Kind.targetHit.rawValue
    let kind = PushNotificationRoute.Kind(rawValue: rawType) ?? .targetHit
    let normalizedSymbol = normalize(stringValue(for: ["symbol"], in: payload) ?? stringValue(for: ["symbol"], in: root))

    if (kind == .targetHit || kind == .earningsReminder), normalizedSymbol == nil {
      return nil
    }

    let scenario = normalize(stringValue(for: ["scenario"], in: payload))
    let targetID = normalize(stringValue(for: ["targetId", "target_id"], in: payload))
    let earningsDate = normalize(stringValue(for: ["earningsDate", "earnings_date"], in: payload))
    let leadDays = intValue(for: ["leadDays", "lead_days"], in: payload)
    let deepLink = normalize(stringValue(for: ["deepLink", "deep_link"], in: payload))

    return PushNotificationRoute(
      kind: kind,
      symbol: normalizedSymbol,
      scenario: scenario,
      targetID: targetID,
      earningsDate: earningsDate,
      leadDays: leadDays,
      deepLink: deepLink
    )
  }

  nonisolated private static func normalizeDictionary(_ dictionary: [AnyHashable: Any]) -> [String: Any] {
    Dictionary(uniqueKeysWithValues: dictionary.compactMap { key, value in
      guard let key = key as? String else { return nil }
      return (key, value)
    })
  }

  nonisolated private static func stringValue(for keys: [String], in dictionary: [String: Any]) -> String? {
    for key in keys {
      if let string = dictionary[key] as? String {
        return string
      }
    }
    return nil
  }

  nonisolated private static func intValue(for keys: [String], in dictionary: [String: Any]) -> Int? {
    for key in keys {
      if let int = dictionary[key] as? Int {
        return int
      }
      if let string = dictionary[key] as? String, let int = Int(string) {
        return int
      }
    }
    return nil
  }

  nonisolated private static func normalize(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

enum PushNotificationUserAction: Equatable {
  case openStock
  case openPortfolio
}

protocol PushPermissionProviding: Sendable {
  func requestAuthorization() async throws -> Bool
  func currentAuthorizationStatus() async -> PushAuthorizationStatus
}

struct SystemPushPermissionProvider: PushPermissionProviding, @unchecked Sendable {
  private let center: UNUserNotificationCenter

  init(center: UNUserNotificationCenter = .current()) {
    self.center = center
  }

  func requestAuthorization() async throws -> Bool {
    try await center.requestAuthorization(options: [.alert, .badge, .sound])
  }

  func currentAuthorizationStatus() async -> PushAuthorizationStatus {
    let settings = await center.notificationSettings()
    switch settings.authorizationStatus {
    case .authorized:
      return .authorized
    case .provisional, .ephemeral:
      return .provisional
    case .denied:
      return .denied
    case .notDetermined:
      return .notDetermined
    @unknown default:
      return .notDetermined
    }
  }
}

protocol PushRemoteNotificationsRegistering: Sendable {
  @MainActor func registerForRemoteNotifications()
  func openSystemSettings()
}

struct SystemPushRemoteNotificationsRegistrar: PushRemoteNotificationsRegistering, Sendable {
  @MainActor func registerForRemoteNotifications() {
    UIApplication.shared.registerForRemoteNotifications()
  }

  func openSystemSettings() {
    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
      return
    }

    Task { @MainActor in
      _ = await UIApplication.shared.open(settingsURL)
    }
  }
}

@MainActor
final class PushNotificationsCoordinator: ObservableObject {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "PushNotificationsUX"
  )

  @Published private(set) var authorizationStatus: PushAuthorizationStatus = .notDetermined
  @Published private(set) var isOptedIn: Bool = false
  @Published private(set) var earningsAlertsEnabled: Bool = false
  @Published private(set) var isEarningsAlertsLoading: Bool = false
  @Published var showPostLoginExplainer = false
  @Published private(set) var lastErrorMessage: String?
  @Published private(set) var earningsAlertsErrorMessage: String?
  @Published private(set) var pendingNotificationRoute: PushNotificationRoute?

  private let service: PushNotificationsServicing
  private let permissionProvider: PushPermissionProviding
  private let remoteRegistrar: PushRemoteNotificationsRegistering
  private let sessionStore: AuthSessionStoring
  private let userDefaults: UserDefaults
  private let environmentResolver: () -> PushAPNSEnvironment

  private var currentUserID: String = ""
  private var deviceToken: String?

  init(
    service: PushNotificationsServicing,
    permissionProvider: PushPermissionProviding = SystemPushPermissionProvider(),
    remoteRegistrar: PushRemoteNotificationsRegistering = SystemPushRemoteNotificationsRegistrar(),
    sessionStore: AuthSessionStoring,
    userDefaults: UserDefaults = .standard,
    environmentResolver: @escaping () -> PushAPNSEnvironment = PushNotificationsCoordinator.resolveAPNSEnvironment
  ) {
    self.service = service
    self.permissionProvider = permissionProvider
    self.remoteRegistrar = remoteRegistrar
    self.sessionStore = sessionStore
    self.userDefaults = userDefaults
    self.environmentResolver = environmentResolver
  }

  func handleAuthenticatedSessionBecameActive() {
    Task {
      currentUserID = normalized(await sessionStore.currentUserID)
      guard !currentUserID.isEmpty else {
        return
      }

      isOptedIn = optedInUsers.contains(currentUserID)

      await refreshAuthorizationStatus()
      await loadEarningsPreferencesIfPossible()

      if authorizationStatus == .notDetermined && !hasSeenExplainer(for: currentUserID) {
        showPostLoginExplainer = true
        return
      }

      if isOptedIn {
        if authorizationStatus == .authorized || authorizationStatus == .provisional {
          remoteRegistrar.registerForRemoteNotifications()
          await syncDeviceTokenIfPossible()
        } else if authorizationStatus == .denied {
          await deactivateCurrentTokenBestEffort()
        }
      }
    }
  }

  func handleSessionWillInvalidate() {
    Task {
      await deactivateCurrentTokenBestEffort()
    }
  }

  func handleSessionDidInvalidate() {
    showPostLoginExplainer = false
    currentUserID = ""
    isOptedIn = false
    earningsAlertsEnabled = false
    earningsAlertsErrorMessage = nil
  }

  func refreshAuthorizationStatus() async {
    authorizationStatus = await permissionProvider.currentAuthorizationStatus()
  }

  func didRegisterForRemoteNotifications(deviceTokenData: Data) {
    deviceToken = deviceTokenData.map { String(format: "%02x", $0) }.joined()
    Task {
      await syncDeviceTokenIfPossible()
    }
  }

  func didFailToRegisterForRemoteNotifications(error: any Error) {
    lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to register for push notifications."
  }

  func handleIncomingRemoteNotification(
    userInfo: [AnyHashable: Any],
    userAction: PushNotificationUserAction = .openStock
  ) {
    guard let parsedRoute = PushNotificationPayloadParser.parse(userInfo: userInfo) else {
      Self.logger.warning("push.route parse_failed")
      return
    }

    handleIncomingRoute(parsedRoute, userAction: userAction)
  }

  func handleIncomingRoute(
    _ parsedRoute: PushNotificationRoute,
    userAction: PushNotificationUserAction = .openStock
  ) {
    let route: PushNotificationRoute
    switch userAction {
    case .openStock:
      route = parsedRoute
    case .openPortfolio:
      route = PushNotificationRoute(
        kind: .openPortfolio,
        symbol: parsedRoute.symbol,
        scenario: parsedRoute.scenario,
        targetID: parsedRoute.targetID,
        earningsDate: parsedRoute.earningsDate,
        leadDays: parsedRoute.leadDays,
        deepLink: parsedRoute.deepLink
      )
    }

    pendingNotificationRoute = route
    Self.logger.info(
      "push.route queued kind=\(route.kind.rawValue, privacy: .public) symbol=\(route.symbol ?? "-", privacy: .public) action=\(String(describing: userAction), privacy: .public)"
    )
  }

  func consumePendingNotificationRoute() -> PushNotificationRoute? {
    defer { pendingNotificationRoute = nil }
    return pendingNotificationRoute
  }

  func enableFromExplainer() async {
    let userID = normalized(await sessionStore.currentUserID)
    guard !userID.isEmpty else {
      return
    }

    markExplainerSeen(for: userID)
    setOptIn(true, for: userID)
    showPostLoginExplainer = false

    await requestPermissionFlow()
  }

  func dismissExplainer() {
    Task {
      let userID = normalized(await sessionStore.currentUserID)
      guard !userID.isEmpty else {
        showPostLoginExplainer = false
        return
      }

      markExplainerSeen(for: userID)
      setOptIn(false, for: userID)
      showPostLoginExplainer = false
    }
  }

  func setNotificationsEnabled(_ enabled: Bool) async {
    let userID = normalized(await sessionStore.currentUserID)
    guard !userID.isEmpty else {
      return
    }

    setOptIn(enabled, for: userID)
    markExplainerSeen(for: userID)

    if enabled {
      await refreshAuthorizationStatus()
      if authorizationStatus == .denied {
        remoteRegistrar.openSystemSettings()
        return
      }
      await requestPermissionFlow()
    } else {
      await deactivateCurrentTokenBestEffort()
      earningsAlertsEnabled = false
    }
  }

  func loadEarningsPreferencesIfPossible() async {
    let userID = normalized(await sessionStore.currentUserID)
    guard !userID.isEmpty else {
      return
    }

    isEarningsAlertsLoading = true
    defer { isEarningsAlertsLoading = false }

    do {
      let preferences = try await service.fetchEarningsPreferences()
      earningsAlertsEnabled = preferences.enabled
      earningsAlertsErrorMessage = nil
    } catch {
      earningsAlertsErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load earnings reminders."
    }
  }

  func setEarningsAlertsEnabled(_ enabled: Bool) async {
    let userID = normalized(await sessionStore.currentUserID)
    guard !userID.isEmpty else {
      return
    }

    if enabled, !isOptedIn {
      await setNotificationsEnabled(true)
    }

    guard isOptedIn else {
      earningsAlertsEnabled = false
      return
    }

    isEarningsAlertsLoading = true
    defer { isEarningsAlertsLoading = false }

    do {
      let preferences = try await service.updateEarningsPreferences(enabled: enabled)
      earningsAlertsEnabled = preferences.enabled
      earningsAlertsErrorMessage = nil
    } catch {
      earningsAlertsErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to update earnings reminders."
    }
  }

  func deactivateCurrentTokenBestEffort() async {
    guard let token = deviceToken, !token.isEmpty else {
      return
    }

    do {
      try await service.deactivateDevice(deviceToken: token)
    } catch {
      // Best-effort by design; keep session/logout flow uninterrupted.
    }
  }

  var statusDescription: String {
    switch authorizationStatus {
    case .authorized:
      return "Authorized"
    case .provisional:
      return "Provisional"
    case .denied:
      return "Denied"
    case .notDetermined:
      return "Not determined"
    }
  }

  private func requestPermissionFlow() async {
    do {
      _ = try await permissionProvider.requestAuthorization()
      await refreshAuthorizationStatus()
      if authorizationStatus == .authorized || authorizationStatus == .provisional {
        remoteRegistrar.registerForRemoteNotifications()
        await syncDeviceTokenIfPossible()
      } else {
        await deactivateCurrentTokenBestEffort()
      }
    } catch {
      lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Notification permission request failed."
    }
  }

  private func syncDeviceTokenIfPossible() async {
    guard let token = deviceToken, !token.isEmpty else {
      return
    }

    let userID = normalized(await sessionStore.currentUserID)
    guard !userID.isEmpty else {
      return
    }

    guard optedInUsers.contains(userID) else {
      return
    }

    guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
      return
    }

    do {
      _ = try await service.registerDevice(
        deviceToken: token,
        apnsEnvironment: environmentResolver(),
        authorizationStatus: authorizationStatus
      )
      currentUserID = userID
      isOptedIn = true
      lastErrorMessage = nil
    } catch {
      lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to sync push token."
    }
  }

  private func normalized(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func hasSeenExplainer(for userID: String) -> Bool {
    explainerSeenUsers.contains(userID)
  }

  private func markExplainerSeen(for userID: String) {
    var users = explainerSeenUsers
    users.insert(userID)
    userDefaults.set(Array(users), forKey: Self.explainerSeenUserIDsKey)
  }

  private func setOptIn(_ enabled: Bool, for userID: String) {
    var users = optedInUsers
    if enabled {
      users.insert(userID)
    } else {
      users.remove(userID)
    }
    userDefaults.set(Array(users), forKey: Self.optedInUserIDsKey)
    isOptedIn = enabled
  }

  private var explainerSeenUsers: Set<String> {
    Set(userDefaults.stringArray(forKey: Self.explainerSeenUserIDsKey) ?? [])
  }

  private var optedInUsers: Set<String> {
    Set(userDefaults.stringArray(forKey: Self.optedInUserIDsKey) ?? [])
  }

  private static let explainerSeenUserIDsKey = "push_notifications_explainer_seen_user_ids"
  private static let optedInUserIDsKey = "push_notifications_opted_in_user_ids"

  nonisolated static func resolveAPNSEnvironment() -> PushAPNSEnvironment {
#if targetEnvironment(simulator)
    return .development
#else
    guard
      let provisioningProfileURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
      let data = try? Data(contentsOf: provisioningProfileURL),
      let source = String(data: data, encoding: .utf8),
      let plistStart = source.range(of: "<plist"),
      let plistEnd = source.range(of: "</plist>"),
      plistStart.lowerBound < plistEnd.upperBound
    else {
      return .production
    }

    let plistString = String(source[plistStart.lowerBound ..< plistEnd.upperBound])
    guard
      let plistData = plistString.data(using: .utf8),
      let raw = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
      let entitlements = raw["Entitlements"] as? [String: Any],
      let environment = (entitlements["aps-environment"] ?? entitlements["com.apple.developer.aps-environment"]) as? String
    else {
      return .production
    }

    return environment == "development" ? .development : .production
#endif
  }
}
