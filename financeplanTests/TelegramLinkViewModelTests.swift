import Foundation
import XCTest
@testable import financeplan

@MainActor
final class TelegramLinkViewModelTests: XCTestCase {
  private final class ServiceMock: TelegramLinkServiceProtocol, @unchecked Sendable {
    var statusResult: Result<TelegramStatus, Error> = .success(
      TelegramStatus(available: true, connected: false, botUsername: "norviq_bot", lastSeenAt: nil, connectedAt: nil)
    )
    var codeResult: Result<TelegramPairingCode, Error> = .success(
      TelegramPairingCode(
        code: "ABCD2345",
        expiresAt: Date().addingTimeInterval(900),
        deepLink: "https://t.me/norviq_bot?start=ABCD2345"
      )
    )
    var preferencesResult: Result<[TelegramAlertPreference], Error> = .success([])
    var disconnectError: Error?
    var statusCalls = 0
    var preferenceCalls: [(kind: String, enabled: Bool)] = []

    func status() async throws -> TelegramStatus {
      statusCalls += 1
      return try statusResult.get()
    }

    func createCode() async throws -> TelegramPairingCode {
      try codeResult.get()
    }

    func disconnect() async throws {
      if let disconnectError { throw disconnectError }
      statusResult = .success(
        TelegramStatus(available: true, connected: false, botUsername: "norviq_bot", lastSeenAt: nil, connectedAt: nil)
      )
    }

    func preferences() async throws -> [TelegramAlertPreference] {
      try preferencesResult.get()
    }

    func setAlert(kind: String, enabled: Bool) async throws -> [TelegramAlertPreference] {
      preferenceCalls.append((kind, enabled))
      return try preferencesResult.get()
    }
  }

  private enum MockError: LocalizedError {
    case offline
    var errorDescription: String? { "The network is unavailable." }
  }

  private func connectedStatus() -> TelegramStatus {
    TelegramStatus(
      available: true, connected: true, botUsername: "norviq_bot",
      lastSeenAt: Date(timeIntervalSince1970: 1_770_000_000), connectedAt: Date(timeIntervalSince1970: 1_769_000_000)
    )
  }

  func testLoadPublishesDisconnectedState() async {
    let service = ServiceMock()
    let viewModel = TelegramLinkViewModel(service: service)

    await viewModel.load()

    XCTAssertTrue(viewModel.isAvailable)
    XCTAssertFalse(viewModel.isConnected)
    XCTAssertEqual(viewModel.botHandle, "@norviq_bot")
    XCTAssertNil(viewModel.errorMessage)
  }

  // Alerts only mean something once there is a chat to deliver them to.
  func testLoadFetchesAlertsOnlyWhenConnected() async {
    let service = ServiceMock()
    service.preferencesResult = .success([
      TelegramAlertPreference(kind: "budget", enabled: true, quietHoursStart: nil, quietHoursEnd: nil, timezone: "UTC")
    ])
    let viewModel = TelegramLinkViewModel(service: service)

    await viewModel.load()
    XCTAssertTrue(viewModel.alerts.isEmpty, "an unlinked account has nowhere to deliver alerts")

    service.statusResult = .success(connectedStatus())
    await viewModel.load()
    XCTAssertEqual(viewModel.alerts.count, 1)
    XCTAssertEqual(viewModel.alerts.first?.label, "Budget alerts")
  }

  func testConnectPublishesAPairingCode() async {
    let service = ServiceMock()
    let viewModel = TelegramLinkViewModel(service: service)

    await viewModel.connect()

    XCTAssertEqual(viewModel.pairingCode?.code, "ABCD2345")
    XCTAssertEqual(viewModel.pairingCode?.deepLink, "https://t.me/norviq_bot?start=ABCD2345")
  }

  // The code is only useful until the link exists; leaving it on screen after
  // would invite the user to redeem something already spent.
  func testCodeIsClearedOnceConnected() async {
    let service = ServiceMock()
    let viewModel = TelegramLinkViewModel(service: service)
    await viewModel.connect()
    XCTAssertNotNil(viewModel.pairingCode)

    service.statusResult = .success(connectedStatus())
    await viewModel.load()

    XCTAssertNil(viewModel.pairingCode)
    XCTAssertTrue(viewModel.isConnected)
  }

  func testDisconnectReloadsStatus() async {
    let service = ServiceMock()
    service.statusResult = .success(connectedStatus())
    let viewModel = TelegramLinkViewModel(service: service)
    await viewModel.load()
    XCTAssertTrue(viewModel.isConnected)

    await viewModel.disconnect()

    XCTAssertFalse(viewModel.isConnected)
    XCTAssertNil(viewModel.pairingCode)
  }

  func testSetAlertForwardsTheRequestedState() async {
    let service = ServiceMock()
    let viewModel = TelegramLinkViewModel(service: service)

    await viewModel.setAlert(kind: "tax", enabled: true)

    XCTAssertEqual(service.preferenceCalls.count, 1)
    XCTAssertEqual(service.preferenceCalls.first?.kind, "tax")
    XCTAssertEqual(service.preferenceCalls.first?.enabled, true)
  }

  func testLoadSurfacesAnError() async {
    let service = ServiceMock()
    service.statusResult = .failure(MockError.offline)
    let viewModel = TelegramLinkViewModel(service: service)

    await viewModel.load()

    XCTAssertEqual(viewModel.errorMessage, "The network is unavailable.")
    XCTAssertFalse(viewModel.isAvailable)
  }

  // A build with no bot configured must not offer a Connect button that can
  // only fail.
  func testUnavailableDeploymentReportsUnavailable() async {
    let service = ServiceMock()
    service.statusResult = .success(
      TelegramStatus(available: false, connected: false, botUsername: "", lastSeenAt: nil, connectedAt: nil)
    )
    let viewModel = TelegramLinkViewModel(service: service)

    await viewModel.load()

    XCTAssertFalse(viewModel.isAvailable)
    XCTAssertEqual(viewModel.botHandle, "")
  }

  func testAlertLabelsFallBackToTheRawKind() {
    let known = TelegramAlertPreference(
      kind: "thesis_watch", enabled: false, quietHoursStart: nil, quietHoursEnd: nil, timezone: "UTC"
    )
    XCTAssertEqual(known.label, "Thesis watch")

    let unknown = TelegramAlertPreference(
      kind: "brand_new_kind", enabled: false, quietHoursStart: nil, quietHoursEnd: nil, timezone: "UTC"
    )
    XCTAssertEqual(unknown.label, "brand_new_kind", "an unknown kind should stay visible, not render blank")
  }
}
