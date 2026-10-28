import Foundation
import XCTest
@testable import financeplan

@MainActor
final class AchievementsPushTests: XCTestCase {
  func testUnlockPushParses() {
    let route = PushNotificationPayloadParser.parse(userInfo: ["schemaVersion": 1, "type": "achievement_unlocked"])
    XCTAssertEqual(route?.kind, .achievementUnlocked)
  }

  func testCongratsPushParses() {
    let route = PushNotificationPayloadParser.parse(userInfo: ["schemaVersion": 1, "type": "achievement_congrats"])
    XCTAssertEqual(route?.kind, .achievementCongrats)
  }

  func testUnknownKindsKeepFallingBackToATargetHit() {
    let route = PushNotificationPayloadParser.parse(userInfo: ["type": "something_newer", "symbol": "AAPL"])
    XCTAssertEqual(route?.kind, .targetHit)
  }

  func testUnlockPushesOpenAchievementsAndCongratsOpenTheFeed() {
    XCTAssertEqual(AchievementPushDestination.destination(for: .achievementUnlocked), .achievements)
    XCTAssertEqual(AchievementPushDestination.destination(for: .achievementCongrats), .feed)
    XCTAssertNil(AchievementPushDestination.destination(for: .friendRequest))
  }

  func testDeviceRegistrationAdvertisesAchievements() {
    XCTAssertTrue(PushNotificationsService.deviceCapabilities.contains("achievements_v1"))
    XCTAssertTrue(PushNotificationsService.deviceCapabilities.contains("rebalance_drift_v1"))
  }
}
