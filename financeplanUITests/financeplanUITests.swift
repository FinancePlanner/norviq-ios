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

    let importStocksButton = app.buttons["onboarding.importStocksButton"]
    XCTAssertTrue(
      importStocksButton.waitForExistence(timeout: 20),
      "Expected onboarding import gate to appear for first login."
    )
    XCTAssertFalse(app.tabBars.buttons["Home"].exists, "Home flow should not be reachable before import selection.")

    importStocksButton.tap()

    let importScreen = app.otherElements["initialStockImportScreen"]
    XCTAssertTrue(importScreen.waitForExistence(timeout: 8))

    let continueButton = app.buttons["stockImportContinueButton"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 8))
    XCTAssertFalse(continueButton.isEnabled, "Continue should be disabled until an import method is selected.")
  }

  @MainActor
  func testSelectingImportMethod_TransitionsToHome() throws {
    let app = makeAuthenticatedFirstLoginApp(userID: "ui-test-\(UUID().uuidString)")
    app.launch()

    completeMandatoryImport(in: app)

    XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 15))
    XCTAssertTrue(app.staticTexts["Portfolio Value"].waitForExistence(timeout: 15))
    XCTAssertFalse(app.staticTexts["Import Your Portfolio"].exists)
  }

  @MainActor
  func testCompletedImport_IsRememberedForSameUser() throws {
    let userID = "ui-test-\(UUID().uuidString)"
    let firstLaunchApp = makeAuthenticatedFirstLoginApp(userID: userID)
    firstLaunchApp.launch()

    completeMandatoryImport(in: firstLaunchApp)
    XCTAssertTrue(firstLaunchApp.tabBars.buttons["Home"].waitForExistence(timeout: 15))
    firstLaunchApp.terminate()

    let secondLaunchApp = makeAuthenticatedFirstLoginApp(userID: userID, resetSession: false)
    secondLaunchApp.launch()

    XCTAssertTrue(secondLaunchApp.tabBars.buttons["Home"].waitForExistence(timeout: 15))
    XCTAssertTrue(secondLaunchApp.staticTexts["Portfolio Value"].waitForExistence(timeout: 15))
    XCTAssertFalse(
      secondLaunchApp.staticTexts["Import Your Portfolio"].exists,
      "The same user should skip the initial import gate after completing it once."
    )
  }

  @MainActor
  func testPortfolioCSVImportSheetCanBeOpenedFromToolbar() throws {
    let app = makeAuthenticatedImportedUserApp(userID: "ui-test-\(UUID().uuidString)")
    app.launch()

    let portfolioTab = app.tabBars.buttons["Portfolio"]
    XCTAssertTrue(portfolioTab.waitForExistence(timeout: 25))
    portfolioTab.tap()

    let actionsMenu = app.buttons["portfolio.actionsMenu"]
    XCTAssertTrue(actionsMenu.waitForExistence(timeout: 8))
    actionsMenu.tap()

    let importAction = app.buttons["Import CSV"]
    XCTAssertTrue(importAction.waitForExistence(timeout: 8))
    importAction.tap()

    XCTAssertTrue(app.otherElements["portfolioCSVImportSheet"].waitForExistence(timeout: 8))
  }

  @MainActor
  private func completeMandatoryImport(in app: XCUIApplication) {
    let importStocksButton = app.buttons["onboarding.importStocksButton"]
    XCTAssertTrue(importStocksButton.waitForExistence(timeout: 20))
    importStocksButton.tap()

    XCTAssertTrue(app.otherElements["initialStockImportScreen"].waitForExistence(timeout: 8))
    let apiMethodButton = app.buttons["stockImportMethod.api"]
    XCTAssertTrue(apiMethodButton.waitForExistence(timeout: 8))
    apiMethodButton.tap()

    let continueButton = app.buttons["stockImportContinueButton"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 8))
    XCTAssertTrue(continueButton.isEnabled)
    continueButton.tap()

    let apiContinueButton = app.buttons["Continue"]
    XCTAssertTrue(apiContinueButton.waitForExistence(timeout: 8))
    apiContinueButton.tap()

    let successTitle = app.staticTexts["All Set!"]
    XCTAssertTrue(successTitle.waitForExistence(timeout: 8))
    let goToHomeButton = app.buttons["Go to Home"]
    XCTAssertTrue(goToHomeButton.waitForExistence(timeout: 8))
    goToHomeButton.tap()
  }

  @MainActor
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

  @MainActor
  private func makeAuthenticatedImportedUserApp(userID: String, resetSession: Bool = true) -> XCUIApplication {
    let app = XCUIApplication()
    var launchArguments = [
      "-ui_test_skip_splash",
      "-ui_test_auth_token",
      "ui-test-token",
      "-ui_test_user_id",
      userID,
      "-ui_test_imported_user_id",
      userID
    ]
    if resetSession {
      launchArguments.append("-ui_test_reset_session")
    }
    app.launchArguments += launchArguments
    return app
  }
}
