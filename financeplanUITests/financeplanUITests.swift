//
//  financeplanUITests.swift
//  financeplanUITests
//
//  Created by Fernando Correia on 12.02.26.
//

import Foundation
import XCTest

final class FinanceplanUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testFirstLoginAuthenticatedUser_IsBlockedByMandatoryImportScreen() throws {
    let app = makeAuthenticatedFirstLoginApp(userID: "ui-test-\(UUID().uuidString)")
    app.launch()

    let importTitle = app.staticTexts["Import Your Stocks"]
    XCTAssertTrue(
      importTitle.waitForExistence(timeout: 15),
      "Expected the mandatory import screen to appear for first login."
    )

    let continueButton = app.buttons["Select a Method"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 8))
    XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled until an import method is selected.")
    XCTAssertFalse(app.tabBars.buttons["Home"].exists, "Home flow should not be reachable before import selection.")
  }

  @MainActor
  func testSelectingImportMethod_TransitionsToHome() throws {
    let app = makeAuthenticatedFirstLoginApp(userID: "ui-test-\(UUID().uuidString)")
    app.launch()

    completeImportViaCSV(in: app)

    XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 15))
    XCTAssertTrue(app.staticTexts["Portfolio Value"].waitForExistence(timeout: 15))
    XCTAssertFalse(app.staticTexts["Import Your Stocks"].exists)
  }

  @MainActor
  func testCompletedImport_IsRememberedForSameUser() throws {
    let userID = "ui-test-\(UUID().uuidString)"
    let firstLaunchApp = makeAuthenticatedFirstLoginApp(userID: userID)
    firstLaunchApp.launch()

    completeImportViaCSV(in: firstLaunchApp)
    XCTAssertTrue(firstLaunchApp.tabBars.buttons["Home"].waitForExistence(timeout: 15))
    firstLaunchApp.terminate()

    let secondLaunchApp = makeAuthenticatedFirstLoginApp(userID: userID, resetSession: false)
    secondLaunchApp.launch()

    XCTAssertTrue(secondLaunchApp.tabBars.buttons["Home"].waitForExistence(timeout: 15))
    XCTAssertTrue(secondLaunchApp.staticTexts["Portfolio Value"].waitForExistence(timeout: 15))
    XCTAssertFalse(
      secondLaunchApp.staticTexts["Import Your Stocks"].exists,
      "The same user should skip the initial import gate after completing it once."
    )
  }

  @MainActor
  private func completeImportViaCSV(in app: XCUIApplication) {
    XCTAssertTrue(app.staticTexts["Import Your Stocks"].waitForExistence(timeout: 15))
    let csvMethodButton = app.buttons.containing(.staticText, identifier: "Import CSV").firstMatch
    XCTAssertTrue(csvMethodButton.waitForExistence(timeout: 8))
    csvMethodButton.tap()

    let continueButton = app.buttons["Continue with Import CSV"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 8))
    XCTAssertTrue(continueButton.isEnabled)
    continueButton.tap()
  }

  private func makeAuthenticatedFirstLoginApp(userID: String, resetSession: Bool = true) -> XCUIApplication {
    let app = XCUIApplication()
    var launchArguments = [
      "-ui_test_skip_splash",
      "-ui_test_auth_token",
      "ui-test-token",
      "-ui_test_user_id",
      userID
    ]
    if resetSession {
      launchArguments.append("-ui_test_reset_session")
    }
    app.launchArguments += launchArguments
    return app
  }
}
