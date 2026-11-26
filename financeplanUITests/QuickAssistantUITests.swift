import Network
import XCTest

/// Q, the one entry point on every tab, and the Quick Q card, in the real app
/// with a fake session.
///
/// It runs against the `local` environment, localhost:8080. A refused connection
/// or a 404 there leaves the session alone; a real backend would answer the fake
/// token with a 401 and sign the app out, which fails these tests. The
/// Rebalancing test puts its own stub on that port.
///
/// On iOS 26 and later Q is the tab bar's bottom accessory; below 26 it is a
/// floating button in each tab. Both carry the id `q.entry`. Its label changes
/// with the plan ("AI summary" when a tap summarises, "Ask Q" otherwise), and the
/// accessory shows "Ask Q" as text, so neither the label nor that text identifies
/// anything here: the card is found by its composer.
final class QuickAssistantUITests: XCTestCase {
    private var stubAPI: StubAPIServer?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        stubAPI?.stop()
        stubAPI = nil
    }

    @MainActor
    private func launch(billingTier: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NORVIQ_ENVIRONMENT"] = "local"
        app.launchAuthenticatedWithExpenses(userID: "quick-q-ui-test", billingTier: billingTier)
        return app
    }

    /// Q, once the app has settled on Home.
    @MainActor
    private func qEntry(_ app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["q.entry"]
        XCTAssertTrue(button.waitForExistence(timeout: 20), "Q missing from Home")
        // A fresh install asks about notifications over the dashboard.
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 5) {
            notNow.tap()
            XCTAssertTrue(notNow.waitForNonExistence(timeout: 3), "Notifications prompt stayed up")
        }
        return button
    }

    /// The card. Its composer is the one thing only the card has.
    @MainActor
    private func card(_ app: XCUIApplication) -> XCUIElement {
        composer(app)
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

    // MARK: - Tap and hold

    @MainActor
    func testHoldingQOpensTheCardAndNotTheSummary() {
        let app = launch(billingTier: "pro")
        qEntry(app).press(forDuration: 1.0)
        XCTAssertTrue(card(app).waitForExistence(timeout: 3), "Card did not open")
        XCTAssertFalse(summary(app).waitForExistence(timeout: 2), "Summary opened too")
    }

    @MainActor
    func testProTapOpensTheSummaryAndNotTheCard() {
        let app = launch(billingTier: "pro")
        qEntry(app).tap()
        XCTAssertTrue(summary(app).waitForExistence(timeout: 5), "Summary did not open")
        XCTAssertFalse(card(app).exists, "Card opened on a plain tap")
    }

    @MainActor
    func testFreeTapOpensTheCard() {
        let app = launch(billingTier: "free")
        qEntry(app).tap()
        XCTAssertTrue(card(app).waitForExistence(timeout: 3), "Card did not open for a free account")
        XCTAssertFalse(summary(app).exists, "Summary opened for a free account")
    }

    // MARK: - Placement

    @MainActor
    func testQEntryStaysClearOfTheTabBarOnEveryTab() {
        let app = launch(billingTier: "free")
        _ = qEntry(app)
        let tabBar = app.tabBars.firstMatch
        // The third slot is Groups with groups on, Friends otherwise, and is
        // left out while the server has not turned social on, as with no
        // server. The More tabs that then move into the bar are not tapped.
        let third = ["Groups", "Friends"].filter { tabBar.buttons[$0].exists }
        let button = app.buttons["q.entry"]
        for tab in ["Portfolio"] + third + ["Expenses", "Home"] {
            tabBar.buttons[tab].tap()
            XCTAssertTrue(button.waitForExistence(timeout: 3), "Q missing on \(tab)")
            XCTAssertLessThanOrEqual(button.frame.maxY, tabBar.frame.minY, "Q overlaps the tab bar on \(tab)")
            if #unavailable(iOS 26) {
                XCTAssertGreaterThan(button.frame.maxY, tabBar.frame.minY - 40, "Q drifted up from the tab bar on \(tab)")
                XCTAssertGreaterThan(button.frame.maxX, app.frame.maxX - 40, "Q left the trailing edge on \(tab)")
            }
        }
    }

    /// The floating button below iOS 26. The accessory is part of the tab bar
    /// and stays while the card is up.
    @MainActor
    func testQEntryGivesWayToTheCard() throws {
        if #available(iOS 26, *) {
            throw XCTSkip("The iOS 26 accessory stays while the card is up; only the floating button gives way")
        }
        let app = launch(billingTier: "free")
        let button = qEntry(app)
        button.tap()
        XCTAssertTrue(card(app).waitForExistence(timeout: 3), "Card did not open")
        XCTAssertTrue(button.waitForNonExistence(timeout: 3), "Q stayed up behind the card")
        app.buttons["Close Q"].tap()
        XCTAssertTrue(button.waitForExistence(timeout: 3), "Q did not come back")
    }

    @MainActor
    func testKeyboardCoversQRatherThanLiftingIt() {
        let app = launch(billingTier: "free")
        let button = qEntry(app)
        let resting = button.frame
        app.searchFields.firstMatch.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Keyboard missing")
        XCTAssertEqual(button.frame.minY, resting.minY, accuracy: 1, "Q moved with the keyboard")
    }

    // MARK: - Hidden on screens with a bottom action

    /// Rebalancing is reached through a portfolio, which only a server can
    /// supply, so a stub stands in for the API.
    @MainActor
    func testQEntryHiddenOnRebalancing() throws {
        let stub = try StubAPIServer(routes: ["/v1/portfolios": StubAPIServer.onePortfolio])
        stubAPI = stub
        try stub.start()

        let app = launch(billingTier: "free")
        let button = qEntry(app)

        app.tabBars.firstMatch.buttons["Portfolio"].tap()
        app.buttons["Manage portfolios"].firstMatch.tap()
        let portfolio = app.staticTexts[StubAPIServer.portfolioName].firstMatch
        XCTAssertTrue(portfolio.waitForExistence(timeout: 10), "The stub's portfolio is not listed")
        XCTAssertTrue(button.exists, "Q missing before Rebalancing")
        portfolio.tap()

        let rebalancing = app.buttons["Targets & rebalancing"].firstMatch
        XCTAssertTrue(rebalancing.waitForExistence(timeout: 5), "No way into Rebalancing")
        rebalancing.tap()
        XCTAssertTrue(app.buttons["Edit targets"].waitForExistence(timeout: 5), "Rebalancing did not open")
        XCTAssertTrue(button.waitForNonExistence(timeout: 5), "Q still shown on Rebalancing")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(rebalancing.waitForExistence(timeout: 5), "Did not return from Rebalancing")
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Q did not come back after leaving Rebalancing")
    }

    // MARK: - The card

    @MainActor
    func testComposerStaysAboveTheKeyboard() throws {
        let app = launch(billingTier: "free")
        qEntry(app).tap()
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
        qEntry(app).tap()
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

    /// With nothing to answer it, a send fails like a dropped network. The
    /// question must come back to the composer rather than being lost.
    @MainActor
    func testFailedSendPutsTheQuestionBackInTheComposer() {
        let app = launch(billingTier: "free")
        qEntry(app).tap()
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
        let button = qEntry(app)
        button.tap()
        XCTAssertTrue(card(app).waitForExistence(timeout: 3))
        app.buttons["Close Q"].tap()
        XCTAssertTrue(card(app).waitForNonExistence(timeout: 3), "Close button did not dismiss")

        // Closing the card re-arms the tap, so this one is not swallowed.
        button.tap()
        XCTAssertTrue(card(app).waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        XCTAssertTrue(card(app).waitForNonExistence(timeout: 3), "Tapping outside did not dismiss")
    }
}

/// The stub API could not start, for a reason other than the port being taken.
enum StubAPIError: Error {
    case notReady(String)
}

/// A stand-in for the API at `AppEnvironments.local`, in the test runner.
///
/// It serves fixed JSON for the routes it is given and answers anything else
/// the way an API without that route does, with a 404 that leaves the session
/// alone. The simulator shares the Mac's network, so the port must be free
/// there: a backend already on it makes the test that needs this skip. Only one
/// stub can hold the port, so these tests run serially.
final class StubAPIServer: @unchecked Sendable {
    /// `AppEnvironments.local`'s port.
    static let port: NWEndpoint.Port = 8080

    static let portfolioName = "Q Test Portfolio"

    /// `GET /v1/portfolios` with one portfolio the user owns, in the API's
    /// snake_case.
    static let onePortfolio = Data(
        """
        {"items":[{"id":"q-ui-test-portfolio","owner_user_id":"quick-q-ui-test","name":"\(portfolioName)",\
        "purpose":"personal","ownership":"individual","mode":"actual","base_currency":"EUR","is_default":true,\
        "current_user_role":"owner","capabilities":{"can_view":true,"can_edit":true,"can_manage_members":false,\
        "can_manage_connections":false,"can_archive":false,"can_delete":false},"created_at":"2026-01-01T00:00:00Z"}],\
        "next_cursor":null}
        """.utf8
    )

    private static let notFound = Data(#"{"error":true,"code":"not_found","reason":"Not Found"}"#.utf8)

    private let listener: NWListener
    private let routes: [String: Data]
    private let queue = DispatchQueue(label: "quick-q-ui-test.stub-api")

    /// Throws `XCTSkip` when the port is taken, and the error itself for any
    /// other failure.
    init(routes: [String: Data]) throws {
        self.routes = routes
        do {
            listener = try NWListener(using: .tcp, on: Self.port)
        } catch let error as NWError {
            throw Self.skipIfPortTaken(error, state: "init")
        }
    }

    /// Returns once listening. Throws `XCTSkip` when the port is taken, and
    /// fails on any other error or when the listener never becomes ready.
    func start() throws {
        let settled = DispatchSemaphore(value: 0)
        let outcome = Outcome()
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                outcome.state = "ready"
            case let .failed(error):
                (outcome.state, outcome.error) = ("failed", error)
            case let .waiting(error):
                (outcome.state, outcome.error) = ("waiting", error)
            default:
                return
            }
            settled.signal()
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.serve(connection)
        }
        listener.start(queue: queue)
        guard settled.wait(timeout: .now() + 5) == .success else {
            listener.cancel()
            throw StubAPIError.notReady("timed out after 5 s")
        }
        if let error = outcome.error {
            listener.cancel()
            throw Self.skipIfPortTaken(error, state: outcome.state)
        }
    }

    /// `XCTSkip` for a port already in use, which is another server on the
    /// Mac; anything else is a real failure.
    private static func skipIfPortTaken(_ error: NWError, state: String) -> Error {
        if case .posix(.EADDRINUSE) = error {
            return XCTSkip("localhost:\(port) is in use by another server (EADDRINUSE, listener \(state)), so the stub API cannot run")
        }
        return StubAPIError.notReady("listener \(state): \(error)")
    }

    func stop() {
        listener.stateUpdateHandler = nil
        listener.cancel()
    }

    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveHead(on: connection, buffer: Data())
    }

    /// Reads up to the end of the headers. A body, if any, is never needed.
    private func receiveHead(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return connection.cancel() }
            var buffer = buffer
            if let data { buffer.append(data) }
            if buffer.range(of: Data("\r\n\r\n".utf8)) != nil {
                respond(on: connection, to: buffer)
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                receiveHead(on: connection, buffer: buffer)
            }
        }
    }

    private func respond(on connection: NWConnection, to request: Data) {
        let requestLine = (String(bytes: request, encoding: .utf8) ?? "").split(separator: "\r\n").first ?? ""
        let target = requestLine.split(separator: " ").dropFirst().first ?? ""
        let path = String(target.split(separator: "?").first ?? "")
        let body = routes[path]
        let status = body == nil ? "404 Not Found" : "200 OK"
        let payload = body ?? Self.notFound
        var response = Data(
            "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n".utf8
        )
        response.append(payload)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }

    /// Set on the listener's queue, read after the semaphore.
    private final class Outcome: @unchecked Sendable {
        var state = ""
        var error: NWError?
    }
}
