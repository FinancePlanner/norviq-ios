import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

/// The trades card's rules are the web card's (`norviq-web-v2`
/// `features/dashboard/assistant/trades.ts` and `TradesCard.svelte`), and its
/// wire is the backend's `record_trades` confirm (`assistant/trades.go`).

private let storedListID = "8F1C2B9A-0D4E-4C1B-9E7A-3B5D6C7E8F90"
private let otherListID = "1A2B3C4D-5E6F-4A1B-8C9D-0E1F2A3B4C5D"

/// `TestProposalArgumentsShape` in the backend, byte for byte.
private let backendShape = #"{"portfolio_list_id":"8F1C2B9A-0D4E-4C1B-9E7A-3B5D6C7E8F90","skipped_rows":0,"base_currency":"USD","synced":false,"trades":[{"symbol":"AAPL","side":"buy","quantity":1,"price":100.5,"trade_date":"2024-03-10","issues":[]}]}"#

/// Three rows: a plain buy, a sell with every optional field, and a buy that is
/// already recorded, whose optional fields are explicit nulls.
private func storedArguments(synced: Bool = false, skipped: Int = 2) -> String {
    #"{"portfolio_list_id":"\#(storedListID)","skipped_rows":\#(skipped),"base_currency":"USD","synced":\#(synced),"trades":["#
        + #"{"symbol":"AAPL","side":"buy","quantity":1,"price":100.5,"trade_date":"2024-03-10","issues":[]},"#
        + #"{"symbol":"ASML","side":"sell","quantity":2,"price":610.25,"trade_date":"2024-03-11","currency":"EUR","fees":1.25,"confidence":0.95,"#
        + #""issues":[{"code":"currency_mismatch","message":"ASML is in EUR but this portfolio's account is in USD.","blocking":false}]},"#
        + #"{"symbol":"TSLA","side":"buy","quantity":3,"price":200,"trade_date":"2024-03-12","currency":null,"fees":null,"confidence":null,"#
        + #""issues":[{"code":"already_recorded","message":"TSLA: this trade is already recorded.","blocking":true}]}"#
        + "]}"
}

private func tradesAction(id: String = "a1", arguments: String = storedArguments(), summary: String = "Record 2 buys and 1 sell in Growth.") -> AIPendingActionResponse {
    AIPendingActionResponse(
        id: id,
        conversationId: "c1",
        toolName: "record_trades",
        summary: summary,
        arguments: arguments,
        status: .pending,
        expiresAt: "2026-11-05T12:15:00Z",
        createdAt: "2026-11-05T12:00:00Z"
    )
}

@MainActor
private func review(_ arguments: String = storedArguments(), summary: String = "Record 2 buys and 1 sell in Growth.") throws -> AssistantTradesReview {
    try XCTUnwrap(AssistantTradesReview(action: tradesAction(arguments: arguments, summary: summary)))
}

// MARK: - Stub service

private final class TradesService: PersistentAssistantServicing, @unchecked Sendable {
    struct Unused: Error {}
    struct Offline: Error {}

    /// Answers to successive `pendingActions()` calls; the last one repeats.
    var actionLists: [Result<[AIPendingActionResponse], Error>] = []
    var listsResult: Result<[PortfolioListDTOResponse], Error> = .success([])
    var confirmResult: Result<AIConfirmedActionResponse, Error> = .success(
        AIConfirmedActionResponse(actionId: "a1", status: .completed, resultId: nil, message: "Trades recorded.")
    )
    private(set) var pendingActionsCalls = 0
    private(set) var listsCalls = 0
    private(set) var confirmed: [(id: String, portfolioListID: String, trades: [AIReviewedTrade])] = []

    func pendingActions() async throws -> [AIPendingActionResponse] {
        defer { pendingActionsCalls += 1 }
        guard !actionLists.isEmpty else { return [] }
        return try actionLists[min(pendingActionsCalls, actionLists.count - 1)].get()
    }

    func portfolioLists() async throws -> [PortfolioListDTOResponse] {
        listsCalls += 1
        return try listsResult.get()
    }

    func confirmTrades(id: String, portfolioListID: String, trades: [AIReviewedTrade]) async throws -> AIConfirmedActionResponse {
        confirmed.append((id, portfolioListID, trades))
        return try confirmResult.get()
    }

    func preferences() async throws -> AIAssistantPreferencesResponse {
        AIAssistantPreferencesResponse(proactiveTipsEnabled: false, pushEnabled: false, timezone: "UTC", imagesEnabled: true)
    }
    func usage() async throws -> AIAssistantUsageResponse {
        AIAssistantUsageResponse(month: "2026-11", used: 1, limit: nil, remaining: nil, isPro: true)
    }
    func createConversation(title: String?, bindMessaging _: Bool?) async throws -> AIConversationResponse {
        AIConversationResponse(id: "c1", title: title ?? "", messages: [], createdAt: "2026-11-05T00:00:00Z", updatedAt: "2026-11-05T00:00:00Z")
    }
    func conversations() async throws -> [AIConversationSummaryResponse] { [] }
    func tips() async throws -> [AITipResponse] { [] }

    func streamTurn(conversationID _: String, content _: String, images _: [ScreenshotUploadImage], context _: AssistantTurnContext?) -> AsyncThrowingStream<PersistentAssistantStreamEvent, Error> {
        AsyncThrowingStream { $0.finish(throwing: Unused()) }
    }
    func conversation(id _: String) async throws -> AIConversationResponse { throw Unused() }
    func deleteConversation(id _: String) async throws { throw Unused() }
    func turn(conversationID _: String, content _: String) async throws -> AIAssistantTurnResponse { throw Unused() }
    func updatePreferences(_: AIAssistantPreferencesResponse) async throws -> AIAssistantPreferencesResponse { throw Unused() }
    func dismissTip(id _: String) async throws { throw Unused() }
    func confirmAction(id _: String) async throws -> AIConfirmedActionResponse { throw Unused() }
    func cancelAction(id _: String) async throws { throw Unused() }
    func memos(bookmarked _: Bool?, conversationID _: String?) async throws -> [PositionMemoListItem] { [] }
    func memo(id _: String) async throws -> PositionMemoDetail { throw Unused() }
    func bookmarkMemo(id _: String, bookmarked _: Bool) async throws -> PositionMemoCard { throw Unused() }
    func deleteMemo(id _: String) async throws { throw Unused() }
}

/// Answers one request with a canned status and body, and keeps the request.
private final class StubSession: HTTPClientSession, @unchecked Sendable {
    let status: Int
    let body: Data
    private(set) var request: URLRequest?

    init(status: Int, body: String) {
        self.status = status
        self.body = Data(body.utf8)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.request = request
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        return (body, response)
    }
}

private let confirmedJSON = #"{"actionId":"a1","status":"completed","message":"Trades recorded."}"#

@MainActor
final class AssistantTradesCardTests: XCTestCase {
    private func loadedViewModel(_ service: TradesService) async -> PersistentAssistantViewModel {
        let viewModel = PersistentAssistantViewModel(service: service, sleep: { _ in })
        await viewModel.load()
        return viewModel
    }

    private func client(_ session: StubSession) -> PersistentAssistantHTTPClient {
        PersistentAssistantHTTPClient(baseURL: URL(string: "https://api.example.test")!, session: session)
    }

    private let kept = [
        AIReviewedTrade(symbol: "AAPL", side: "buy", quantity: 1, price: 100.5, tradeDate: "2024-03-10"),
    ]

    // MARK: - The plan's seven

    func testDecodesStoredArguments() throws {
        let shape = try XCTUnwrap(TradesProposalDTO.decode(arguments: backendShape))
        XCTAssertEqual(shape.portfolioListId, storedListID)
        XCTAssertEqual(shape.skippedRows, 0)
        XCTAssertEqual(shape.baseCurrency, "USD")
        XCTAssertFalse(shape.synced)
        XCTAssertEqual(shape.trades, [
            AIProposedTrade(symbol: "AAPL", side: "buy", quantity: 1, price: 100.5, tradeDate: "2024-03-10", issues: []),
        ])

        let full = try XCTUnwrap(TradesProposalDTO.decode(arguments: storedArguments()))
        XCTAssertEqual(full.skippedRows, 2)
        XCTAssertEqual(full.trades.count, 3)
        let sell = full.trades[1]
        XCTAssertEqual(sell.currency, "EUR")
        XCTAssertEqual(sell.fees, 1.25)
        XCTAssertEqual(sell.confidence, 0.95)
        XCTAssertEqual(sell.issues, [AITradeIssue(code: "currency_mismatch", message: "ASML is in EUR but this portfolio's account is in USD.", blocking: false)])
        let recorded = full.trades[2]
        XCTAssertNil(recorded.currency)
        XCTAssertNil(recorded.fees)
        XCTAssertNil(recorded.confidence)

        // The card shows the numbers as text, and an absent confidence reads as low (R15).
        let card = try review()
        XCTAssertEqual(card.rows.map(\.quantity), ["1", "2", "3"])
        XCTAssertEqual(card.rows.map(\.price), ["100.5", "610.25", "200"])
        XCTAssertEqual(card.rows.map(\.fees), ["", "1.25", ""])
        XCTAssertEqual(card.rows.map(\.isLowConfidence), [true, false, true])
    }

    func testAlreadyRecordedRowsStartUntickedAndLocked() throws {
        var card = try review()
        XCTAssertEqual(card.rows.map(\.keep), [true, true, false])
        XCTAssertEqual(card.rows.map(\.isLocked), [false, false, true])
        // Ticking it anyway changes nothing that is sent.
        card.rows[2].keep = true
        XCTAssertEqual(card.keptIndexes, [0, 1])
        XCTAssertEqual(card.confirmTrades.map(\.symbol), ["AAPL", "ASML"])
        // Only a blocking already_recorded locks a row.
        let quiet = storedArguments().replacingOccurrences(of: #""blocking":true"#, with: #""blocking":false"#)
        XCTAssertEqual(try review(quiet).rows.map(\.isLocked), [false, false, false])
    }

    func testConfirmBodyHasOnlyKeptRows() async throws {
        let service = TradesService()
        service.actionLists = [.success([tradesAction()])]
        let viewModel = await loadedViewModel(service)
        var card = try XCTUnwrap(viewModel.tradesReviews["a1"])
        card.rows[0].keep = false
        card.rows[1].price = " 610,5 "
        card.rows[1].currency = " eur "
        card.rows[1].symbol = " ASML "
        viewModel.updateTradesReview(card)

        await viewModel.confirmTrades(tradesAction())

        let sent = try XCTUnwrap(service.confirmed.first)
        XCTAssertEqual(sent.id, "a1")
        XCTAssertEqual(sent.portfolioListID, storedListID)
        XCTAssertEqual(sent.trades, [
            AIReviewedTrade(symbol: "ASML", side: "sell", quantity: 2, price: 610.5, tradeDate: "2024-03-11", currency: "EUR", fees: 1.25),
        ])
        XCTAssertNil(viewModel.tradesReviews["a1"], "a saved card is gone")
        XCTAssertFalse(viewModel.pendingActions.contains { $0.id == "a1" })
        XCTAssertEqual(viewModel.errorMessage, "Trades recorded.")
    }

    func test422MapsRowErrorsAndKeepsCard() async throws {
        // The client reads the 422 body.
        let session = StubSession(status: 422, body: #"{"reason":"1 trade could not be saved.","rowErrors":[{"index":1,"code":"exceeds_holding","message":"This sells 2 ASML but only 1 would be held."}]}"#)
        do {
            _ = try await client(session).confirmTrades(id: "a1", portfolioListID: storedListID, trades: kept)
            XCTFail("expected a refusal")
        } catch let error as PersistentAssistantHTTPClient.Error {
            XCTAssertEqual(error, .unprocessable(
                reason: "1 trade could not be saved.",
                rowErrors: [AITradeRowError(index: 1, code: "exceeds_holding", message: "This sells 2 ASML but only 1 would be held.")]
            ))
            XCTAssertEqual(error.statusCode, 422)
        }

        // The view model puts each error on the row that was sent at its index,
        // after checking the card is still pending.
        let service = TradesService()
        service.actionLists = [.success([tradesAction()])]
        service.confirmResult = .failure(PersistentAssistantHTTPClient.Error.unprocessable(
            reason: "2 trades could not be saved.",
            rowErrors: [
                AITradeRowError(index: 1, code: "exceeds_holding", message: "This sells 2 ASML but only 1 would be held."),
                AITradeRowError(index: 7, code: "invalid", message: "Out of range."),
            ]
        ))
        let viewModel = await loadedViewModel(service)
        await viewModel.confirmTrades(tradesAction())

        XCTAssertEqual(service.pendingActionsCalls, 2, "a 422 refetches the action")
        let card = try XCTUnwrap(viewModel.tradesReviews["a1"])
        XCTAssertNil(card.closedMessage)
        XCTAssertEqual(card.refusal?.message, "2 trades could not be saved.")
        XCTAssertEqual(card.refusal?.byRow, [1: ["This sells 2 ASML but only 1 would be held."]])
        XCTAssertEqual(card.refusal?.unplaced, ["Out of range."])
        XCTAssertTrue(viewModel.pendingActions.contains { $0.id == "a1" })
        XCTAssertNil(viewModel.errorMessage)
    }

    func test409ShowsExpiredMessage() async throws {
        let session = StubSession(status: 409, body: #"{"error":true,"reason":"Action is no longer available for confirmation."}"#)
        do {
            _ = try await client(session).confirmTrades(id: "a1", portfolioListID: storedListID, trades: kept)
            XCTFail("expected a conflict")
        } catch let error as PersistentAssistantHTTPClient.Error {
            XCTAssertEqual(error.statusCode, 409)
        }

        let service = TradesService()
        service.actionLists = [.success([tradesAction()])]
        service.confirmResult = .failure(PersistentAssistantHTTPClient.Error.conflict("Action is no longer available for confirmation."))
        let viewModel = await loadedViewModel(service)
        await viewModel.confirmTrades(tradesAction())

        XCTAssertEqual(viewModel.tradesReviews["a1"]?.closedMessage, "This review expired. Send the screenshot again.")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSyncedDisablesSaveUntilAnotherPortfolioChosen() throws {
        var card = try review(storedArguments(synced: true))
        XCTAssertTrue(card.blockedBySync)
        XCTAssertFalse(card.canSave)
        card.portfolioListID = otherListID
        XCTAssertFalse(card.blockedBySync)
        XCTAssertTrue(card.canSave)
        XCTAssertEqual(card.confirmBody.portfolioListId, otherListID)
        // The stored list in another case is still the stored list.
        card.portfolioListID = storedListID.lowercased()
        XCTAssertTrue(card.blockedBySync)
        XCTAssertFalse(card.canSave)
        XCTAssertEqual(AssistantTradesReview.syncedCopy, "This portfolio syncs from IBKR, so saved trades would be overwritten. Pick another portfolio.")
    }

    func testDecimalCommaParses() throws {
        XCTAssertEqual(TradeNumber.parse("1,5"), 1.5)
        XCTAssertEqual(TradeNumber.parse("182,35"), 182.35)
        XCTAssertEqual(TradeNumber.parse("0,123"), 0.123)
        XCTAssertEqual(TradeNumber.parse("1 234,56"), 1234.56)
        XCTAssertEqual(TradeNumber.parse("1.234.567,5"), 1_234_567.5)
        var card = try review()
        card.rows[0].quantity = "1,5"
        XCTAssertEqual(card.problem(at: 0), "")
        XCTAssertEqual(card.confirmTrades.first?.quantity, 1.5)
    }

    // MARK: - Numbers (R16, R18, R20, R21)

    func testAmbiguousCommaIsRefusedWithItsQuestion() throws {
        XCTAssertNil(TradeNumber.parse("1,234"))
        XCTAssertNil(TradeNumber.parse("-12,500"))
        XCTAssertNil(TradeNumber.parse("01,234"))
        var card = try review()
        card.rows[0].quantity = "1,234"
        XCTAssertEqual(card.problem(at: 0), "Is that 1234 or 1.234? Type it without the comma.")
        XCTAssertFalse(card.canSave)
    }

    func testOnlyKnownShapesParse() {
        let accepted: [(String, Double)] = [
            ("10", 10), ("1.5", 1.5), (".5", 0.5), ("1.", 1), (" 2.25 ", 2.25), ("+2", 2), ("-3", -3),
            ("1 234", 1234), ("1\u{00A0}234,5", 1234.5), ("1,234,567.5", 1_234_567.5), ("1'234.5", 1234.5),
            ("1.000", 1), ("1.234", 1.234),
        ]
        for (text, value) in accepted {
            XCTAssertEqual(TradeNumber.parse(text), value, text)
        }
        let refused = ["", "  ", "abc", "1e5", "12a", "1,2,3", "1.2.3", "1,23,456", "1.234,567.8", "\u{0661}\u{0662}", "1 2", "--1"]
        for text in refused {
            XCTAssertNil(TradeNumber.parse(text), text)
        }
    }

    func testSpaceGroupBeforeADotIsRefused() throws {
        XCTAssertNil(TradeNumber.parse("100 150.25"))
        var card = try review()
        card.rows[0].price = "100 150.25"
        XCTAssertEqual(card.problem(at: 0), "Spaces and a decimal point do not go together here. Type it without the spaces.")
    }

    func testSavesAsHintAndDotThousandsWarning() {
        XCTAssertEqual(TradeNumber.hint(for: "1,5", stored: "2"), TradeNumber.Hint(text: "Saves as 1.5", warns: false))
        XCTAssertEqual(TradeNumber.hint(for: "1 234", stored: nil), TradeNumber.Hint(text: "Saves as 1234", warns: false))
        XCTAssertEqual(TradeNumber.hint(for: "1.234", stored: "5"), TradeNumber.Hint(text: "Saves as 1.234, not 1234", warns: true))
        XCTAssertNil(TradeNumber.hint(for: "1.234", stored: "1.234"), "a stored value stays quiet")
        XCTAssertNil(TradeNumber.hint(for: "150", stored: "150"))
        XCTAssertNil(TradeNumber.hint(for: "1,234", stored: nil), "an unreadable cell gets its problem, not a hint")
        XCTAssertNil(TradeNumber.hint(for: "", stored: nil))
    }

    func testNumbersAreWrittenWithoutAnExponent() {
        XCTAssertEqual(TradeNumber.format(5e-7), "0.0000005")
        XCTAssertEqual(TradeNumber.format(100), "100")
        XCTAssertEqual(TradeNumber.format(100.5), "100.5")
        XCTAssertEqual(TradeNumber.format(1e21), "1000000000000000000000")
        XCTAssertEqual(TradeNumber.tidy("1,5"), "1.5")
        XCTAssertEqual(TradeNumber.tidy("1,234"), "1,234", "unreadable text is left for its problem")
    }

    // MARK: - Card rules

    func testRowProblems() throws {
        var card = try review()
        card.rows[0].symbol = " "
        XCTAssertEqual(card.problem(at: 0), "Enter a symbol.")
        card.rows[0].symbol = "AAPL"
        card.rows[0].quantity = "0"
        XCTAssertEqual(card.problem(at: 0), "Enter the number of shares.")
        card.rows[0].quantity = "1"
        card.rows[0].price = ""
        XCTAssertEqual(card.problem(at: 0), "Enter the price.")
        card.rows[0].price = "1"
        card.rows[0].tradeDate = "2026-02-30"
        XCTAssertEqual(card.problem(at: 0), "Enter the date.")
        card.rows[0].tradeDate = "2026-02-28"
        card.rows[0].fees = "-1"
        XCTAssertEqual(card.problem(at: 0), "Fees must be a number, or blank.")
        card.rows[0].fees = ""
        XCTAssertEqual(card.problem(at: 0), "")
        // An unticked row has no problem to fix.
        card.rows[0].quantity = "x"
        card.rows[0].keep = false
        XCTAssertEqual(card.problem(at: 0), "")
        XCTAssertTrue(card.canSave)
        card.rows[1].keep = false
        XCTAssertFalse(card.canSave, "nothing kept")
    }

    func testLowConfidenceBelowPointEight() throws {
        let edge = storedArguments().replacingOccurrences(of: #""confidence":0.95"#, with: #""confidence":0.8"#)
        XCTAssertFalse(try review(edge).rows[1].isLowConfidence)
        let low = storedArguments().replacingOccurrences(of: #""confidence":0.95"#, with: #""confidence":0.79"#)
        XCTAssertTrue(try review(low).rows[1].isLowConfidence)
    }

    func testSellTaxNoteOnlyWhileASellIsKept() throws {
        var card = try review()
        XCTAssertTrue(card.showsSellTaxNote)
        XCTAssertEqual(AssistantTradesReview.sellTaxNote, "Sells update realized P&L, not yet your annual tax figures.")
        card.rows[1].keep = false
        XCTAssertFalse(card.showsSellTaxNote)
        card.rows[0].side = "sell"
        XCTAssertTrue(card.showsSellTaxNote)
    }

    func testSkippedRowsAndSaveTitle() throws {
        XCTAssertEqual(try review(storedArguments(skipped: 2)).skippedRowsText, "2 rows left out (options, shorts, dividends or fees).")
        XCTAssertEqual(try review(storedArguments(skipped: 1)).skippedRowsText, "1 row left out (options, shorts, dividends or fees).")
        XCTAssertEqual(try review(storedArguments(skipped: 0)).skippedRowsText, "")
        var card = try review()
        XCTAssertEqual(card.saveTitle, "Save 2 trades")
        card.rows[0].keep = false
        XCTAssertEqual(card.saveTitle, "Save 1 trade")
    }

    func testPortfolioPickerAndDestination() throws {
        let card = try review()
        XCTAssertEqual(AssistantTradesReview.listName(fromSummary: "Record 1 buy in Fun in the sun."), "Fun in the sun")
        XCTAssertEqual(AssistantTradesReview.listName(fromSummary: "Something else"), "")
        // No lists loaded: one option, named from the summary.
        XCTAssertEqual(card.options(lists: nil), [.init(id: storedListID, name: "Growth")])
        XCTAssertEqual(card.destination(lists: nil), "Growth")
        // The stored list among the lists, in another case: the lists as they are.
        let lists = [
            PortfolioListDTOResponse(id: storedListID.lowercased(), name: "Growth", isDefault: false, createdAt: nil, updatedAt: nil),
            PortfolioListDTOResponse(id: otherListID, name: "Main", isDefault: true, createdAt: nil, updatedAt: nil),
        ]
        XCTAssertEqual(card.options(lists: lists).map(\.name), ["Growth", "Main"])
        // The stored list missing: it is offered first, so the destination is always visible.
        let others = [lists[1]]
        XCTAssertEqual(card.options(lists: others), [.init(id: storedListID, name: "Growth"), .init(id: otherListID, name: "Main")])
        let unnamed = try review(summary: "")
        XCTAssertEqual(unnamed.options(lists: nil).first?.name, "the proposed portfolio")
    }

    func testUnreadableArgumentsFallBackToTheOldCard() async {
        let unreadable = [
            "not json",
            #"{"portfolio_list_id":"x","trades":[]}"#,
            #"{"trades":[{"symbol":"AAPL","side":"buy","quantity":1,"price":1,"trade_date":"2024-03-10","issues":[]}]}"#,
            storedArguments().replacingOccurrences(of: #""side":"buy""#, with: #""side":"short""#),
            storedArguments().replacingOccurrences(of: #""quantity":1,"#, with: ""),
        ]
        for arguments in unreadable {
            XCTAssertNil(TradesProposalDTO.decode(arguments: arguments), arguments)
        }
        let service = TradesService()
        service.actionLists = [.success([tradesAction(arguments: "not json")])]
        let viewModel = await loadedViewModel(service)
        XCTAssertNil(viewModel.tradesReviews["a1"])
        XCTAssertEqual(service.listsCalls, 0, "no card, no lists")
    }

    // MARK: - Confirm outcomes

    func test422AfterTheClaimClosesTheCard() async throws {
        let service = TradesService()
        service.actionLists = [.success([tradesAction()]), .success([])]
        service.confirmResult = .failure(PersistentAssistantHTTPClient.Error.unprocessable(reason: "The action could not be applied.", rowErrors: []))
        let viewModel = await loadedViewModel(service)
        await viewModel.confirmTrades(tradesAction())
        XCTAssertEqual(
            viewModel.tradesReviews["a1"]?.closedMessage,
            "The action could not be applied. Those trades were not saved and this review is closed. Send the screenshot again."
        )
    }

    func test422WhenTheRefetchFailsKeepsTheCard() async throws {
        let service = TradesService()
        service.actionLists = [.success([tradesAction()]), .failure(TradesService.Offline())]
        service.confirmResult = .failure(PersistentAssistantHTTPClient.Error.unprocessable(reason: nil, rowErrors: []))
        let viewModel = await loadedViewModel(service)
        await viewModel.confirmTrades(tradesAction())
        let card = try XCTUnwrap(viewModel.tradesReviews["a1"])
        XCTAssertNil(card.closedMessage)
        XCTAssertEqual(card.refusal?.message, "That did not go through. Try again.")
    }

    func test403UpgradeSaysItIsPro() async throws {
        let session = StubSession(status: 403, body: #"{"success":false,"code":"upgrade_required","error":"Upgrade to Pro.","feature":"screenshot_import","plan":"free","requiredPlan":"pro"}"#)
        do {
            _ = try await client(session).confirmTrades(id: "a1", portfolioListID: storedListID, trades: kept)
            XCTFail("expected a refusal")
        } catch let error as PersistentAssistantHTTPClient.Error {
            XCTAssertEqual(error, .upgradeRequired("Upgrade to Pro."))
            XCTAssertEqual(error.statusCode, 403)
        }

        let service = TradesService()
        service.actionLists = [.success([tradesAction()])]
        service.confirmResult = .failure(PersistentAssistantHTTPClient.Error.upgradeRequired("Upgrade to Pro."))
        let viewModel = await loadedViewModel(service)
        await viewModel.confirmTrades(tradesAction())
        XCTAssertEqual(viewModel.tradesReviews["a1"]?.refusal?.message, "Saving trades from a screenshot is part of Pro.")
        XCTAssertNil(viewModel.tradesReviews["a1"]?.closedMessage)
    }

    func testOtherFailureSaysTryAgainAndKeepsEdits() async throws {
        let service = TradesService()
        service.actionLists = [.success([tradesAction()])]
        service.confirmResult = .failure(TradesService.Offline())
        let viewModel = await loadedViewModel(service)
        var card = try XCTUnwrap(viewModel.tradesReviews["a1"])
        card.rows[0].price = "101"
        viewModel.updateTradesReview(card)
        await viewModel.confirmTrades(tradesAction())
        XCTAssertEqual(viewModel.tradesReviews["a1"]?.refusal?.message, "That did not go through. Try again.")
        XCTAssertEqual(viewModel.tradesReviews["a1"]?.rows[0].price, "101")
        XCTAssertNil(viewModel.activeActionID)
    }

    func testCardThatCannotSaveSendsNothing() async throws {
        let service = TradesService()
        service.actionLists = [.success([tradesAction(arguments: storedArguments(synced: true))])]
        let viewModel = await loadedViewModel(service)
        await viewModel.confirmTrades(tradesAction())
        XCTAssertTrue(service.confirmed.isEmpty)
    }

    func testReloadKeepsEditsAndLoadsListsOnce() async throws {
        let service = TradesService()
        service.actionLists = [.success([tradesAction()])]
        service.listsResult = .success([
            PortfolioListDTOResponse(id: otherListID, name: "Main", isDefault: true, createdAt: nil, updatedAt: nil),
        ])
        let viewModel = await loadedViewModel(service)
        XCTAssertEqual(viewModel.portfolioLists?.map(\.id), [otherListID])
        var card = try XCTUnwrap(viewModel.tradesReviews["a1"])
        card.rows[0].symbol = "AAPL.US"
        viewModel.updateTradesReview(card)
        await viewModel.load()
        XCTAssertEqual(viewModel.tradesReviews["a1"]?.rows[0].symbol, "AAPL.US")
        XCTAssertEqual(service.listsCalls, 1)
    }

    // MARK: - Localisation

    /// Every string the card adds, as the code's keys, is translated in the
    /// app's compiled pt-PT strings.
    func testEveryCardStringHasPortuguese() throws {
        let keys = [
            "Review trades", "Check each row against your screenshot. Only ticked rows are saved.", "Expires %@",
            "Saving to %@", "Portfolio", "Not applied", "Save %@", "Side", "Buy", "Sell", "Symbol", "Shares", "Price",
            "Date", "Currency", "Fees", "Hard to read — check", "Cancel",
            "This portfolio syncs from IBKR, so saved trades would be overwritten. Pick another portfolio.",
            "Sells update realized P&L, not yet your annual tax figures.",
            "This review expired. Send the screenshot again.",
            "Those trades were not saved and this review is closed. Send the screenshot again.",
            "That did not go through. Try again.", "Saving trades from a screenshot is part of Pro.",
            "Saves as %@, not %@", "Saves as %@", "Is that %@ or %@? Type it without the comma.",
            "Spaces and a decimal point do not go together here. Type it without the spaces.",
            "Enter a symbol.", "Enter the number of shares.", "Enter the price.", "Enter the date.",
            "Fees must be a number, or blank.", "1 row left out (options, shorts, dividends or fees).",
            "%lld rows left out (options, shorts, dividends or fees).", "Save 1 trade", "Save %lld trades",
            "the proposed portfolio",
        ]
        let path = try XCTUnwrap(Bundle.main.path(forResource: "pt-PT", ofType: "lproj"))
        let portuguese = try XCTUnwrap(Bundle(path: path))
        for key in keys {
            let missing = "\u{0}missing"
            let value = portuguese.localizedString(forKey: key, value: missing, table: nil)
            XCTAssertNotEqual(value, missing, key)
            XCTAssertNotEqual(value, key, key)
        }
        XCTAssertEqual(portuguese.localizedString(forKey: "Saves as %@, not %@", value: nil, table: nil), "Guarda como %1$@, não %2$@")
    }

    // MARK: - Wire

    func testConfirmRequestSendsTheReviewedRowsAsJSON() async throws {
        let session = StubSession(status: 200, body: confirmedJSON)
        let trades = [
            AIReviewedTrade(symbol: "AAPL", side: "buy", quantity: 1.5, price: 100.25, tradeDate: "2024-03-10"),
            AIReviewedTrade(symbol: "ASML", side: "sell", quantity: 2, price: 610, tradeDate: "2024-03-11", currency: "EUR", fees: 1.25),
        ]
        let result = try await client(session).confirmTrades(id: "a1", portfolioListID: storedListID, trades: trades)
        XCTAssertEqual(result.message, "Trades recorded.")

        let request = try XCTUnwrap(session.request)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/v1/ai/assistant/actions/a1/confirm")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(Set(body.keys), ["portfolioListId", "trades"])
        XCTAssertEqual(body["portfolioListId"] as? String, storedListID)
        let rows = try XCTUnwrap(body["trades"] as? [[String: Any]])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(Set(rows[0].keys), ["symbol", "side", "quantity", "price", "tradeDate"], "blank currency and fees are left out")
        XCTAssertEqual(rows[0]["quantity"] as? Double, 1.5)
        XCTAssertEqual(rows[0]["price"] as? Double, 100.25)
        XCTAssertEqual(rows[0]["tradeDate"] as? String, "2024-03-10")
        XCTAssertEqual(Set(rows[1].keys), ["symbol", "side", "quantity", "price", "tradeDate", "currency", "fees"])
        XCTAssertEqual(rows[1]["currency"] as? String, "EUR")
        XCTAssertEqual(rows[1]["fees"] as? Double, 1.25)
    }

    func testPortfolioListsComeFromTheListsRoute() async throws {
        let session = StubSession(status: 200, body: #"[{"id":"\#(otherListID)","name":"Main","isDefault":true}]"#)
        let lists = try await client(session).portfolioLists()
        XCTAssertEqual(lists.map(\.name), ["Main"])
        XCTAssertEqual(session.request?.url?.path, "/v1/portfolio/lists")
        XCTAssertEqual(session.request?.httpMethod, "GET")
    }
}
