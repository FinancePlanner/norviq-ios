import XCTest

extension XCUIApplication {
  func launchAuthenticatedWithExpenses(userID: String, resetSession: Bool = true) {
    var args = [
      "-ui_test_skip_splash",
      "-ui_test_auth_token", "ui-test-token",
      "-ui_test_user_id", userID,
      "-ui_test_imported_user_id", userID
    ]
    if resetSession {
      args.append("-ui_test_reset_session")
    }
    launchArguments += args
    launch()
  }

  func tapExpensesTab() {
    let tab = tabBars.buttons["Expenses"]
    if tab.waitForExistence(timeout: 2) {
      tab.tap()
      return
    }
    let ptTab = tabBars.buttons["Despesas"]
    if ptTab.waitForExistence(timeout: 2) {
      ptTab.tap()
      return
    }
    tabBars.buttons.element(boundBy: 2).tap()
  }

  func tapReportsTab() {
    let tab = tabBars.buttons["Reports"]
    if tab.waitForExistence(timeout: 2) {
      tab.tap()
      return
    }
    let ptTab = tabBars.buttons["Relatórios"]
    if ptTab.waitForExistence(timeout: 2) {
      ptTab.tap()
      return
    }
    tabBars.buttons.element(boundBy: 3).tap()
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
