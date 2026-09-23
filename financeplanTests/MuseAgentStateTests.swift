import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class MuseAgentStateTests: XCTestCase {
    private func run(_ events: [MuseAgentEvent], from start: MuseAgentState = .idle) -> MuseAgentState {
        events.reduce(start) { $0.reduce($1) }
    }

    func testStartsIdleAndReady() {
        XCTAssertEqual(MuseAgentState.idle.phase, .idle)
        XCTAssertEqual(MuseAgentState.idle.status, "Ready")
    }

    func testStartedIsWorkingAndThinking() {
        let state = run([.started])
        XCTAssertEqual(state.phase, .working)
        XCTAssertEqual(state.status, "is thinking")
    }

    func testToolShowsLabelAsVerbPhrase() {
        let state = run([.started, .tool("Adding expense…")])
        XCTAssertEqual(state.phase, .working)
        XCTAssertEqual(state.status, "is adding expense")
    }

    func testToolOutsideATurnIsIgnored() {
        XCTAssertEqual(run([.tool("Adding expense…")]), .idle)
        let celebrating = run([.started, .turn])
        XCTAssertEqual(celebrating.reduce(.tool("Adding expense…")), celebrating)
    }

    func testTurnCelebratesThenSettlesToReady() {
        let celebrating = run([.started, .tool("Reading your portfolio…"), .turn])
        XCTAssertEqual(celebrating.phase, .celebrating)
        let settled = celebrating.reduce(.celebrationEnded)
        XCTAssertEqual(settled.phase, .idle)
        XCTAssertEqual(settled.status, "Ready")
    }

    func testCelebrationEndsInListeningWhenComposerStillFocused() {
        let state = run([.composerFocus(true), .started, .turn, .celebrationEnded])
        XCTAssertEqual(state.phase, .listening)
        XCTAssertEqual(state.status, "is listening")
    }

    func testStaleCelebrationEndDoesNotInterruptANewTurn() {
        let state = run([.started, .turn, .started, .celebrationEnded])
        XCTAssertEqual(state.phase, .working)
        XCTAssertEqual(state.status, "is thinking")
    }

    func testFailureHitsASnagAndIsIdle() {
        let state = run([.started, .tool("Adding expense…"), .failed])
        XCTAssertEqual(state.phase, .idle)
        XCTAssertEqual(state.status, "hit a snag")
    }

    func testComposerFocusListensWhenIdleAndReleasesToReady() {
        let listening = run([.composerFocus(true)])
        XCTAssertEqual(listening.phase, .listening)
        XCTAssertEqual(listening.status, "is listening")
        let released = listening.reduce(.composerFocus(false))
        XCTAssertEqual(released.phase, .idle)
        XCTAssertEqual(released.status, "Ready")
    }

    func testComposerFocusClearsASnag() {
        let state = run([.started, .failed, .composerFocus(true)])
        XCTAssertEqual(state.status, "is listening")
    }

    func testComposerFocusNeverInterruptsWork() {
        let working = run([.started, .tool("Adding expense…")])
        let focused = working.reduce(.composerFocus(true))
        XCTAssertEqual(focused.phase, .working)
        XCTAssertEqual(focused.status, "is adding expense")
        let blurred = focused.reduce(.composerFocus(false))
        XCTAssertEqual(blurred.status, "is adding expense")
    }

    // MARK: - Tool label copy

    func testToolStatusStripsEllipsisAndLowercasesVerb() {
        XCTAssertEqual(MuseAgentState.toolStatus(for: "Looking up the market…"), "is looking up the market")
        XCTAssertEqual(MuseAgentState.toolStatus(for: "Recording the trade..."), "is recording the trade")
    }

    func testToolStatusKeepsAcronyms() {
        XCTAssertEqual(MuseAgentState.toolStatus(for: "ETF screen running"), "is ETF screen running")
    }

    func testEmptyToolLabelFallsBackToThinking() {
        XCTAssertEqual(MuseAgentState.toolStatus(for: "  …"), "is thinking")
    }

    func testLongToolLabelIsCappedAt32CharactersOnAWord() {
        let status = MuseAgentState.toolStatus(for: "Reconciling every brokerage statement you have uploaded…")
        let label = String(status.dropFirst("is ".count))
        XCTAssertLessThanOrEqual(label.count, 32)
        XCTAssertTrue(label.hasSuffix("…"))
        XCTAssertEqual(label, "reconciling every brokerage…")
    }

    func testEveryBackendLabelFitsWithoutTruncation() {
        // Labels from the backend's AIChatService.activityLabel.
        let labels = [
            "Building your spending report…", "Reading the economy snapshot…",
            "Deleting the position record…", "Reading your recorded trades…",
        ]
        for label in labels {
            XCTAssertFalse(MuseAgentState.toolStatus(for: label).hasSuffix("…"), label)
        }
    }
}

@MainActor
final class PersistentAssistantStreamDecodingTests: XCTestCase {
    func testToolFrameDecodesLabel() throws {
        let event = try AssistantStreamClient.decodePersistent(event: "tool", json: #"{"label":"Adding expense…"}"#)
        guard case let .tool(label) = event else { return XCTFail("expected tool, got \(String(describing: event))") }
        XCTAssertEqual(label, "Adding expense…")
    }

    func testToolFrameWithoutLabelIsIgnored() throws {
        XCTAssertNil(try AssistantStreamClient.decodePersistent(event: "tool", json: "{}"))
        XCTAssertNil(try AssistantStreamClient.decodePersistent(event: "tool", json: "not json"))
    }

    func testUnknownFramesAreIgnored() throws {
        XCTAssertNil(try AssistantStreamClient.decodePersistent(event: "token", json: #"{"delta":"Hi"}"#))
        XCTAssertNil(try AssistantStreamClient.decodePersistent(event: "message", json: "{}"))
    }

    func testKnownFramesStillDecode() throws {
        guard case .started = try AssistantStreamClient.decodePersistent(event: "started", json: "{}") else {
            return XCTFail("expected started")
        }
        guard case .done = try AssistantStreamClient.decodePersistent(event: "done", json: "{}") else {
            return XCTFail("expected done")
        }
        guard case let .error(message) = try AssistantStreamClient.decodePersistent(
            event: "error", json: #"{"message":"Nope"}"#
        ) else { return XCTFail("expected error") }
        XCTAssertEqual(message, "Nope")
    }

    func testMalformedTurnThrows() {
        XCTAssertThrowsError(try AssistantStreamClient.decodePersistent(event: "turn", json: "{}"))
    }
}

@MainActor
final class PersistentAssistantAgentStateTests: XCTestCase {
    private struct Unused: Error {}

    private struct StubService: PersistentAssistantServicing {
        let events: [PersistentAssistantStreamEvent]

        func conversation(id: String) async throws -> AIConversationResponse {
            AIConversationResponse(id: id, title: "Test", messages: [], createdAt: "2026-09-23T00:00:00Z", updatedAt: "2026-09-23T00:00:00Z")
        }
        func streamTurn(conversationID _: String, content _: String) -> AsyncThrowingStream<PersistentAssistantStreamEvent, Error> {
            AsyncThrowingStream { continuation in
                for event in events { continuation.yield(event) }
                continuation.finish()
            }
        }
        func conversations() async throws -> [AIConversationSummaryResponse] { [] }
        func createConversation(title _: String?) async throws -> AIConversationResponse { throw Unused() }
        func deleteConversation(id _: String) async throws { throw Unused() }
        func turn(conversationID _: String, content _: String) async throws -> AIAssistantTurnResponse { throw Unused() }
        func preferences() async throws -> AIAssistantPreferencesResponse { throw Unused() }
        func updatePreferences(_: AIAssistantPreferencesResponse) async throws -> AIAssistantPreferencesResponse { throw Unused() }
        func tips() async throws -> [AITipResponse] { [] }
        func dismissTip(id _: String) async throws { throw Unused() }
        func usage() async throws -> AIAssistantUsageResponse { throw Unused() }
        func pendingActions() async throws -> [AIPendingActionResponse] { [] }
        func confirmAction(id _: String) async throws -> AIConfirmedActionResponse { throw Unused() }
        func cancelAction(id _: String) async throws { throw Unused() }
        func memos(bookmarked _: Bool?, conversationID _: String?) async throws -> [PositionMemoListItem] { [] }
        func memo(id _: String) async throws -> PositionMemoDetail { throw Unused() }
        func bookmarkMemo(id _: String, bookmarked _: Bool) async throws -> PositionMemoCard { throw Unused() }
        func deleteMemo(id _: String) async throws { throw Unused() }
    }

    private func turn() -> AIAssistantTurnResponse {
        let json = #"""
        {"kind":"message","conversationId":"c1","message":{"id":"m1","conversationId":"c1","role":"assistant",
         "content":"Done.","createdAt":"2026-09-23T00:00:00Z"}}
        """#
        return try! JSONDecoder().decode(AIAssistantTurnResponse.self, from: Data(json.utf8))
    }

    private func sendingViewModel(
        _ events: [PersistentAssistantStreamEvent],
        sleep: @escaping @Sendable (Duration) async throws -> Void
    ) async throws -> PersistentAssistantViewModel {
        let viewModel = PersistentAssistantViewModel(service: StubService(events: events), sleep: sleep)
        try await viewModel.selectConversation(id: "c1")
        viewModel.draft = "How am I doing?"
        await viewModel.send()
        return viewModel
    }

    func testTurnCelebratesUntilTheTimerFires() async throws {
        let viewModel = try await sendingViewModel(
            [.started, .tool("Reading your portfolio…"), .turn(turn()), .done],
            sleep: { _ in try await Task.sleep(for: .seconds(60)) }
        )
        XCTAssertEqual(viewModel.agentState.phase, .celebrating)
    }

    func testCelebrationSettlesToReady() async throws {
        let viewModel = try await sendingViewModel([.started, .turn(turn()), .done], sleep: { _ in })
        for _ in 0..<10 where viewModel.agentState.phase == .celebrating { await Task.yield() }
        XCTAssertEqual(viewModel.agentState.phase, .idle)
        XCTAssertEqual(viewModel.agentState.status, "Ready")
    }

    func testStreamErrorHitsASnag() async throws {
        let viewModel = try await sendingViewModel(
            [.started, .tool("Adding expense…"), .error("Nope")],
            sleep: { _ in }
        )
        XCTAssertEqual(viewModel.agentState.phase, .idle)
        XCTAssertEqual(viewModel.agentState.status, "hit a snag")
    }
}
