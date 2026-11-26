import XCTest

/// Film-only UI test for marketing video 01 (marketing/videos/01-leftover-units, shot A2).
///
/// Records a real Quick Add of "Dinner out" 34.00 (Fun, linked to the "Dinner out" plan
/// item) on whatever account is already signed in on the simulator: the DEMO account.
/// It is paced for a viewer, not for CI, and it writes real data, so it only runs when
/// asked to:
///
///     TEST_RUNNER_FILM=1 xcodebuild test -scheme financeplan \
///       -destination 'platform=iOS Simulator,name=iPhone 17' \
///       -only-testing:financeplanUITests/FilmQuickAddTests
///
/// Start `xcrun simctl io <sim> recordVideo` before running it.
@MainActor
final class FilmQuickAddTests: XCTestCase {
  override func setUpWithError() throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["FILM"] == "1", "Film-only test; set TEST_RUNNER_FILM=1")
    continueAfterFailure = false
  }

  /// A beat the viewer can follow. Scripted taps are otherwise too fast to read.
  private func beat(_ seconds: TimeInterval = 0.9) { Thread.sleep(forTimeInterval: seconds) }

  func testFilmQuickAddDinnerOut() throws {
    let app = XCUIApplication()
    // Keep the existing session (no -ui_test_reset_session). US locale so amounts read in dollars,
    // matching the web capture and the USD budget.
    app.launchArguments += [
      "-ui_test_skip_splash",
      "-ui_test_app_appearance", "dark",
      "-AppleLanguages", "(en)",
      "-AppleLocale", "en_US",
    ]
    app.launch()

    app.tapTab(.money)
    let record = app.buttons["expenses.recordSpendButton"]
    XCTAssertTrue(record.waitForExistence(timeout: 20), "Not on Money, or not signed in")
    beat(1.6) // establishing shot of the budget

    record.tap()
    let title = app.textFields["expenses.expenseTitleField"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    beat(0.6)
    title.tap()
    title.typeText("Dinner out")
    beat(0.5)

    let amount = app.textFields["Amount"]
    XCTAssertTrue(amount.waitForExistence(timeout: 5))
    amount.tap()
    amount.typeText("34")
    beat(0.5)
    // The number pad has no Done key: tap the section header to end editing.
    if app.keyboards.firstMatch.exists { app.staticTexts["CATEGORY"].tap() }
    beat(0.6)

    // FILM_DUMP=1: print the form's element tree and leave without saving (no data written).
    if ProcessInfo.processInfo.environment["FILM_DUMP"] == "1" {
      print("FILM_DUMP_BEGIN\n\(app.debugDescription)\nFILM_DUMP_END")
      return
    }

    // Pillar: Fun (the link picker lists only items in the selected pillar).
    let pillar = app.buttons["Pillar"]
    XCTAssertTrue(pillar.waitForExistence(timeout: 5), "Pillar menu not found")
    pillar.tap()
    let fun = app.buttons["Fun"].firstMatch
    XCTAssertTrue(fun.waitForExistence(timeout: 3), "Pillar menu did not open")
    beat(0.5)
    fun.tap()
    XCTAssertEqual(pillar.value as? String, "Fun", "Pillar is not Fun after selecting it")
    beat(0.6)

    // Link to plan: Dinner out.
    let linkMenu = app.buttons["Link, None"]
    XCTAssertTrue(linkMenu.waitForExistence(timeout: 5), "Link picker not found")
    linkMenu.tap()
    let dinner = app.buttons["Dinner out"].firstMatch
    XCTAssertTrue(dinner.waitForExistence(timeout: 5), "Plan item 'Dinner out' missing from Link menu")
    beat(0.4)
    dinner.tap()
    XCTAssertTrue(app.buttons["Link, Dinner out"].waitForExistence(timeout: 3), "Link not set to Dinner out")
    beat(0.6)

    let save = app.buttons["expenses.expenseSaveButton"]
    XCTAssertTrue(save.waitForExistence(timeout: 5))
    beat(0.4)
    save.tap()

    XCTAssertTrue(record.waitForExistence(timeout: 15), "Sheet did not dismiss after Save")
    beat(2.5) // hold on the updated budget
  }
}

