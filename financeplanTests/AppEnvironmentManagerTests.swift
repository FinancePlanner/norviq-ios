import XCTest

@testable import financeplan

@MainActor
final class AppEnvironmentManagerTests: XCTestCase {
  // Unique per instance. A fixed suite name is shared process-wide, so these
  // tests raced any other suite touching the same domain once the whole bundle
  // started running together.
  private let defaultsSuiteName = "AppEnvironmentManagerTests.\(UUID().uuidString)"
  private var defaults: UserDefaults!

  override func setUp() async throws {
    // UserDefaults(suiteName:) is failable, and `defaults` is implicitly
    // unwrapped — a nil here raised SIGABRT and took the whole test host down
    // with it, reporting every later test in the run as a 0.000s crash rather
    // than pointing at this line. XCTUnwrap keeps it a single test failure.
    defaults = try XCTUnwrap(
      UserDefaults(suiteName: defaultsSuiteName),
      "Could not open UserDefaults suite \(defaultsSuiteName)"
    )
    defaults.removePersistentDomain(forName: defaultsSuiteName)
  }

  override func tearDown() async throws {
    defaults?.removePersistentDomain(forName: defaultsSuiteName)
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
