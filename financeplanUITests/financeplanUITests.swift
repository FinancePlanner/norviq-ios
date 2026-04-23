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
  func testExpensesAndReportsFlow() throws {
    let app = makeAuthenticatedImportedUserApp(userID: "ui-test-\(UUID().uuidString)")
    app.launch()

    // 1. Navigate to Expenses tab
    let expensesTab = app.tabBars.buttons["Expenses"]
    XCTAssertTrue(expensesTab.waitForExistence(timeout: 25))
    expensesTab.tap()

    // 2. Create a plan if missing (using the 'Create' button in the missing budget alert)
    let createPlanButton = app.buttons["Create"]
    if createPlanButton.waitForExistence(timeout: 5) {
      createPlanButton.tap()
    }

    // 3. Add a planned item
    let addPlannedItemButton = app.buttons["Add planned item"]
    XCTAssertTrue(addPlannedItemButton.waitForExistence(timeout: 10))
    addPlannedItemButton.tap()

    let nameField = app.textFields["Name"]
    XCTAssertTrue(nameField.waitForExistence(timeout: 5))
    nameField.tap()
    nameField.typeText("UI Test Item")

    let amountField = app.textFields["Planned amount"]
    amountField.tap()
    amountField.typeText("100")

    app.buttons["Save"].tap()

    // 4. Record an expense
    let recordSpendButton = app.buttons["Record spend"]
    XCTAssertTrue(recordSpendButton.waitForExistence(timeout: 10))
    recordSpendButton.tap()

    let expenseTitleField = app.textFields["Title"]
    XCTAssertTrue(expenseTitleField.waitForExistence(timeout: 5))
    expenseTitleField.tap()
    expenseTitleField.typeText("UI Test Expense")

    let expenseAmountField = app.textFields["Amount"]
    expenseAmountField.tap()
    expenseAmountField.typeText("50")

    app.buttons["Save"].tap()

    // 5. Navigate to Reports tab
    let reportsTab = app.tabBars.buttons["Reports"]
    XCTAssertTrue(reportsTab.waitForExistence(timeout: 10))
    reportsTab.tap()

    // 6. Verify reports show data
    // The Reports screen has a Segmented Picker: Overview, Portfolio, Spending, Trends
    // We want to check Spending.
    let spendingSegment = app.buttons["Spending"]
    XCTAssertTrue(spendingSegment.waitForExistence(timeout: 10))
    spendingSegment.tap()

    // Verify "Household Spending" or some charts exist
    XCTAssertTrue(app.staticTexts["Household Spending"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["UI Test Item"].exists || app.staticTexts["Fundamentals"].exists)
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
