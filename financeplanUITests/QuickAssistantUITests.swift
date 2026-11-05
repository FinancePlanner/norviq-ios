import XCTest

/// The Quick Q card in the real app, with a fake session.
///
/// It runs against the `local` environment with nothing expected to be listening
/// there. A refused connection leaves the session alone, where a real server
/// would answer the fake token with a 401 and sign the app out. A backend running
/// on localhost:8080 will therefore fail these tests.
final class QuickAssistantUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(billingTier: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NORVIQ_ENVIRONMENT"] = "local"
        app.launchAuthenticatedWithExpenses(userID: "quick-q-ui-test", billingTier: billingTier)
        return app
    }

    @MainActor
    private func aiButton(_ app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["aiSummary.open.home"]
        XCTAssertTrue(button.waitForExistence(timeout: 20), "AI button missing from the dashboard")
        // A fresh install asks about notifications over the dashboard.
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 5) {
            notNow.tap()
            XCTAssertTrue(notNow.waitForNonExistence(timeout: 3), "Notifications prompt stayed up")
        }
        return button
    }

    @MainActor
    private func card(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts["Ask Q"]
    }

    /// A vertical `TextField` is reported as a text view.
    @MainActor
    private func composer(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["quickAssistant.composer"].firstMatch
    }

    /// Only the summary sheet has this button.
    @MainActor
    private func summary(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["Regenerate"]
    }

    @MainActor
    func testHoldingTheButtonOpensTheCardAndNotTheSummary() {
        let app = launch(billingTier: "pro")
        aiButton(app).press(forDuration: 1.0)
        XCTAssertTrue(card(app).waitForExistence(timeout: 3), "Card did not open")
        XCTAssertFalse(summary(app).waitForExistence(timeout: 2), "Summary opened too")
    }

    @MainActor
    func testProTapOpensTheSummaryAndNotTheCard() {
        let app = launch(billingTier: "pro")
        aiButton(app).tap()
        XCTAssertTrue(summary(app).waitForExistence(timeout: 5), "Summary did not open")
        XCTAssertFalse(card(app).exists, "Card opened on a plain tap")
    }

    @MainActor
    func testFreeTapOpensTheCard() {
        let app = launch(billingTier: "free")
        aiButton(app).tap()
        XCTAssertTrue(card(app).waitForExistence(timeout: 3), "Card did not open for a free account")
    }

    @MainActor
    func testComposerStaysAboveTheKeyboard() throws {
        let app = launch(billingTier: "free")
        aiButton(app).tap()
        let composer = composer(app)
        XCTAssertTrue(composer.waitForExistence(timeout: 3), "Composer missing")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "Opening must not raise the keyboard")
        composer.tap()
        let keyboard = app.keyboards.firstMatch
        guard keyboard.waitForExistence(timeout: 5) else {
            throw XCTSkip("Simulator is not showing the software keyboard")
        }
        composer.typeText("How much did I spend?")
        XCTAssertLessThanOrEqual(composer.frame.maxY, keyboard.frame.minY, "Keyboard covers the composer")
    }

    /// Stops short of tapping the mic: on a simulator `AVAudioEngine.inputNode`
    /// can abort the app when the audio server times out, so capture is a device
    /// check. A simulator without on-device speech has no mic, like such a phone.
    @MainActor
    func testMicIsIdleOnOpeningAndGivesWayToADraft() throws {
        let app = launch(billingTier: "free")
        aiButton(app).tap()
        let composer = composer(app)
        XCTAssertTrue(composer.waitForExistence(timeout: 3), "Composer missing")
        let mic = app.buttons["Ask by voice"]
        guard mic.waitForExistence(timeout: 2) else {
            XCTAssertTrue(app.buttons["Send"].exists, "No mic and no send button")
            throw XCTSkip("No on-device speech recognition on this simulator")
        }
        XCTAssertFalse(app.keyboards.firstMatch.exists, "Opening must not raise the keyboard")
        XCTAssertFalse(app.buttons["Stop listening"].exists, "Opening must not start the mic")

        composer.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Keyboard missing")
        composer.typeText("Typed")
        XCTAssertTrue(app.buttons["Send"].waitForExistence(timeout: 2), "Send missing with a draft")
        XCTAssertFalse(mic.exists, "Mic could overwrite a typed draft")
    }

    /// With nothing listening, a send fails like a dropped network. The question
    /// must come back to the composer rather than being lost.
    @MainActor
    func testFailedSendPutsTheQuestionBackInTheComposer() {
        let app = launch(billingTier: "free")
        aiButton(app).tap()
        let composer = composer(app)
        XCTAssertTrue(composer.waitForExistence(timeout: 3), "Composer missing")
        composer.tap()
        guard app.keyboards.firstMatch.waitForExistence(timeout: 5) else {
            XCTFail("Simulator is not showing the software keyboard")
            return
        }
        composer.typeText("How much did I spend?")
        let send = app.buttons["Send"]
        XCTAssertTrue(send.isEnabled, "Send stayed disabled with text in the composer")
        send.tap()

        let restored = NSPredicate(format: "value == %@", "How much did I spend?")
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: restored, object: composer)], timeout: 30),
            .completed,
            "Question did not return to the composer"
        )
        XCTAssertTrue(card(app).exists, "Card closed on a failed send")
        XCTAssertTrue(send.isEnabled, "Send did not recover after the failure")
    }

    @MainActor
    func testCloseButtonAndOutsideTapDismiss() {
        let app = launch(billingTier: "free")
        let button = aiButton(app)
        button.tap()
        XCTAssertTrue(card(app).waitForExistence(timeout: 3))
        app.buttons["Close Q"].tap()
        XCTAssertTrue(card(app).waitForNonExistence(timeout: 3), "Close button did not dismiss")

        button.tap()
        XCTAssertTrue(card(app).waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        XCTAssertTrue(card(app).waitForNonExistence(timeout: 3), "Tapping outside did not dismiss")
    }
}
