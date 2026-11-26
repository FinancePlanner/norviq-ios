import XCTest

/// The five tabs, by the labels the app shows in English and pt-PT.
enum UITestTab {
  case today
  case money
  case wealth
  case plan
  case more

  var labels: [String] {
    switch self {
    case .today: ["Today", "Hoje"]
    case .money: ["Money", "Dinheiro"]
    case .wealth: ["Wealth", "Património"]
    case .plan: ["Plan", "Plano"]
    case .more: ["More", "Mais"]
    }
  }
}

extension XCUIApplication {
  /// A Debug build talks to production unless told otherwise, and production
  /// answers the fake token with a 401 that signs the app out. The `local`
  /// environment, localhost:8080, refuses or 404s instead and the session stays.
  func useLocalAPI() {
    launchEnvironment["NORVIQ_ENVIRONMENT"] = "local"
  }

  func launchAuthenticatedWithExpenses(userID: String, resetSession: Bool = true, billingTier: String? = nil) {
    useLocalAPI()
    var args = [
      "-ui_test_skip_splash",
      "-ui_test_auth_token", "ui-test-token",
      "-ui_test_user_id", userID,
      "-ui_test_imported_user_id", userID
    ]
    if resetSession {
      args.append("-ui_test_reset_session")
    }
    if let billingTier {
      args += ["-ui_test_billing_tier", billingTier]
    }
    launchArguments += args
    launch()
  }

  /// The tab's button, in either language. There is no fallback by index: a
  /// missing tab fails here rather than tapping its neighbour.
  func tabButton(_ tab: UITestTab) -> XCUIElement {
    tabBars.buttons.matching(NSPredicate(format: "label IN %@", tab.labels)).firstMatch
  }

  /// Taps the tab once the shell is up, after closing the notifications
  /// prompt a new user gets over it.
  func tapTab(_ tab: UITestTab, timeout: TimeInterval = 25, file: StaticString = #filePath, line: UInt = #line) {
    let button = tabButton(tab)
    XCTAssertTrue(
      button.waitForExistence(timeout: timeout), "No \(tab.labels.joined(separator: "/")) tab", file: file, line: line)
    dismissNotificationsPromptIfPresent()
    button.tap()
  }

  /// Reports is a row in More's Intelligence section.
  func tapReportsTab() {
    openMoreRow("reports")
  }

  /// More › Settings. The Today avatar opens it too; this is the hub's way.
  func openSettings() {
    openMoreRow("settings")
  }

  /// Opens a More row by its id (`hub.row.<id>`), scrolling the hub to it.
  func openMoreRow(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
    tapTab(.more, file: file, line: line)
    XCTAssertTrue(buttons["hub.account"].waitForExistence(timeout: 10), "More did not open", file: file, line: line)
    // The list is lazy: a row below the fold does not exist until scrolled to.
    let row = buttons["hub.row.\(id)"]
    var swipes = 0
    while !(row.waitForExistence(timeout: 2) && row.isHittable), swipes < 4 {
      swipeUp()
      swipes += 1
    }
    XCTAssertTrue(row.isHittable, "No \(id) row in More", file: file, line: line)
    row.tap()
  }

  /// A new user is asked about notifications over the dashboard. Both
  /// buttons close it; "Not now" leaves the system prompt alone.
  func dismissNotificationsPromptIfPresent(timeout: TimeInterval = 5) {
    let notNow = buttons["Not now"]
    guard notNow.waitForExistence(timeout: timeout) else { return }
    notNow.tap()
    _ = notNow.waitForNonExistence(timeout: 3)
  }

  func dismissKeyboardIfPresent() {
    if keyboards.firstMatch.exists {
      let done = keyboards.buttons["Done"].firstMatch
      if done.exists {
        done.tap()
      }
    }
  }
}
