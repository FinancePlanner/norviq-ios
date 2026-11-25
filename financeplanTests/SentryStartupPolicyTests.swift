@testable import financeplan
import XCTest

final class SentryStartupPolicyTests: XCTestCase {
  func testHostedUnitTestRunIsDetected() {
    XCTAssertTrue(SentryStartupPolicy.isAutomatedTestRun(
      arguments: ["financeplan"],
      environment: ["XCTestConfigurationFilePath": "/tmp/x.xctestconfiguration"]
    ))
  }

  func testUITestLaunchArgumentIsDetected() {
    XCTAssertTrue(SentryStartupPolicy.isAutomatedTestRun(
      arguments: ["financeplan", "-ui_test_skip_splash"],
      environment: [:]
    ))
  }

  func testNormalLaunchIsNotATestRun() {
    XCTAssertFalse(SentryStartupPolicy.isAutomatedTestRun(
      arguments: ["financeplan", "-AppleLanguages", "(pt-PT)"],
      environment: ["SIMULATOR_DEVICE_NAME": "iPhone 17"]
    ))
  }

  func testThisProcessIsATestRun() {
    XCTAssertTrue(SentryStartupPolicy.isAutomatedTestRun())
  }
}
