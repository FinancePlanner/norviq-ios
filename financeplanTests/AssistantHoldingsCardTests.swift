import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

/// The holdings card's wire is the backend's `update_holdings` confirm
/// (`assistant/holdings.go`); its number rules are the trades card's.

private let listID = "8F1C2B9A-0D4E-4C1B-9E7A-3B5D6C7E8F90"

/// AAPL is complete and new, MSFT has no cost and would replace an import,
/// TSLA is complete and would replace a manual holding.
private func storedArguments() -> String {
    #"{"portfolioListId":"\#(listID)","fromCsv":false,"rows":["#
        + #"{"symbol":"AAPL","shares":10,"avgPrice":150.5,"buyDate":"2024-03-15","existing":"none","willReplaceImport":false,"needsCost":false},"#
        + #"{"symbol":"MSFT","shares":2.5,"avgPrice":null,"buyDate":null,"existing":"imported","willReplaceImport":true,"needsCost":true},"#
        + #"{"symbol":"TSLA","shares":3,"avgPrice":200,"buyDate":null,"existing":"manual","willReplaceImport":false,"needsCost":false}"#
        + "]}"
}

private func holdingsAction(id: String = "a1") -> AIPendingActionResponse {
    AIPendingActionResponse(
        id: id,
        conversationId: "c1",
        toolName: "update_holdings",
        summary: "Update 3 holdings in Growth.",
        arguments: storedArguments(),
        status: .pending,
        expiresAt: "2026-11-05T12:15:00Z",
        createdAt: "2026-11-05T12:00:00Z"
    )
}

private final class HoldingsService: PersistentAssistantServicing, @unchecked Sendable {
    struct Unused: Error {}

    var actions: [AIPendingActionResponse] = [holdingsAction()]
    /// Answers to successive confirms; the last one repeats.
    var confirmResults: [Result<AIConfirmedActionResponse, Error>] = []
    private(set) var confirmed: [(id: String, body: AIReviewedHoldings)] = []

    static func done(_ message: String) -> Result<AIConfirmedActionResponse, Error> {
        .success(AIConfirmedActionResponse(actionId: "a1", status: .completed, resultId: nil, message: message))
    }

    func confirmHoldings(id: String, body: AIReviewedHoldings) async throws -> AIConfirmedActionResponse {
        confirmed.append((id, body))
        return try confirmResults[min(confirmed.count - 1, confirmResults.count - 1)].get()
    }

    func pendingActions() async throws -> [AIPendingActionResponse] { actions }
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
    func portfolioLists() async throws -> [PortfolioListDTOResponse] { [] }
    func streamTurn(conversationID _: String, content _: String, attachments _: [AssistantAttachment], context _: AssistantTurnContext?) -> AsyncThrowingStream<PersistentAssistantStreamEvent, Error> {
        AsyncThrowingStream { $0.finish(throwing: Unused()) }
    }
    func conversation(id _: String) async throws -> AIConversationResponse { throw Unused() }
    func deleteConversation(id _: String) async throws { throw Unused() }
    func turn(conversationID _: String, content _: String) async throws -> AIAssistantTurnResponse { throw Unused() }
    func updatePreferences(_: AIAssistantPreferencesResponse) async throws -> AIAssistantPreferencesResponse { throw Unused() }
    func dismissTip(id _: String) async throws { throw Unused() }
    func confirmAction(id _: String) async throws -> AIConfirmedActionResponse { throw Unused() }
    func confirmTrades(id _: String, portfolioListID _: String, trades _: [AIReviewedTrade]) async throws -> AIConfirmedActionResponse { throw Unused() }
    func cancelAction(id _: String) async throws { throw Unused() }
    func memos(bookmarked _: Bool?, conversationID _: String?) async throws -> [PositionMemoListItem] { [] }
    func memo(id _: String) async throws -> PositionMemoDetail { throw Unused() }
    func bookmarkMemo(id _: String, bookmarked _: Bool) async throws -> PositionMemoCard { throw Unused() }
    func deleteMemo(id _: String) async throws { throw Unused() }
}

@MainActor
final class AssistantHoldingsCardTests: XCTestCase {
    private func loadedViewModel(_ service: HoldingsService) async -> PersistentAssistantViewModel {
        let viewModel = PersistentAssistantViewModel(service: service, sleep: { _ in })
        await viewModel.load()
        return viewModel
    }

    private func card() throws -> AssistantHoldingsReview {
        try XCTUnwrap(AssistantHoldingsReview(action: holdingsAction()))
    }

    func testToolNameAndDecode() throws {
        XCTAssertEqual(AssistantHoldingsReview.toolName, "update_holdings")
        let review = try card()
        XCTAssertEqual(review.rows.map(\.symbol), ["AAPL", "MSFT", "TSLA"])
        XCTAssertEqual(review.rows[1].shares, "2.5")
        XCTAssertEqual(review.rows[1].avgPrice, "")
        XCTAssertEqual(review.portfolioListID, listID)
        var other = holdingsAction()
        other = AIPendingActionResponse(
            id: "a2", conversationId: "c1", toolName: "record_trades", summary: "", arguments: storedArguments(),
            status: .pending, expiresAt: other.expiresAt, createdAt: other.createdAt
        )
        XCTAssertNil(AssistantHoldingsReview(action: other))
    }

    func testBadges() throws {
        let rows = try card().rows
        XCTAssertEqual(rows.map(\.badge), ["New", "Replaces import", "Replaces existing"])
        let flagged = AssistantHoldingRow(index: 0, holding: AIProposedHolding(
            symbol: "X", shares: 1, avgPrice: 1, buyDate: nil, existing: "none", willReplaceImport: true, needsCost: false
        ))
        XCTAssertEqual(flagged.badge, "Replaces import")
        let mixed = AssistantHoldingRow(index: 0, holding: AIProposedHolding(
            symbol: "X", shares: 1, avgPrice: 1, buyDate: nil, existing: "mixed", willReplaceImport: false, needsCost: false
        ))
        XCTAssertEqual(mixed.badge, "Replaces existing")
    }

    func testConfirmDisabledUntilCostFilled() throws {
        var review = try card()
        XCTAssertFalse(review.canSave, "MSFT is ticked and has no cost")
        XCTAssertEqual(review.problem(at: 1), "Enter the average price.")
        review.rows[1].avgPrice = "12,5"
        XCTAssertTrue(review.canSave)
        review.rows[1].avgPrice = "0"
        XCTAssertFalse(review.canSave, "a cost of 0 is not a cost")
        review.rows[1].keep = false
        XCTAssertTrue(review.canSave, "an unticked row does not block")
        review.rows[0].shares = ""
        XCTAssertFalse(review.canSave, "a ticked row with no shares blocks")
        review.rows[0].shares = "-1"
        XCTAssertFalse(review.canSave)
        for index in review.rows.indices { review.rows[index].keep = false }
        XCTAssertFalse(review.canSave, "nothing ticked")
        review.rows[0].shares = "10"
        review.rows[0].keep = true
        review.rows[0].buyDate = "2024-13-40"
        XCTAssertFalse(review.canSave, "a date that is not on the calendar")
        review.rows[0].buyDate = ""
        XCTAssertTrue(review.canSave, "a blank date is fine")
    }

    func testDecimalCommaParses() throws {
        var review = try card()
        review.rows[0].shares = "1,5"
        review.rows[0].avgPrice = "1.234,5"
        review.rows[1].keep = false
        review.rows[2].keep = false
        let sent = try XCTUnwrap(review.confirmBody.rows.first)
        XCTAssertEqual(sent.shares, 1.5)
        XCTAssertEqual(sent.avgPrice, 1234.5)
        XCTAssertEqual(TradeNumber.parse("1,5"), 1.5)
        XCTAssertEqual(TradeNumber.parse("1.234,5"), 1234.5)
        review.rows[0].shares = "1,234"
        XCTAssertFalse(review.canSave, "ambiguous, as on the trades card")
    }

    func testConfirmBodySendsOnlyTickedRowsAndTheCardList() throws {
        var review = try card()
        review.rows[1].avgPrice = "9"
        review.rows[2].keep = false
        review.rows[0].symbol = " AAPL "
        let body = review.confirmBody
        XCTAssertEqual(body.portfolioListId, listID)
        XCTAssertFalse(body.replaceExisting)
        XCTAssertEqual(body.rows.map(\.symbol), ["AAPL", "MSFT"])
        XCTAssertEqual(body.rows[0].buyDate, "2024-03-15")
        XCTAssertNil(body.rows[1].buyDate)
        XCTAssertEqual(body.rows[1].avgPrice, 9)
    }

    func testCollisionShowsReplaceToggleAndResends() async throws {
        let service = HoldingsService()
        service.confirmResults = [
            .failure(PersistentAssistantHTTPClient.Error.holdingsRefused(AIHoldingsRefusalResponse(
                reason: "These holdings already exist: TSLA. Turn on “Replace existing” to update them.",
                code: "holdings_collision", symbols: ["TSLA"], rows: []
            ))),
            HoldingsService.done("Saved AAPL, MSFT, TSLA."),
        ]
        let viewModel = await loadedViewModel(service)
        var review = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        review.rows[1].avgPrice = "9"
        viewModel.updateHoldingsReview(review)

        await viewModel.confirmHoldings(holdingsAction())
        let refused = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        XCTAssertTrue(refused.showsReplaceToggle)
        XCTAssertFalse(refused.replaceExisting)
        XCTAssertEqual(refused.refusal?.message, "These holdings already exist: TSLA. Turn on “Replace existing” to update them.")
        XCTAssertNil(refused.closedMessage, "the card stays open")
        XCTAssertEqual(service.confirmed.count, 1)
        XCTAssertFalse(service.confirmed[0].body.replaceExisting)

        await viewModel.setReplaceExisting(true, for: holdingsAction())
        XCTAssertEqual(service.confirmed.count, 2, "turning it on resends")
        XCTAssertTrue(service.confirmed[1].body.replaceExisting)
        XCTAssertEqual(service.confirmed[1].body.rows.map(\.symbol), ["AAPL", "MSFT", "TSLA"])
        XCTAssertEqual(viewModel.holdingsReviews["a1"]?.completedMessage, "Saved AAPL, MSFT, TSLA.")
    }

    func testTurningReplaceOffDoesNotResend() async throws {
        let service = HoldingsService()
        service.confirmResults = [HoldingsService.done("Saved AAPL.")]
        let viewModel = await loadedViewModel(service)
        await viewModel.setReplaceExisting(false, for: holdingsAction())
        XCTAssertTrue(service.confirmed.isEmpty)
        XCTAssertEqual(viewModel.holdingsReviews["a1"]?.replaceExisting, false)
    }

    func testRowErrorLandsOnRow() async throws {
        let service = HoldingsService()
        service.confirmResults = [
            .failure(PersistentAssistantHTTPClient.Error.holdingsRefused(AIHoldingsRefusalResponse(
                reason: "Some rows need fixing.", code: nil, symbols: [],
                // Index 0 of the SENT rows is MSFT here: AAPL is unticked.
                rows: [AIHoldingRowError(index: 0, message: "MSFT: shares must be above zero."), AIHoldingRowError(index: 9, message: "Out of range.")]
            ))),
        ]
        let viewModel = await loadedViewModel(service)
        var review = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        review.rows[0].keep = false
        review.rows[1].avgPrice = "9"
        viewModel.updateHoldingsReview(review)

        await viewModel.confirmHoldings(holdingsAction())
        let card = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        XCTAssertEqual(card.refusal?.byRow[1], ["MSFT: shares must be above zero."])
        XCTAssertNil(card.refusal?.byRow[0], "not on the card's first row")
        XCTAssertEqual(card.refusal?.unplaced, ["Out of range."])
        XCTAssertFalse(card.showsReplaceToggle, "no collision")
    }

    func testCollisionAndRowErrorsShowTogether() async throws {
        let service = HoldingsService()
        service.confirmResults = [
            .failure(PersistentAssistantHTTPClient.Error.holdingsRefused(AIHoldingsRefusalResponse(
                reason: "These holdings already exist: TSLA.", code: "holdings_collision", symbols: ["TSLA"],
                rows: [AIHoldingRowError(index: 0, message: "AAPL: bad date.")]
            ))),
        ]
        let viewModel = await loadedViewModel(service)
        var review = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        review.rows[1].avgPrice = "9"
        viewModel.updateHoldingsReview(review)
        await viewModel.confirmHoldings(holdingsAction())
        let card = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        XCTAssertTrue(card.showsReplaceToggle)
        XCTAssertEqual(card.refusal?.byRow[0], ["AAPL: bad date."])
    }

    func testExpiredShowsResendCopy() async throws {
        let service = HoldingsService()
        service.confirmResults = [.failure(PersistentAssistantHTTPClient.Error.conflict("Action is no longer available for confirmation."))]
        let viewModel = await loadedViewModel(service)
        var review = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        review.rows[1].avgPrice = "9"
        viewModel.updateHoldingsReview(review)
        await viewModel.confirmHoldings(holdingsAction())
        XCTAssertEqual(viewModel.holdingsReviews["a1"]?.closedMessage, "This card expired. Send the file again.")
        XCTAssertEqual(AssistantHoldingsReview.expiredCopy, "This card expired. Send the file again.")
    }

    func testPartialResultListsFailed() async throws {
        let service = HoldingsService()
        let message = "Saved AAPL, MSFT. Couldn't save TSLA: Unknown symbol."
        service.confirmResults = [HoldingsService.done(message)]
        let viewModel = await loadedViewModel(service)
        var review = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        review.rows[1].avgPrice = "9"
        viewModel.updateHoldingsReview(review)
        await viewModel.confirmHoldings(holdingsAction())
        let card = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        XCTAssertEqual(card.completedMessage, message)
        XCTAssertNil(viewModel.errorMessage, "the settled card shows it; no alert as well")
        XCTAssertTrue(card.completedMessage?.contains("Couldn't save TSLA: Unknown symbol.") == true)
        XCTAssertFalse(card.canSave, "a settled card cannot be saved again")
    }

    func testUpgradeRequiredShowsProCopy() async throws {
        let body = Data(#"{"success":false,"code":"upgrade_required","error":"Limit reached."}"#.utf8)
        let failure = PersistentAssistantHTTPClient.Error.makeStatus(403, message: "Limit reached.", body: body)
        XCTAssertEqual(failure, .upgradeRequired("Limit reached."))
        let service = HoldingsService()
        service.confirmResults = [.failure(failure)]
        let viewModel = await loadedViewModel(service)
        var review = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        review.rows[1].avgPrice = "9"
        viewModel.updateHoldingsReview(review)
        await viewModel.confirmHoldings(holdingsAction())
        XCTAssertEqual(viewModel.holdingsReviews["a1"]?.refusal?.message, AssistantHoldingsReview.upgradeCopy)
        XCTAssertNil(viewModel.holdingsReviews["a1"]?.closedMessage)
    }

    func testGenericEnvelope422StaysUnprocessableAndShowsItsReason() async throws {
        let body = Data(#"{"error":true,"code":"unprocessable_entity","reason":"x"}"#.utf8)
        let failure = PersistentAssistantHTTPClient.Error.makeStatus(422, message: nil, body: body)
        XCTAssertEqual(failure, .unprocessable(reason: "x", rowErrors: []))
        let service = HoldingsService()
        service.confirmResults = [.failure(failure)]
        let viewModel = await loadedViewModel(service)
        var review = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        review.rows[1].avgPrice = "9"
        viewModel.updateHoldingsReview(review)
        await viewModel.confirmHoldings(holdingsAction())
        XCTAssertEqual(viewModel.holdingsReviews["a1"]?.refusal?.message, "x")
    }

    func testToggleStaysVisibleWhileOn() async throws {
        let service = HoldingsService()
        service.confirmResults = [
            .failure(PersistentAssistantHTTPClient.Error.holdingsRefused(AIHoldingsRefusalResponse(
                reason: "These holdings already exist: TSLA.", code: "holdings_collision", symbols: ["TSLA"], rows: []
            ))),
            .failure(PersistentAssistantHTTPClient.Error.holdingsRefused(AIHoldingsRefusalResponse(
                reason: "Some rows need fixing.", code: nil, symbols: [],
                rows: [AIHoldingRowError(index: 0, message: "AAPL: bad date.")]
            ))),
        ]
        let viewModel = await loadedViewModel(service)
        var review = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        review.rows[1].avgPrice = "9"
        viewModel.updateHoldingsReview(review)
        await viewModel.confirmHoldings(holdingsAction())
        await viewModel.setReplaceExisting(true, for: holdingsAction())
        let card = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        XCTAssertEqual(card.refusal?.byRow[0], ["AAPL: bad date."])
        XCTAssertTrue(card.replaceExisting)
        XCTAssertTrue(card.showsReplaceToggle, "row errors only, but the toggle is on")
    }

    func testExpiredAfterAttemptShowsMaybeSavedCopy() async throws {
        let service = HoldingsService()
        service.confirmResults = [
            .failure(PersistentAssistantHTTPClient.Error.invalidStatus(500)),
            .failure(PersistentAssistantHTTPClient.Error.conflict("gone")),
        ]
        let viewModel = await loadedViewModel(service)
        var review = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        review.rows[1].avgPrice = "9"
        viewModel.updateHoldingsReview(review)
        await viewModel.confirmHoldings(holdingsAction())
        XCTAssertEqual(viewModel.holdingsReviews["a1"]?.refusal?.message, "That did not go through. Try again.")
        await viewModel.confirmHoldings(holdingsAction())
        XCTAssertEqual(viewModel.holdingsReviews["a1"]?.closedMessage, AssistantHoldingsReview.maybeSavedCopy)
    }

    func testNewBadgeIsLocalisedKey() throws {
        XCTAssertEqual(try card().rows[0].badge, "New")
    }

    func testNothingTickedNeverCallsTheBackend() async throws {
        let service = HoldingsService()
        service.confirmResults = [HoldingsService.done("x")]
        let viewModel = await loadedViewModel(service)
        var review = try XCTUnwrap(viewModel.holdingsReviews["a1"])
        for index in review.rows.indices { review.rows[index].keep = false }
        viewModel.updateHoldingsReview(review)
        await viewModel.confirmHoldings(holdingsAction())
        XCTAssertTrue(service.confirmed.isEmpty, "an empty rows list is a 422, so it is never sent")
    }

    // MARK: - Wire

    func testRefusalBodyBecomesAHoldingsRefusal() {
        let body = Data(#"{"reason":"These holdings already exist: AAPL.","code":"holdings_collision","symbols":["AAPL"],"rows":[{"index":1,"message":"Bad."}]}"#.utf8)
        let error = PersistentAssistantHTTPClient.Error.makeStatus(422, message: nil, body: body)
        XCTAssertEqual(error, .holdingsRefused(AIHoldingsRefusalResponse(
            reason: "These holdings already exist: AAPL.", code: "holdings_collision", symbols: ["AAPL"],
            rows: [AIHoldingRowError(index: 1, message: "Bad.")]
        )))
        let plain = PersistentAssistantHTTPClient.Error.makeStatus(422, message: nil, body: Data(#"{"reason":"Nothing was selected to save."}"#.utf8))
        XCTAssertEqual(plain, .unprocessable(reason: "Nothing was selected to save.", rowErrors: []))
    }

    func testEndpointBodyIsCamelCase() throws {
        let endpoint = ConfirmAssistantHoldingsEndpoint(id: "a1", payload: AIReviewedHoldings(
            portfolioListId: listID, replaceExisting: true,
            rows: [AIReviewedHolding(symbol: "AAPL", shares: 10, avgPrice: 150.5, buyDate: nil)]
        ))
        XCTAssertEqual(endpoint.path, "/v1/ai/assistant/actions/a1/confirm")
        let parameters = try endpoint.asParameters()
        XCTAssertEqual(parameters["portfolioListId"] as? String, listID)
        XCTAssertEqual(parameters["replaceExisting"] as? Bool, true)
        let rows = try XCTUnwrap(parameters["rows"] as? [[String: Any]])
        XCTAssertEqual(rows.first?["avgPrice"] as? Double, 150.5)
        XCTAssertNil(rows.first?["buyDate"])
    }
}
