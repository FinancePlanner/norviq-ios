import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

// MARK: - Fixtures

private enum Fixture {
    static let watchArguments = #"""
    {"condition":"it drops below $180","confirmationText":"Got it — I'll watch AAPL and ping you when it drops below $180.","firstRunAt":"2026-09-24T08:00:00Z","intervalMinutes":1440,"scheduleHuman":"Every day at 8:00","spec":"Check AAPL and tell me when it drops below $180.","title":"Watch AAPL"}
    """#
    static let confirmationText = "Got it — I'll watch AAPL and ping you when it drops below $180."

    static func action(id: String = "a1", toolName: String = "create_watch", arguments: String = watchArguments) -> AIPendingActionResponse {
        AIPendingActionResponse(
            id: id, conversationId: "c1", toolName: toolName, summary: "Watch AAPL every day at 8:00",
            arguments: arguments, status: .pending,
            expiresAt: "2026-09-25T00:00:00Z", createdAt: "2026-09-24T00:00:00Z"
        )
    }

    static let proposal = AIWatchProposalResponse(
        title: "Watch AAPL", scheduleHuman: "Every day at 8:00", intervalMinutes: 1440,
        spec: "Check AAPL and tell me when it drops below $180."
    )

    static func message(
        _ id: String, role: AIAssistantRole = .assistant, content: String,
        origin: AIMessageOrigin? = nil, sourceLabel: String? = nil
    ) -> AIMessageResponse {
        AIMessageResponse(
            id: id, conversationId: "c1", role: role, content: content,
            createdAt: "2026-09-24T00:00:00Z", origin: origin, sourceLabel: sourceLabel
        )
    }

    static func turn(action: AIPendingActionResponse, proposal: AIWatchProposalResponse?) -> AIAssistantTurnResponse {
        AIAssistantTurnResponse(
            kind: .confirmationRequired, conversationId: "c1",
            message: message("m1", content: "I can set that up as a standing task."),
            pendingAction: action, memo: nil, watchProposal: proposal
        )
    }
}

// MARK: - DTO decoding

@MainActor
final class MuseStageCDecodingTests: XCTestCase {
    func testMessageWithoutNewFieldsDecodesAsReply() throws {
        let json = #"{"id":"m1","conversationId":"c1","role":"assistant","content":"Hi","createdAt":"2026-09-24T00:00:00Z"}"#
        let message = try JSONDecoder.stockPlanShared.decode(AIMessageResponse.self, from: Data(json.utf8))
        XCTAssertNil(message.origin)
        XCTAssertNil(message.sourceLabel)
        XCTAssertNil(MuseMessageCaption.text(for: message))
    }

    func testProactiveMessageDecodesOriginAndLabel() throws {
        let json = #"{"id":"m1","conversationId":"c1","role":"assistant","content":"Got it","createdAt":"2026-09-24T00:00:00Z","origin":"proactive","sourceLabel":"Standing task"}"#
        let message = try JSONDecoder.stockPlanShared.decode(AIMessageResponse.self, from: Data(json.utf8))
        XCTAssertEqual(message.origin, .proactive)
        XCTAssertEqual(message.sourceLabel, "Standing task")
    }

    func testTurnWithoutWatchProposalDecodes() throws {
        let json = #"""
        {"kind":"message","conversationId":"c1","message":{"id":"m1","conversationId":"c1","role":"assistant","content":"Done.","createdAt":"2026-09-24T00:00:00Z"}}
        """#
        let turn = try JSONDecoder.stockPlanShared.decode(AIAssistantTurnResponse.self, from: Data(json.utf8))
        XCTAssertNil(turn.watchProposal)
        XCTAssertNil(turn.pendingAction)
    }

    func testStreamedTurnWithWatchProposalDecodes() throws {
        let arguments = Fixture.watchArguments
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "\\\"")
        let json = """
        {"kind":"confirmation_required","conversationId":"c1",
         "message":{"id":"m1","conversationId":"c1","role":"assistant","content":"I can set that up.","createdAt":"2026-09-24T00:00:00Z","origin":"reply"},
         "pendingAction":{"id":"a1","conversationId":"c1","toolName":"create_watch","summary":"Watch AAPL","arguments":"\(arguments)","status":"pending","expiresAt":"2026-09-25T00:00:00Z","createdAt":"2026-09-24T00:00:00Z"},
         "watchProposal":{"title":"Watch AAPL","scheduleHuman":"Every day at 8:00","intervalMinutes":1440,"spec":"Check AAPL and tell me when it drops below $180."}}
        """
        let event = try AssistantStreamClient.decodePersistent(event: "turn", json: json)
        guard case let .turn(turn) = event else { return XCTFail("expected turn, got \(String(describing: event))") }
        XCTAssertEqual(turn.kind, .confirmationRequired)
        XCTAssertEqual(turn.message.origin, .reply)
        XCTAssertEqual(turn.watchProposal, Fixture.proposal)
        XCTAssertEqual(turn.pendingAction.flatMap { MuseStandingTask.from($0) }?.title, "Watch AAPL")
    }

    func testConflictStatusKeepsItsCode() {
        let error = PersistentAssistantHTTPClient.Error.makeStatus(409, message: "Action is no longer pending.")
        XCTAssertEqual(error, .conflict("Action is no longer pending."))
        XCTAssertEqual(error.statusCode, 409)
        XCTAssertEqual(PersistentAssistantHTTPClient.Error.makeStatus(500, message: "Boom"), .api("Boom"))
        XCTAssertEqual(PersistentAssistantHTTPClient.Error.makeStatus(500, message: nil), .invalidStatus(500))
    }
}

// MARK: - Mapping

final class MuseStandingTaskMappingTests: XCTestCase {
    func testProposalWins() {
        let action = Fixture.action(arguments: #"{"title":"Old","scheduleHuman":"Every hour","spec":"old"}"#)
        let task = MuseStandingTask.from(action, proposal: Fixture.proposal)
        XCTAssertEqual(task, MuseStandingTask(
            actionID: "a1", title: "Watch AAPL", scheduleHuman: "Every day at 8:00",
            spec: "Check AAPL and tell me when it drops below $180."
        ))
    }

    func testReloadRedrawsFromArguments() {
        let task = MuseStandingTask.from(Fixture.action())
        XCTAssertEqual(task?.title, "Watch AAPL")
        XCTAssertEqual(task?.scheduleHuman, "Every day at 8:00")
        XCTAssertEqual(task?.spec, "Check AAPL and tell me when it drops below $180.")
    }

    func testOtherActionsAndBadArgumentsFallBack() {
        XCTAssertNil(MuseStandingTask.from(Fixture.action(toolName: "add_expense"), proposal: Fixture.proposal))
        XCTAssertNil(MuseStandingTask.from(Fixture.action(arguments: "not json")))
        XCTAssertNil(MuseStandingTask.from(Fixture.action(arguments: #"{"title":"x"}"#)))
    }

    func testCaptionOnlyForProactiveAgentMessages() {
        XCTAssertEqual(MuseMessageCaption.text(for: Fixture.message("1", content: "x", origin: .proactive, sourceLabel: "Daily tip")), "Daily tip")
        XCTAssertEqual(MuseMessageCaption.text(for: Fixture.message("2", content: "x", origin: .proactive, sourceLabel: "  ")), "From Vig")
        XCTAssertNil(MuseMessageCaption.text(for: Fixture.message("3", content: "x", origin: .reply, sourceLabel: "Standing task")))
        XCTAssertNil(MuseMessageCaption.text(for: Fixture.message("4", role: .user, content: "x", origin: .proactive, sourceLabel: "Standing task")))
    }
}

// MARK: - Card flows

@MainActor
final class MuseStandingTaskFlowTests: XCTestCase {
    private struct Unused: Error {}

    private final class StubAPI: PersistentAssistantServicing, @unchecked Sendable {
        var messages: [AIMessageResponse] = []
        var actions: [AIPendingActionResponse] = []
        var events: [PersistentAssistantStreamEvent] = []
        var confirmResult: Result<AIConfirmedActionResponse, any Error> = .failure(Unused())
        var cancelResult: Result<Void, any Error> = .success(())
        /// Messages the server appends when an action is confirmed.
        var appendOnConfirm: [AIMessageResponse] = []
        var failConversationFetch = false
        private(set) var confirmed: [String] = []
        private(set) var cancelled: [String] = []

        func conversation(id: String) async throws -> AIConversationResponse {
            if failConversationFetch { throw Unused() }
            return AIConversationResponse(id: id, title: "Test", messages: messages, createdAt: "2026-09-24T00:00:00Z", updatedAt: "2026-09-24T00:00:00Z")
        }
        func streamTurn(conversationID _: String, content _: String) -> AsyncThrowingStream<PersistentAssistantStreamEvent, Error> {
            let events = events
            return AsyncThrowingStream { continuation in
                for event in events { continuation.yield(event) }
                continuation.finish()
            }
        }
        func confirmAction(id: String) async throws -> AIConfirmedActionResponse {
            confirmed.append(id)
            let result = try confirmResult.get()
            messages += appendOnConfirm
            return result
        }
        func cancelAction(id: String) async throws {
            cancelled.append(id)
            try cancelResult.get()
        }
        func pendingActions() async throws -> [AIPendingActionResponse] { actions }
        func conversations() async throws -> [AIConversationSummaryResponse] {
            [AIConversationSummaryResponse(id: "c1", title: "Test", lastMessagePreview: nil, createdAt: "2026-09-24T00:00:00Z", updatedAt: "2026-09-24T00:00:00Z")]
        }
        func usage() async throws -> AIAssistantUsageResponse {
            AIAssistantUsageResponse(month: "2026-09", used: 1, limit: nil, remaining: nil, isPro: true)
        }
        func createConversation(title _: String?) async throws -> AIConversationResponse { throw Unused() }
        func deleteConversation(id _: String) async throws { throw Unused() }
        func turn(conversationID _: String, content _: String) async throws -> AIAssistantTurnResponse { throw Unused() }
        func preferences() async throws -> AIAssistantPreferencesResponse {
            AIAssistantPreferencesResponse(proactiveTipsEnabled: true, pushEnabled: false, timezone: "UTC")
        }
        func updatePreferences(_: AIAssistantPreferencesResponse) async throws -> AIAssistantPreferencesResponse { throw Unused() }
        func tips() async throws -> [AITipResponse] { [] }
        func dismissTip(id _: String) async throws { throw Unused() }
        func memos(bookmarked _: Bool?, conversationID _: String?) async throws -> [PositionMemoListItem] { [] }
        func memo(id _: String) async throws -> PositionMemoDetail { throw Unused() }
        func bookmarkMemo(id _: String, bookmarked _: Bool) async throws -> PositionMemoCard { throw Unused() }
        func deleteMemo(id _: String) async throws { throw Unused() }
    }

    private let confirmed = AIConfirmedActionResponse(actionId: "a1", status: .completed, resultId: "w1", message: Fixture.confirmationText)

    /// Streams a turn that proposes a watch.
    private func streamedProposal(_ api: StubAPI) async throws -> PersistentAssistantViewModel {
        let action = Fixture.action()
        api.events = [.started, .turn(Fixture.turn(action: action, proposal: Fixture.proposal)), .done]
        let viewModel = PersistentAssistantViewModel(service: api, sleep: { _ in })
        try await viewModel.selectConversation(id: "c1")
        viewModel.draft = "Watch AAPL every morning and tell me when it drops below 180"
        await viewModel.send()
        return viewModel
    }

    func testStreamedTurnShowsTheProposalCard() async throws {
        let api = StubAPI()
        let viewModel = try await streamedProposal(api)
        let action = try XCTUnwrap(viewModel.pendingActions.first)
        XCTAssertEqual(viewModel.watchProposals[action.id], Fixture.proposal)
        XCTAssertEqual(viewModel.standingTask(for: action)?.scheduleHuman, "Every day at 8:00")
    }

    func testReloadRedrawsTheCardFromTheListedAction() async {
        let api = StubAPI()
        api.actions = [Fixture.action()]
        let viewModel = PersistentAssistantViewModel(service: api, sleep: { _ in })
        await viewModel.load()
        let action = try? XCTUnwrap(viewModel.pendingActions.first)
        XCTAssertNotNil(action)
        XCTAssertTrue(viewModel.watchProposals.isEmpty)
        XCTAssertEqual(action.flatMap { viewModel.standingTask(for: $0) }?.title, "Watch AAPL")
    }

    func testConfirmRefetchesTheServersStandingTaskMessage() async throws {
        let api = StubAPI()
        let viewModel = try await streamedProposal(api)
        api.confirmResult = .success(confirmed)
        api.appendOnConfirm = [Fixture.message("m9", content: Fixture.confirmationText, origin: .proactive, sourceLabel: "Standing task")]

        await viewModel.confirm(try XCTUnwrap(viewModel.pendingActions.first))

        XCTAssertEqual(api.confirmed, ["a1"])
        XCTAssertTrue(viewModel.pendingActions.isEmpty)
        XCTAssertTrue(viewModel.watchProposals.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        let last = try XCTUnwrap(viewModel.activeConversation?.messages.last)
        XCTAssertEqual(last.id, "m9")
        XCTAssertEqual(MuseMessageCaption.text(for: last), "Standing task")
        XCTAssertEqual(viewModel.activeConversation?.messages.filter { $0.content == Fixture.confirmationText }.count, 1)
    }

    func testConfirmAppendsLocallyWhenTheRefetchFails() async throws {
        let api = StubAPI()
        let viewModel = try await streamedProposal(api)
        api.confirmResult = .success(confirmed)
        api.failConversationFetch = true

        await viewModel.confirm(try XCTUnwrap(viewModel.pendingActions.first))

        let last = try XCTUnwrap(viewModel.activeConversation?.messages.last)
        XCTAssertEqual(last.content, Fixture.confirmationText)
        XCTAssertEqual(last.origin, .proactive)
        XCTAssertEqual(MuseMessageCaption.text(for: last), "Standing task")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSecondConfirmConflictSaysAlreadySetUp() async throws {
        let api = StubAPI()
        let viewModel = try await streamedProposal(api)
        api.confirmResult = .failure(PersistentAssistantHTTPClient.Error.conflict("Action is no longer pending."))
        let action = try XCTUnwrap(viewModel.pendingActions.first)

        await viewModel.confirm(action)

        XCTAssertEqual(viewModel.standingTaskOutcomes[action.id], .alreadySetUp)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.pendingActions.map(\.id), ["a1"], "the card stays to say so")
        await viewModel.confirm(action)
        XCTAssertEqual(api.confirmed, ["a1"], "an answered card does not confirm again")
    }

    func testConflictOnAnOrdinaryActionIsAnError() async throws {
        let api = StubAPI()
        api.actions = [Fixture.action(toolName: "add_expense")]
        api.confirmResult = .failure(PersistentAssistantHTTPClient.Error.conflict("Action is no longer pending."))
        let viewModel = PersistentAssistantViewModel(service: api, sleep: { _ in })
        await viewModel.load()

        await viewModel.confirm(try XCTUnwrap(viewModel.pendingActions.first))

        XCTAssertEqual(viewModel.errorMessage, "Action is no longer pending.")
        XCTAssertTrue(viewModel.standingTaskOutcomes.isEmpty)
    }

    func testNotNowCancels() async throws {
        let api = StubAPI()
        let viewModel = try await streamedProposal(api)

        await viewModel.cancel(try XCTUnwrap(viewModel.pendingActions.first))

        XCTAssertEqual(api.cancelled, ["a1"])
        XCTAssertTrue(viewModel.pendingActions.isEmpty)
        XCTAssertTrue(viewModel.watchProposals.isEmpty)
    }
}
