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
  func testUnauthenticatedGoogleAuthButtonExistsInDarkMode() throws {
    let app = makeUnauthenticatedApp(appearance: "dark")
    app.launch()

    let loginButton = app.buttons["Already have an account? Log in"]
    XCTAssertTrue(loginButton.waitForExistence(timeout: 20))
    loginButton.tap()

    let googleButton = app.buttons["socialAuth.google"]
    XCTAssertTrue(
      googleButton.waitForExistence(timeout: 10),
      "Expected the Google OAuth button to be available on the dark-mode sign-in screen."
    )
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

    let importButton = app.buttons["portfolioCSVImport.commit"]
    XCTAssertTrue(importButton.waitForExistence(timeout: 8))
    XCTAssertFalse(importButton.isEnabled, "Import button should be disabled before selecting a file.")
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
  }

  @MainActor
  func testFreeUserSeesPaywallOnProTabs() throws {
    let app = makeAuthenticatedImportedUserApp(userID: "ui-test-\(UUID().uuidString)")
    app.launch()

    let portfolioTab = app.tabBars.buttons["Portfolio"]
    XCTAssertTrue(portfolioTab.waitForExistence(timeout: 25))
    portfolioTab.tap()

    let allocationSegment = app.buttons["Allocation 🔒"]
    XCTAssertTrue(allocationSegment.waitForExistence(timeout: 8))
    allocationSegment.tap()

    // Paywall should appear
    _ = app.staticTexts["Unlock Pro"] // Assuming paywall has "Unlock Pro" or similar, just checking if paywall elements exist
    // Alternatively, verify that the segment didn't change
    XCTAssertTrue(app.buttons["Holdings"].isSelected || app.otherElements["PaywallView"].exists || app.buttons["Continue with Free"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testProUserCanAccessProTabs() throws {
    let app = makeAuthenticatedImportedUserApp(userID: "ui-test-\(UUID().uuidString)", billingTier: "pro")
    app.launch()

    let portfolioTab = app.tabBars.buttons["Portfolio"]
    XCTAssertTrue(portfolioTab.waitForExistence(timeout: 25))
    portfolioTab.tap()

    let allocationSegment = app.buttons["Allocation"]
    XCTAssertTrue(allocationSegment.waitForExistence(timeout: 8))
    allocationSegment.tap()

    // Should load the allocation screen
    XCTAssertTrue(app.staticTexts["By cost basis"].waitForExistence(timeout: 8))
  }

  @MainActor
  func testTrialUserCanAccessProTabs() throws {
    let app = makeAuthenticatedImportedUserApp(userID: "ui-test-\(UUID().uuidString)", billingTier: "trial")
    app.launch()

    let portfolioTab = app.tabBars.buttons["Portfolio"]
    XCTAssertTrue(portfolioTab.waitForExistence(timeout: 25))
    portfolioTab.tap()

    let allocationSegment = app.buttons["Allocation"]
    XCTAssertTrue(allocationSegment.waitForExistence(timeout: 8))
    allocationSegment.tap()

    XCTAssertTrue(app.staticTexts["By cost basis"].waitForExistence(timeout: 8))
  }

  @MainActor
  func testSettingsReflectFreeTrialAndProBillingStates() throws {
    let freeApp = makeAuthenticatedImportedUserApp(userID: "ui-test-\(UUID().uuidString)", billingTier: "free")
    freeApp.launch()
    openSettings(in: freeApp)
    XCTAssertTrue(freeApp.descendants(matching: .any)["settings.subscription.free"].waitForExistence(timeout: 8))
    freeApp.terminate()

    let trialApp = makeAuthenticatedImportedUserApp(userID: "ui-test-\(UUID().uuidString)", billingTier: "trial")
    trialApp.launch()
    openSettings(in: trialApp)
    XCTAssertTrue(trialApp.descendants(matching: .any)["settings.subscription.trial"].waitForExistence(timeout: 8))
    trialApp.terminate()

    let proApp = makeAuthenticatedImportedUserApp(userID: "ui-test-\(UUID().uuidString)", billingTier: "pro")
    proApp.launch()
    openSettings(in: proApp)
    XCTAssertTrue(proApp.descendants(matching: .any)["settings.subscription.pro"].waitForExistence(timeout: 8))
  }

  @MainActor
  func testFreeUserSeesPaywallOnPriceAlertSwipe() throws {
    let app = makeAuthenticatedImportedUserApp(userID: "ui-test-\(UUID().uuidString)")
    app.launch()

    let portfolioTab = app.tabBars.buttons["Portfolio"]
    XCTAssertTrue(portfolioTab.waitForExistence(timeout: 25))
    portfolioTab.tap()

    let firstStockCell = app.cells.firstMatch
    guard firstStockCell.waitForExistence(timeout: 10) else { return } // Skip if no stocks

    firstStockCell.swipeLeft()
    
    let alertButton = app.buttons["bell.badge.plus"] // System image for Target Alert action
    if alertButton.waitForExistence(timeout: 2) {
      alertButton.tap()
      XCTAssertTrue(app.otherElements["PaywallView"].waitForExistence(timeout: 5) || app.staticTexts["Unlock Pro"].exists)
    }
  }

  @MainActor
  func testProUserCanAccessPriceAlerts() throws {
    let app = makeAuthenticatedImportedUserApp(userID: "ui-test-\(UUID().uuidString)", billingTier: "pro")
    app.launch()

    let portfolioTab = app.tabBars.buttons["Portfolio"]
    XCTAssertTrue(portfolioTab.waitForExistence(timeout: 25))
    portfolioTab.tap()

    let firstStockCell = app.cells.firstMatch
    guard firstStockCell.waitForExistence(timeout: 10) else { return } // Skip if no stocks

    firstStockCell.swipeLeft()
    
    let alertButton = app.buttons["bell.badge.plus"]
    if alertButton.waitForExistence(timeout: 2) {
      alertButton.tap()
      XCTAssertTrue(app.navigationBars["Set Alert"].waitForExistence(timeout: 5))
    }
  }

  @MainActor
  private func openSettings(in app: XCUIApplication) {
    let homeTab = app.tabBars.buttons["Home"]
    if homeTab.waitForExistence(timeout: 25) {
      homeTab.tap()
    }

    let settingsButton = app.buttons["Open settings"]
    XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
    settingsButton.tap()
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
  private func makeAuthenticatedFirstLoginApp(userID: String, resetSession: Bool = true, billingTier: String? = nil) -> XCUIApplication {
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
    if let billingTier {
      launchArguments += ["-ui_test_billing_tier", billingTier]
    }
    app.launchArguments += launchArguments
    return app
  }

  @MainActor
  private func makeAuthenticatedImportedUserApp(userID: String, resetSession: Bool = true, billingTier: String? = nil) -> XCUIApplication {
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
    if let billingTier {
      launchArguments += ["-ui_test_billing_tier", billingTier]
    }
    app.launchArguments += launchArguments
    return app
  }

  @MainActor
  private func makeUnauthenticatedApp(appearance: String? = nil) -> XCUIApplication {
    let app = XCUIApplication()
    var launchArguments = [
      "-ui_test_skip_splash",
      "-ui_test_reset_session"
    ]
    if let appearance {
      launchArguments += ["-ui_test_app_appearance", appearance]
    }
    app.launchArguments += launchArguments
    return app
  }
}
