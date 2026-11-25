import Foundation

/// Decides whether Sentry starts for this process.
///
/// Automated test runs must not report: simulators under `xcodebuild test`
/// routinely block the main thread for seconds (snapshot rendering, simulator
/// shutdown), and each block reached Sentry as an "App Hang" alert in the
/// `development` environment.
nonisolated enum SentryStartupPolicy {
  /// `true` for hosted unit tests (XCTest injects `XCTestConfigurationFilePath`)
  /// and for UI tests (every UI test launches the app with `-ui_test_*` arguments).
  static func isAutomatedTestRun(
    arguments: [String] = ProcessInfo.processInfo.arguments,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> Bool {
    environment["XCTestConfigurationFilePath"] != nil
      || arguments.contains { $0.hasPrefix("-ui_test_") }
  }
}
