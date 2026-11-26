import XCTest

/// The five-tab shell and its hubs, in the real app with a fake session.
///
/// It runs against the `local` environment, localhost:8080, where a refused
/// connection or a 404 leaves the session alone. The hub rows these tests tap
/// are fixed, so no server is needed.
final class NavigationUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  private func launch(billingTier: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchAuthenticatedWithExpenses(userID: "nav-ui-test", billingTier: billingTier)
    return app
  }

  /// A Pro row tapped by a free user presents the paywall over More. Nothing
  /// is pushed and the tab does not change, before or after the paywall closes.
  @MainActor
  func testFreeUserInsightsRowOpensPaywallWithoutLeavingMore() {
    let app = launch(billingTier: "free")
    app.openMoreRow("insights")

    let paywall = app.descendants(matching: .any)["PaywallView"].firstMatch
    XCTAssertTrue(paywall.waitForExistence(timeout: 5), "Paywall did not open")
    let insights = app.descendants(matching: .any)["insights.screen"].firstMatch
    XCTAssertFalse(insights.exists, "Insights opened under the paywall")
    XCTAssertTrue(app.tabButton(.more).isSelected, "Left More for the paywall")

    app.buttons["Close"].firstMatch.tap()
    XCTAssertTrue(paywall.waitForNonExistence(timeout: 5), "Paywall did not close")
    XCTAssertTrue(app.buttons["hub.row.insights"].waitForExistence(timeout: 5), "Not back on More's list")
    XCTAssertFalse(insights.exists, "Insights opened after the paywall closed")
    XCTAssertTrue(app.tabButton(.more).isSelected, "More is no longer the selected tab")
  }
}
