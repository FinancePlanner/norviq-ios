import XCTest

final class ExpensesSmokeTests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  // MARK: - Helpers

  private func launchApp(userID: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchAuthenticatedWithExpenses(userID: userID)
    return app
  }

  private func ensureMonthlyBudgetSet(in app: XCUIApplication) {
    app.tapExpensesTab()

    let editButton = app.buttons["expenses.editSalaryButton"]
    guard editButton.waitForExistence(timeout: 10) else {
      XCTFail("Expected salary card edit button")
      return
    }
    editButton.tap()

    let amountField = app.textFields["expenses.salaryAmountField"]
    XCTAssertTrue(amountField.waitForExistence(timeout: 10), "Salary editor did not appear")
    amountField.tap()
    amountField.typeText("5000")

    let saveButton = app.buttons["expenses.salarySaveButton"]
    XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
    saveButton.tap()

    // Wait for sheet to dismiss and salary to reflect
    XCTAssertTrue(
      editButton.waitForExistence(timeout: 10),
      "Expected to return to expenses screen"
    )
  }

  private func addPlannedItem(in app: XCUIApplication, title: String, amount: String) {
    let addButton = app.buttons["expenses.addFirstPlanItemButton"]
    let altAddButton = app.buttons["expenses.addPlanItemButton"]

    if addButton.waitForExistence(timeout: 5) {
      addButton.tap()
    } else if altAddButton.waitForExistence(timeout: 5) {
      altAddButton.tap()
    } else {
      XCTFail("No add plan item button found")
      return
    }

    let titleField = app.textFields["expenses.planItemTitleField"]
    XCTAssertTrue(titleField.waitForExistence(timeout: 10), "Plan item editor did not appear")
    titleField.tap()
    titleField.typeText(title)

    let amountField = app.textFields["expenses.planItemAmountField"]
    amountField.tap()
    amountField.typeText(amount)

    app.dismissKeyboardIfPresent()

    let saveButton = app.buttons["expenses.planItemSaveButton"]
    XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
    saveButton.tap()

    // Verify item appears
    let itemLabel = app.staticTexts[title]
    XCTAssertTrue(itemLabel.waitForExistence(timeout: 10), "Added plan item should appear")
  }

  private func recordExpense(in app: XCUIApplication, title: String, amount: String) {
    let recordButton = app.buttons["expenses.recordSpendButton"]
    XCTAssertTrue(recordButton.waitForExistence(timeout: 10), "Record spend button missing")
    recordButton.tap()

    let titleField = app.textFields["expenses.expenseTitleField"]
    XCTAssertTrue(titleField.waitForExistence(timeout: 10), "Record expense sheet did not appear")
    titleField.tap()
    titleField.typeText(title)

    let amountField = app.textFields["expenses.expenseAmountField"]
    amountField.tap()
    amountField.typeText(amount)

    app.dismissKeyboardIfPresent()

    let saveButton = app.buttons["expenses.expenseSaveButton"]
    XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
    saveButton.tap()

    // Wait for sheet dismissal by checking button no longer exists or record button reappears
    XCTAssertTrue(recordButton.waitForExistence(timeout: 10), "Should return to expenses screen")
  }

  // MARK: - Tests

  @MainActor
  func testCreateMonthlyPlan() throws {
    let app = launchApp(userID: "ui-test-expenses-plan-\(UUID().uuidString)")
    ensureMonthlyBudgetSet(in: app)

    // Verify we're on expenses screen with budget set
    XCTAssertTrue(app.buttons["expenses.recordSpendButton"].waitForExistence(timeout: 10))
  }

  @MainActor
  func testAddPlannedItem() throws {
    let app = launchApp(userID: "ui-test-expenses-item-\(UUID().uuidString)")
    ensureMonthlyBudgetSet(in: app)
    addPlannedItem(in: app, title: "Groceries", amount: "300")
  }

  @MainActor
  func testRecordExpense() throws {
    let app = launchApp(userID: "ui-test-expenses-record-\(UUID().uuidString)")
    ensureMonthlyBudgetSet(in: app)
    recordExpense(in: app, title: "Coffee", amount: "45.50")
  }

  @MainActor
  func testReportsTabShowsData() throws {
    let app = launchApp(userID: "ui-test-expenses-reports-\(UUID().uuidString)")
    ensureMonthlyBudgetSet(in: app)
    addPlannedItem(in: app, title: "Rent", amount: "1200")
    recordExpense(in: app, title: "Dinner", amount: "60")

    app.tapReportsTab()

    let scrollContent = app.otherElements["reports.scrollContent"]
    XCTAssertTrue(scrollContent.waitForExistence(timeout: 15), "Reports content should load")

    // Switch to Spending tab to verify chart
    let spendingSegment = app.segmentedControls.buttons["Spending"]
    if spendingSegment.waitForExistence(timeout: 5) {
      spendingSegment.tap()
    }

    let chart = app.otherElements["reports.spendingChart"]
    XCTAssertTrue(chart.waitForExistence(timeout: 10), "Spending chart should appear")
  }
}
