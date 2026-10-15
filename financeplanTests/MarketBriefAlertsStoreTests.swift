import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class MarketBriefAlertsStoreTests: XCTestCase {
  func testTurningOnAsksForPushThenWritesTheLanguage() async {
    let service = MarketBriefServiceStub()
    var optInRequests = 0
    let store = MarketBriefAlertsStore(service: service, ensurePushOptIn: {
      optInRequests += 1
      return true
    })

    await store.setEnabled(true, language: "pt-PT")

    XCTAssertEqual(optInRequests, 1)
    XCTAssertEqual(service.updates, [MarketBriefNotificationPreferences(enabled: true, language: "pt-PT")])
    XCTAssertTrue(store.isEnabled)
  }

  func testDeclinedPushLeavesTheSwitchOffAndWritesNothing() async {
    let service = MarketBriefServiceStub()
    let store = MarketBriefAlertsStore(service: service, ensurePushOptIn: { false })

    await store.setEnabled(true, language: "en")

    XCTAssertFalse(store.isEnabled)
    XCTAssertTrue(service.updates.isEmpty)
  }

  func testTurningOffNeedsNoPushPermission() async {
    let service = MarketBriefServiceStub()
    service.preferences = MarketBriefNotificationPreferences(enabled: true, language: "en")
    var optInRequests = 0
    let store = MarketBriefAlertsStore(service: service, ensurePushOptIn: {
      optInRequests += 1
      return true
    })
    await store.load(language: "en")

    await store.setEnabled(false, language: "en")

    XCTAssertEqual(optInRequests, 0)
    XCTAssertFalse(store.isEnabled)
    XCTAssertEqual(service.updates.last?.enabled, false)
  }

  func testFailedWriteRollsBack() async {
    let service = MarketBriefServiceStub()
    service.updateError = URLError(.notConnectedToInternet)
    let store = MarketBriefAlertsStore(service: service, ensurePushOptIn: { true })

    await store.setEnabled(true, language: "en")

    XCTAssertFalse(store.isEnabled)
    XCTAssertNotNil(store.errorMessage)
  }

  func testLanguageChangeRewritesWhileEnabled() async {
    let service = MarketBriefServiceStub()
    let store = MarketBriefAlertsStore(service: service, ensurePushOptIn: { true })
    await store.setEnabled(true, language: "en")

    await store.languageChanged(to: "pt-PT")

    XCTAssertEqual(service.updates.last, MarketBriefNotificationPreferences(enabled: true, language: "pt-PT"))
    XCTAssertEqual(store.serverLanguage, "pt-PT")
  }

  func testLanguageChangeWhileOffWritesNothing() async {
    let service = MarketBriefServiceStub()
    let store = MarketBriefAlertsStore(service: service, ensurePushOptIn: { true })
    await store.load(language: "en")

    await store.languageChanged(to: "pt-PT")

    XCTAssertTrue(service.updates.isEmpty)
  }

  func testLoadRewritesAStaleServerLanguage() async {
    let service = MarketBriefServiceStub()
    service.preferences = MarketBriefNotificationPreferences(enabled: true, language: "en")
    let store = MarketBriefAlertsStore(service: service, ensurePushOptIn: { true })

    await store.load(language: "pt-PT")

    XCTAssertEqual(service.updates, [MarketBriefNotificationPreferences(enabled: true, language: "pt-PT")])
    XCTAssertTrue(store.isEnabled)
  }
}
