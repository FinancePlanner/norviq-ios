import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class PushNotificationsCoordinatorTests: XCTestCase {
  private final class PushNotificationsServiceMock: PushNotificationsServicing, @unchecked Sendable {
    var registerCalls = 0
    var deactivateCalls = 0
    var lastRegisterDeviceToken: String?
    var lastRegisterEnvironment: PushAPNSEnvironment?
    var lastRegisterAuthorizationStatus: PushAuthorizationStatus?

    func registerDevice(
      deviceToken: String,
      apnsEnvironment: PushAPNSEnvironment,
      authorizationStatus: PushAuthorizationStatus
    ) async throws -> PushDeviceRegistrationResponse {
      registerCalls += 1
      lastRegisterDeviceToken = deviceToken
      lastRegisterEnvironment = apnsEnvironment
      lastRegisterAuthorizationStatus = authorizationStatus
      return PushDeviceRegistrationResponse(
        id: "device-1",
        deviceToken: deviceToken,
        platform: .ios,
        apnsEnvironment: apnsEnvironment,
        authorizationStatus: authorizationStatus,
        isActive: true,
        lastSeenAt: "2026-04-10T10:30:00Z"
      )
    }

    func deactivateDevice(deviceToken _: String) async throws {
      deactivateCalls += 1
    }
  }

  private final class PushPermissionProviderMock: PushPermissionProviding, @unchecked Sendable {
    var status: PushAuthorizationStatus
    var requestAuthorizationCalls = 0

    init(status: PushAuthorizationStatus) {
      self.status = status
    }

    func requestAuthorization() async throws -> Bool {
      requestAuthorizationCalls += 1
      return true
    }

    func currentAuthorizationStatus() async -> PushAuthorizationStatus {
      status
    }
  }

  private final class PushRemoteRegistrarMock: PushRemoteNotificationsRegistering, @unchecked Sendable {
    var registerCalls = 0
    var openSettingsCalls = 0

    func registerForRemoteNotifications() {
      registerCalls += 1
    }

    func openSystemSettings() {
      openSettingsCalls += 1
    }
  }

  private final class SessionStoreMock: AuthSessionStoring, @unchecked Sendable {
    var authToken: String = ""
    func setAuthToken(_ value: String) async { authToken = value }

    var refreshToken: String = ""
    func setRefreshToken(_ value: String) async { refreshToken = value }

    var authTokenExpiresAt: Date?
    func setAuthTokenExpiresAt(_ value: Date?) async { authTokenExpiresAt = value }

    var refreshTokenExpiresAt: Date?
    func setRefreshTokenExpiresAt(_ value: Date?) async { refreshTokenExpiresAt = value }

    var loginIsSignup: Bool = true
    func setLoginIsSignup(_ value: Bool) async { loginIsSignup = value }

    var currentUserID: String = ""
    func setCurrentUserID(_ value: String) async { currentUserID = value }

    var currentUsername: String = ""
    func setCurrentUsername(_ value: String) async { currentUsername = value }

    func store(authResponse _: AuthResponse) async {}
    func clearSession() async {}
    func hasCompletedInitialStockImport(for _: String) async -> Bool { false }
    func markInitialStockImportCompleted(for _: String) async {}
  }

  private func makeDefaults() -> UserDefaults {
    let suiteName = "PushNotificationsCoordinatorTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }

  private func waitForCoordinatorTasks() async {
    await Task.yield()
    await Task.yield()
    await Task.yield()
  }

  func testHandleAuthenticatedSession_ShowsExplainerForFirstTimeUndeterminedStatus() async {
    let service = PushNotificationsServiceMock()
    let permission = PushPermissionProviderMock(status: .notDetermined)
    let registrar = PushRemoteRegistrarMock()
    let sessionStore = SessionStoreMock()
    await sessionStore.setCurrentUserID("user-1")

    let coordinator = PushNotificationsCoordinator(
      service: service,
      permissionProvider: permission,
      remoteRegistrar: registrar,
      sessionStore: sessionStore,
      userDefaults: makeDefaults(),
      environmentResolver: { .development }
    )

    coordinator.handleAuthenticatedSessionBecameActive()
    await waitForCoordinatorTasks()

    XCTAssertTrue(coordinator.showPostLoginExplainer)
    XCTAssertFalse(coordinator.isOptedIn)
    XCTAssertEqual(coordinator.authorizationStatus, .notDetermined)
  }

  func testEnableFromExplainer_TransitionsToRegisteredStateWhenPermissionGranted() async {
    let service = PushNotificationsServiceMock()
    let permission = PushPermissionProviderMock(status: .notDetermined)
    let registrar = PushRemoteRegistrarMock()
    let sessionStore = SessionStoreMock()
    await sessionStore.setCurrentUserID("user-1")

    let coordinator = PushNotificationsCoordinator(
      service: service,
      permissionProvider: permission,
      remoteRegistrar: registrar,
      sessionStore: sessionStore,
      userDefaults: makeDefaults(),
      environmentResolver: { .development }
    )

    coordinator.didRegisterForRemoteNotifications(deviceTokenData: Data([0xAA, 0xBB, 0xCC]))
    permission.status = .authorized

    await coordinator.enableFromExplainer()
    await waitForCoordinatorTasks()

    XCTAssertFalse(coordinator.showPostLoginExplainer)
    XCTAssertTrue(coordinator.isOptedIn)
    XCTAssertEqual(permission.requestAuthorizationCalls, 1)
    XCTAssertGreaterThanOrEqual(registrar.registerCalls, 1)
    XCTAssertGreaterThanOrEqual(service.registerCalls, 1)
    XCTAssertEqual(service.lastRegisterDeviceToken, "aabbcc")
    XCTAssertEqual(service.lastRegisterEnvironment, .development)
    XCTAssertEqual(service.lastRegisterAuthorizationStatus, .authorized)
  }

  func testSetNotificationsEnabledFalse_DeactivatesToken() async {
    let service = PushNotificationsServiceMock()
    let permission = PushPermissionProviderMock(status: .authorized)
    let registrar = PushRemoteRegistrarMock()
    let sessionStore = SessionStoreMock()
    await sessionStore.setCurrentUserID("user-1")

    let coordinator = PushNotificationsCoordinator(
      service: service,
      permissionProvider: permission,
      remoteRegistrar: registrar,
      sessionStore: sessionStore,
      userDefaults: makeDefaults(),
      environmentResolver: { .development }
    )

    coordinator.didRegisterForRemoteNotifications(deviceTokenData: Data([0xAA, 0xBB]))
    await coordinator.setNotificationsEnabled(false)

    XCTAssertFalse(coordinator.isOptedIn)
    XCTAssertEqual(service.deactivateCalls, 1)
  }

  func testHandleIncomingRemoteNotification_OpenPortfolioAction_QueuesPortfolioRoute() async {
    let service = PushNotificationsServiceMock()
    let permission = PushPermissionProviderMock(status: .authorized)
    let registrar = PushRemoteRegistrarMock()
    let sessionStore = SessionStoreMock()
    await sessionStore.setCurrentUserID("user-1")

    let coordinator = PushNotificationsCoordinator(
      service: service,
      permissionProvider: permission,
      remoteRegistrar: registrar,
      sessionStore: sessionStore,
      userDefaults: makeDefaults(),
      environmentResolver: { .development }
    )

    coordinator.handleIncomingRemoteNotification(
      userInfo: [
        "type": "target_hit",
        "symbol": "AAPL",
        "scenario": "bull"
      ],
      userAction: .openPortfolio
    )

    let route = coordinator.consumePendingNotificationRoute()
    XCTAssertEqual(route?.kind, .openPortfolio)
    XCTAssertEqual(route?.symbol, "AAPL")
    XCTAssertEqual(route?.scenario, "bull")
  }

  func testPayloadParser_ParsesTargetHitPayload() {
    let route = PushNotificationPayloadParser.parse(
      userInfo: [
        "type": "target_hit",
        "symbol": "MSFT",
        "scenario": "base",
        "targetId": "target-1",
        "deepLink": "financeplan://stocks/MSFT"
      ]
    )

    XCTAssertEqual(route?.kind, .targetHit)
    XCTAssertEqual(route?.symbol, "MSFT")
    XCTAssertEqual(route?.scenario, "base")
    XCTAssertEqual(route?.targetID, "target-1")
    XCTAssertEqual(route?.deepLink, "financeplan://stocks/MSFT")
  }
}
