import XCTest

@testable import financeplan

@MainActor
final class AppEnvironmentManagerTests: XCTestCase {
  private let defaultsSuiteName = "AppEnvironmentManagerTests"
  private var defaults: UserDefaults!

  override func setUp() async throws {
    defaults = UserDefaults(suiteName: defaultsSuiteName)
    defaults.removePersistentDomain(forName: defaultsSuiteName)
  }

  override func tearDown() async throws {
    defaults.removePersistentDomain(forName: defaultsSuiteName)
    defaults = nil
  }

  func testLegacyDevBuildSettingFallsBackToProductionForArchives() {
    let manager = AppEnvironmentManager(
      environmentVariables: [:],
      infoDictionary: ["NorviqAPIEnvironment": "dev"],
      defaults: defaults,
      schemeEnvironmentValue: nil,
      isDebugBuild: false
    )

    XCTAssertEqual(manager.current, AppEnvironments.production)
    XCTAssertNil(manager.schemeEnvironment)
  }

  func testBuildSettingForcesProductionEnvironmentForAppStoreRelease() {
    let manager = AppEnvironmentManager(
      environmentVariables: [:],
      infoDictionary: ["NorviqAPIEnvironment": "production"],
      defaults: defaults,
      schemeEnvironmentValue: nil,
      isDebugBuild: false
    )

    XCTAssertEqual(manager.current, AppEnvironments.production)
    XCTAssertEqual(manager.schemeEnvironment, AppEnvironments.production)
  }

  func testPersistedEnvironmentDoesNotOverrideForcedBuildEnvironment() {
    defaults.set(AppEnvironments.production.title, forKey: "environment")

    let manager = AppEnvironmentManager(
      environmentVariables: [:],
      infoDictionary: ["NorviqAPIEnvironment": "production"],
      defaults: defaults,
      schemeEnvironmentValue: nil,
      isDebugBuild: false
    )

    XCTAssertEqual(manager.current, AppEnvironments.production)
  }

  func testPersistedEnvironmentOnlyAppliesToDebugBuilds() {
    defaults.set("dev", forKey: "environment")

    let manager = AppEnvironmentManager(
      environmentVariables: [:],
      infoDictionary: [:],
      defaults: defaults,
      schemeEnvironmentValue: nil,
      isDebugBuild: false,
      isTestFlight: false
    )

    XCTAssertEqual(manager.current, AppEnvironments.production)
  }

  func testDebugBuildDefaultsToLocal() {
    let manager = AppEnvironmentManager(
      environmentVariables: [:],
      infoDictionary: [:],
      defaults: defaults,
      schemeEnvironmentValue: nil,
      isDebugBuild: true,
      isTestFlight: false
    )

    XCTAssertEqual(manager.current, AppEnvironments.local)
  }

  func testTestFlightDefaultsToProduction() {
    let manager = AppEnvironmentManager(
      environmentVariables: [:],
      infoDictionary: [:],
      defaults: defaults,
      schemeEnvironmentValue: nil,
      isDebugBuild: false,
      isTestFlight: true
    )

    XCTAssertEqual(manager.current, AppEnvironments.production)
  }

  func testAllowedEnvironmentsReturnsAllCasesWhenLocal() {
    let manager = AppEnvironmentManager(
      environmentVariables: [:],
      infoDictionary: [:],
      defaults: defaults,
      schemeEnvironmentValue: nil,
      isDebugBuild: true,
      isTestFlight: false
    )
    XCTAssertEqual(manager.allowedEnvironmentsWhen(isLoggedIn: false), AppEnvironments.allCases)
  }

  func testAllowedEnvironmentsReturnsEmptyWhenProduction() {
    let manager = AppEnvironmentManager(
      environmentVariables: ["NORVIQ_ENVIRONMENT": "production"],
      infoDictionary: [:],
      defaults: defaults,
      schemeEnvironmentValue: nil,
      isDebugBuild: true,
      isTestFlight: false
    )
    XCTAssertTrue(manager.allowedEnvironmentsWhen(isLoggedIn: false).isEmpty)
  }
}
