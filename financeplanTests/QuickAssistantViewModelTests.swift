import Foundation
import UIKit
import StockPlanShared
import XCTest
@testable import financeplan

/// Scripted service: each stream call plays the next script.
private final class ScriptedAssistantService: PersistentAssistantServicing, @unchecked Sendable {
    struct Unused: Error {}

    var scripts: [[PersistentAssistantStreamEvent]]
    var createResults: [Result<String, Error>]
    var confirmResult: Result<String, Error> = .success("Deleted.")
    private(set) var createdBindings: [Bool?] = []
    private(set) var streamedConversations: [String] = []
    private(set) var streamedContent: [String] = []
    private(set) var contexts: [AssistantTurnContext?] = []
    private(set) var streamedImages: [[ScreenshotUploadImage]] = []
    private(set) var streamedAttachments: [[AssistantAttachment]] = []
    private(set) var preferencesCalls = 0
    /// The next stream yields nothing and ends only when its consumer cancels.
    var hangs = false
    var preferencesResult: Result<AIAssistantPreferencesResponse, Error> = .failure(Unused())
    private(set) var confirmed: [String] = []
    private(set) var cancelled: [String] = []

    init(scripts: [[PersistentAssistantStreamEvent]] = [], createResults: [Result<String, Error>] = [.success("new")]) {
        self.scripts = scripts
        self.createResults = createResults
    }

    func createConversation(title: String?, bindMessaging: Bool?) async throws -> AIConversationResponse {
        createdBindings.append(bindMessaging)
        let id = try createResults.removeFirst().get()
        return AIConversationResponse(id: id, title: title ?? "", messages: [], createdAt: "2026-11-04T00:00:00Z", updatedAt: "2026-11-04T00:00:00Z")
    }

    func streamTurn(conversationID: String, content: String, attachments: [AssistantAttachment], context: AssistantTurnContext?) -> AsyncThrowingStream<PersistentAssistantStreamEvent, Error> {
        streamedConversations.append(conversationID)
        streamedContent.append(content)
        contexts.append(context)
        streamedAttachments.append(attachments)
        streamedImages.append(attachments.compactMap { if case let .image(image) = $0 { image } else { nil } })
        if hangs {
            return AsyncThrowingStream { _ in }
        }
        let events = scripts.isEmpty ? [] : scripts.removeFirst()
        return AsyncThrowingStream { continuation in
            for event in events { continuation.yield(event) }
            continuation.finish()
        }
    }

    func confirmAction(id: String) async throws -> AIConfirmedActionResponse {
        confirmed.append(id)
        let message = try confirmResult.get()
        return AIConfirmedActionResponse(actionId: id, status: .completed, resultId: nil, message: message)
    }

    func portfolioLists() async throws -> [PortfolioListDTOResponse] { [] }
    func confirmTrades(id _: String, portfolioListID _: String, trades _: [AIReviewedTrade]) async throws -> AIConfirmedActionResponse { throw Unused() }
    func confirmHoldings(id _: String, body _: AIReviewedHoldings) async throws -> AIConfirmedActionResponse { throw Unused() }
    func cancelAction(id: String) async throws { cancelled.append(id) }

    func conversation(id _: String) async throws -> AIConversationResponse { throw Unused() }
    func conversations() async throws -> [AIConversationSummaryResponse] { [] }
    func deleteConversation(id _: String) async throws { throw Unused() }
    func turn(conversationID _: String, content _: String) async throws -> AIAssistantTurnResponse { throw Unused() }
    func preferences() async throws -> AIAssistantPreferencesResponse {
        preferencesCalls += 1
        return try preferencesResult.get()
    }
    func updatePreferences(_: AIAssistantPreferencesResponse) async throws -> AIAssistantPreferencesResponse { throw Unused() }
    func tips() async throws -> [AITipResponse] { [] }
    func dismissTip(id _: String) async throws { throw Unused() }
    func usage() async throws -> AIAssistantUsageResponse { throw Unused() }
    func pendingActions() async throws -> [AIPendingActionResponse] { [] }
    func memos(bookmarked _: Bool?, conversationID _: String?) async throws -> [PositionMemoListItem] { [] }
    func memo(id _: String) async throws -> PositionMemoDetail { throw Unused() }
    func bookmarkMemo(id _: String, bookmarked _: Bool) async throws -> PositionMemoCard { throw Unused() }
    func deleteMemo(id _: String) async throws { throw Unused() }
}

private func turn(content: String = "You spent €120.", conversationID: String = "new", action: String? = nil) -> AIAssistantTurnResponse {
    let pending = action.map {
        #""pendingAction":{"id":"a1","conversationId":"\#(conversationID)","toolName":"\#($0)","summary":"Delete lunch","arguments":"{}","status":"pending","expiresAt":"2026-11-04T01:00:00Z","createdAt":"2026-11-04T00:00:00Z"},"#
    } ?? ""
    let json = #"""
    {"kind":"message","conversationId":"\#(conversationID)",\#(pending)"message":{"id":"m1","conversationId":"\#(conversationID)","role":"assistant","content":"\#(content)","createdAt":"2026-11-04T00:00:00Z"}}
    """#
    return try! JSONDecoder().decode(AIAssistantTurnResponse.self, from: Data(json.utf8))
}

@MainActor
final class QuickAssistantViewModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "QuickAssistantViewModelTests"

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    private func makeViewModel(_ service: ScriptedAssistantService, user: String = "u1") -> QuickAssistantViewModel {
        QuickAssistantViewModel(
            service: service,
            conversations: QuickAssistantConversationStore(defaults: defaults, flags: flagCache),
            currentUserID: { user }
        )
    }

    private var flagCache = AttachmentFlagCache()

    private static func prefs(images: Bool?, documents: Bool?) -> AIAssistantPreferencesResponse {
        AIAssistantPreferencesResponse(proactiveTipsEnabled: false, pushEnabled: false, timezone: "UTC", imagesEnabled: images, documentsEnabled: documents)
    }

    private func jpeg() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
    }

    private func csvURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-fills.csv")
        try Data("a,b\n1,2\n".utf8).write(to: url)
        return url
    }

    private func ask(_ viewModel: QuickAssistantViewModel, _ text: String = "How much did I spend?", scope: AIViewScope? = .home, inputMode: AssistantTurnContext.InputMode = .text) async {
        viewModel.draft = text
        await viewModel.send(scope: scope, inputMode: inputMode)
    }

    func testFlagsFollowPreferences() async {
        let service = ScriptedAssistantService()
        service.preferencesResult = .success(Self.prefs(images: true, documents: nil))
        let viewModel = makeViewModel(service)
        await viewModel.loadAttachmentFlags()
        XCTAssertTrue(viewModel.imagesEnabled)
        XCTAssertFalse(viewModel.documentsEnabled)
    }

    func testFailedPreferencesLeaveBothFlagsOffAndTextStillSends() async {
        let service = ScriptedAssistantService(scripts: [[.turn(turn()), .done]])
        let viewModel = makeViewModel(service)
        await viewModel.loadAttachmentFlags()
        XCTAssertFalse(viewModel.imagesEnabled)
        XCTAssertFalse(viewModel.documentsEnabled)
        await ask(viewModel)
        XCTAssertEqual(viewModel.phase, .answered)
    }

    func testQuickQFlagsLoadedOncePerSession() async {
        let service = ScriptedAssistantService()
        service.preferencesResult = .success(Self.prefs(images: true, documents: true))
        let first = makeViewModel(service)
        await first.loadAttachmentFlags()
        // A later presentation builds a fresh view model over the same store.
        let second = makeViewModel(service)
        await second.loadAttachmentFlags()
        XCTAssertEqual(service.preferencesCalls, 1)
        XCTAssertTrue(second.imagesEnabled)
        XCTAssertTrue(second.documentsEnabled)
    }

    func testQuickQSendsAttachments() async throws {
        let service = ScriptedAssistantService(scripts: [[.turn(turn()), .done]])
        let viewModel = makeViewModel(service)
        let image = jpeg()
        await viewModel.addAttachments([{ image }])
        await viewModel.addFiles([try csvURL()])
        XCTAssertEqual(viewModel.attachments.count, 2)
        await ask(viewModel)
        XCTAssertEqual(service.streamedAttachments.first?.count, 2)
        XCTAssertTrue(viewModel.attachments.isEmpty)
        XCTAssertEqual(viewModel.question, "How much did I spend? [file attached]")
    }

    func testQuickQAttachmentOnlyTurnSends() async {
        let service = ScriptedAssistantService(scripts: [[.turn(turn()), .done]])
        let viewModel = makeViewModel(service)
        let image = jpeg()
        await viewModel.addAttachments([{ image }])
        viewModel.draft = ""
        await viewModel.send(scope: .home)
        XCTAssertEqual(service.streamedAttachments.first?.count, 1)
        XCTAssertEqual(viewModel.question, "What's in this image? [image attached]")
    }

    func testQuickQVoiceSendKeepsAttachments() async {
        let service = ScriptedAssistantService(scripts: [[.turn(turn()), .done]])
        let viewModel = makeViewModel(service)
        let image = jpeg()
        await viewModel.addAttachments([{ image }])
        await ask(viewModel, "What is this?", inputMode: .voice)
        XCTAssertEqual(service.streamedAttachments.first?.count, 1)
        XCTAssertEqual(service.contexts.first??.inputMode, .voice)
    }

    func testQuickQFailedSendRestoresAttachments() async {
        let service = ScriptedAssistantService(scripts: [[.error("boom")]])
        let viewModel = makeViewModel(service)
        let image = jpeg()
        await viewModel.addAttachments([{ image }])
        await ask(viewModel)
        XCTAssertEqual(viewModel.attachments.count, 1)
        XCTAssertEqual(viewModel.draft, "How much did I spend?")
    }

    func testQuickQCancelledSendThenResetLeavesNoAttachments() async {
        let service = ScriptedAssistantService()
        service.hangs = true
        let viewModel = makeViewModel(service)
        let image = jpeg()
        await viewModel.addAttachments([{ image }])
        viewModel.draft = "What is this?"
        let task = Task { await viewModel.send(scope: .home) }
        while service.streamedAttachments.isEmpty { await Task.yield() }
        task.cancel()
        viewModel.reset()
        await task.value
        XCTAssertTrue(viewModel.attachments.isEmpty)
    }

    func testQuickQLimitNoticeIsNotAboutImagesOnly() async {
        let viewModel = makeViewModel(ScriptedAssistantService())
        let image = jpeg()
        await viewModel.addAttachments(Array(repeating: { image }, count: 4))
        XCTAssertEqual(viewModel.attachmentNotice, AttachmentCheckError.tooMany.errorDescription)
    }

    func testQuickQRemoveAttachment() async throws {
        let viewModel = makeViewModel(ScriptedAssistantService())
        await viewModel.addFiles([try csvURL()])
        let id = try XCTUnwrap(viewModel.attachments.first?.id)
        viewModel.removeAttachment(id: id)
        XCTAssertTrue(viewModel.attachments.isEmpty)
    }

    func testQuickQHandsOffHoldingsCard() async {
        let service = ScriptedAssistantService(scripts: [[.turn(turn(action: AssistantHoldingsReview.toolName)), .done]])
        let viewModel = makeViewModel(service)
        await ask(viewModel)
        XCTAssertTrue(viewModel.needsFullQ)
        XCTAssertNil(viewModel.pendingAction)
    }

    func testAnswerShowsTheLatestExchange() async {
        let service = ScriptedAssistantService(scripts: [[.started, .tool("Reading your expenses…"), .turn(turn()), .done]])
        let viewModel = makeViewModel(service)
        await ask(viewModel)
        XCTAssertEqual(viewModel.phase, .answered)
        XCTAssertEqual(viewModel.question, "How much did I spend?")
        XCTAssertEqual(viewModel.answer, "You spent €120.")
        XCTAssertEqual(viewModel.draft, "")
    }

    func testFirstQuestionCreatesAConversationThatLeavesTelegramAlone() async {
        let service = ScriptedAssistantService(scripts: [[.turn(turn()), .done]])
        await ask(makeViewModel(service))
        XCTAssertEqual(service.createdBindings, [false])
        XCTAssertEqual(service.streamedConversations, ["new"])
    }

    func testLaterQuestionReusesTheStoredConversation() async {
        let service = ScriptedAssistantService(scripts: [[.turn(turn()), .done], [.turn(turn()), .done]])
        let viewModel = makeViewModel(service)
        await ask(viewModel)
        await ask(viewModel)
        // A fresh card after relaunch finds the same one.
        service.scripts = [[.turn(turn()), .done]]
        await ask(makeViewModel(service))
        XCTAssertEqual(service.createdBindings.count, 1)
        XCTAssertEqual(service.streamedConversations, ["new", "new", "new"])
    }

    func testConversationIsKeptPerUser() async {
        let service = ScriptedAssistantService(
            scripts: [[.turn(turn()), .done], [.turn(turn()), .done]],
            createResults: [.success("first"), .success("second")]
        )
        await ask(makeViewModel(service, user: "u1"))
        await ask(makeViewModel(service, user: "u2"))
        XCTAssertEqual(service.streamedConversations, ["first", "second"])
    }

    func testExpiredConversationIsRecreatedAndTheQuestionResent() async {
        let service = ScriptedAssistantService(
            scripts: [
                [.turn(turn()), .done],
                [.started, .error("This conversation no longer exists.", code: "conversation_not_found"), .done],
                [.turn(turn(conversationID: "again")), .done],
            ],
            createResults: [.success("old"), .success("again")]
        )
        let viewModel = makeViewModel(service)
        await ask(viewModel, "one")
        await ask(viewModel, "two")
        XCTAssertEqual(service.streamedConversations, ["old", "old", "again"])
        XCTAssertEqual(service.streamedContent, ["one", "two", "two"])
        XCTAssertEqual(service.streamedImages, [[], [], []], "Quick Q attaches nothing")
        XCTAssertEqual(viewModel.phase, .answered)
    }

    func testExpiredConversationRetriesOnlyOnce() async {
        let gone = PersistentAssistantStreamEvent.error("Gone", code: "conversation_not_found")
        let service = ScriptedAssistantService(scripts: [[gone], [gone]], createResults: [.success("a"), .success("b")])
        let viewModel = makeViewModel(service)
        await ask(viewModel, "one")
        XCTAssertEqual(service.streamedContent.count, 2)
        XCTAssertEqual(viewModel.phase, .failed("Gone"))
        XCTAssertEqual(viewModel.draft, "one")
    }

    func testTurnSendsTheScreenAndInputMode() async {
        let service = ScriptedAssistantService(scripts: [[.turn(turn()), .done]])
        await ask(makeViewModel(service), scope: .tax, inputMode: .voice)
        let context = service.contexts.first ?? nil
        XCTAssertEqual(context?.screen, "tax")
        XCTAssertEqual(context?.inputMode, .voice)
        XCTAssertEqual(context?.timeZone, TimeZone.current.identifier)
    }

    func testQuotaOpensThePaywallAndKeepsTheQuestion() async {
        let service = ScriptedAssistantService(scripts: [[.started, .error("Out of turns", code: "quota_exhausted"), .done]])
        let viewModel = makeViewModel(service)
        await ask(viewModel, "one")
        XCTAssertTrue(viewModel.isPaywallRequested)
        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertEqual(viewModel.draft, "one")
        XCTAssertNil(viewModel.question)
    }

    func testUpgradeCodeOpensThePaywall() async {
        let service = ScriptedAssistantService(scripts: [[.error("Pro only", code: "upgrade_required")]])
        let viewModel = makeViewModel(service)
        await ask(viewModel)
        XCTAssertTrue(viewModel.isPaywallRequested)
    }

    func testConsentCodeAsksForConsentAndKeepsTheQuestion() async {
        let posted = expectation(forNotification: .aiConsentRequired, object: nil)
        let service = ScriptedAssistantService(scripts: [[.started, .error("Allow first", code: "ai_consent_required"), .done]])
        let viewModel = makeViewModel(service)
        await ask(viewModel, "one")
        await fulfillment(of: [posted], timeout: 1)
        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertEqual(viewModel.draft, "one")
        XCTAssertFalse(viewModel.isPaywallRequested)
    }

    func testOtherFailureShowsTheMessageAndKeepsTheQuestion() async {
        let service = ScriptedAssistantService(scripts: [[.started, .error("Busy"), .done]])
        let viewModel = makeViewModel(service)
        await ask(viewModel, "one")
        XCTAssertEqual(viewModel.phase, .failed("Busy"))
        XCTAssertEqual(viewModel.draft, "one")
        // It is back in the composer, so the card does not show it twice.
        XCTAssertNil(viewModel.question)
    }

    func testStreamWithNoTurnIsAFailure() async {
        let service = ScriptedAssistantService(scripts: [[.started, .done]])
        let viewModel = makeViewModel(service)
        await ask(viewModel)
        guard case .failed = viewModel.phase else { return XCTFail("Expected failure, got \(viewModel.phase)") }
    }

    func testBlankQuestionSendsNothing() async {
        let service = ScriptedAssistantService()
        await ask(makeViewModel(service), "   \n ")
        XCTAssertTrue(service.streamedContent.isEmpty)
        XCTAssertTrue(service.createdBindings.isEmpty)
    }

    func testChangeWaitsForATapAndConfirmShowsTheResult() async {
        let service = ScriptedAssistantService(scripts: [[.turn(turn(action: "delete_expense")), .done]])
        let viewModel = makeViewModel(service)
        await ask(viewModel, "Delete my last expense", inputMode: .voice)
        XCTAssertEqual(viewModel.pendingAction?.id, "a1")
        XCTAssertTrue(service.confirmed.isEmpty)
        await viewModel.confirmPendingAction()
        XCTAssertEqual(service.confirmed, ["a1"])
        XCTAssertNil(viewModel.pendingAction)
        XCTAssertEqual(viewModel.answer, "Deleted.")
    }

    func testCancelDropsTheChange() async {
        let service = ScriptedAssistantService(scripts: [[.turn(turn(action: "delete_expense")), .done]])
        let viewModel = makeViewModel(service)
        await ask(viewModel)
        await viewModel.cancelPendingAction()
        XCTAssertEqual(service.cancelled, ["a1"])
        XCTAssertTrue(service.confirmed.isEmpty)
        XCTAssertNil(viewModel.pendingAction)
        // The turn's text asks for confirmation, which no longer applies.
        XCTAssertEqual(viewModel.answer, String(localized: "Nothing was changed."))
    }

    func testFailedConfirmKeepsTheCardAndSaysSo() async {
        let service = ScriptedAssistantService(scripts: [[.turn(turn(action: "delete_expense")), .done]])
        service.confirmResult = .failure(ScriptedAssistantService.Unused())
        let viewModel = makeViewModel(service)
        await ask(viewModel)
        await viewModel.confirmPendingAction()
        XCTAssertEqual(viewModel.pendingAction?.id, "a1")
        XCTAssertNotNil(viewModel.actionError)
    }

    func testWatchProposalIsLeftForFullQ() async {
        let service = ScriptedAssistantService(scripts: [[.turn(turn(action: MuseStandingTask.toolName)), .done]])
        let viewModel = makeViewModel(service)
        await ask(viewModel)
        XCTAssertNil(viewModel.pendingAction)
        XCTAssertTrue(viewModel.needsFullQ)
    }

    /// A trades card saves only rows the user reviewed, and the backend refuses
    /// a confirm with no rows (422), so Quick Q never offers one.
    func testTradesCardIsLeftForFullQ() async {
        let service = ScriptedAssistantService(scripts: [[.turn(turn(action: AssistantTradesReview.toolName)), .done]])
        let viewModel = makeViewModel(service)
        await ask(viewModel)
        XCTAssertNil(viewModel.pendingAction)
        XCTAssertTrue(viewModel.needsFullQ)
        XCTAssertEqual(viewModel.phase, .answered)
    }

    func testResetClearsTheCardButKeepsTheConversation() async {
        let service = ScriptedAssistantService(scripts: [[.turn(turn()), .done]])
        let viewModel = makeViewModel(service)
        await ask(viewModel)
        viewModel.reset()
        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertNil(viewModel.question)
        XCTAssertNil(viewModel.answer)
        XCTAssertEqual(viewModel.conversationID, "new")
    }
}

// `async` on purpose: see the toolchain crash noted in PilotsStoreTests.swift.
@MainActor
final class QuickAssistantCoordinatorTests: XCTestCase {
    func testPresentsWhenAIIsAllowed() async {
        var consentPrompts = 0
        let coordinator = QuickAssistantCoordinator(allowsAI: { true }, presentConsent: { consentPrompts += 1 })
        coordinator.present(scope: .expenses)
        XCTAssertTrue(coordinator.isPresented)
        XCTAssertEqual(coordinator.scope, .expenses)
        XCTAssertEqual(consentPrompts, 0)
    }

    func testAsksForConsentFirst() async {
        var consentPrompts = 0
        let coordinator = QuickAssistantCoordinator(allowsAI: { false }, presentConsent: { consentPrompts += 1 })
        coordinator.present(scope: .home)
        XCTAssertFalse(coordinator.isPresented)
        XCTAssertEqual(consentPrompts, 1)
    }

    func testFloatingButtonCanOpenWithoutAScreen() async {
        let coordinator = QuickAssistantCoordinator(allowsAI: { true }, presentConsent: {})
        coordinator.present(scope: nil)
        XCTAssertTrue(coordinator.isPresented)
        XCTAssertNil(coordinator.scope)
    }

    func testFloatingButtonHidesWhileAnyScreenAsksAndReturnsAfterTheLast() async {
        let coordinator = QuickAssistantCoordinator(allowsAI: { true }, presentConsent: {})
        XCTAssertTrue(coordinator.showsFloatingButton)
        coordinator.setFloatingButtonHidden(true)
        coordinator.setFloatingButtonHidden(true)
        coordinator.setFloatingButtonHidden(false)
        XCTAssertFalse(coordinator.showsFloatingButton)
        coordinator.setFloatingButtonHidden(false)
        XCTAssertTrue(coordinator.showsFloatingButton)
    }

    func testFloatingButtonHidesWhileTheCardIsUp() async {
        let coordinator = QuickAssistantCoordinator(allowsAI: { true }, presentConsent: {})
        coordinator.present(scope: .home)
        XCTAssertFalse(coordinator.showsFloatingButton)
        coordinator.dismiss()
        XCTAssertTrue(coordinator.showsFloatingButton)
    }

    func testAnExtraUnhideCannotLeaveTheButtonStuck() async {
        let coordinator = QuickAssistantCoordinator(allowsAI: { true }, presentConsent: {})
        coordinator.setFloatingButtonHidden(false)
        coordinator.setFloatingButtonHidden(true)
        XCTAssertFalse(coordinator.showsFloatingButton)
    }

    func testDismissCloses() async {
        let coordinator = QuickAssistantCoordinator(allowsAI: { true }, presentConsent: {})
        coordinator.present(scope: .home)
        coordinator.dismiss()
        XCTAssertFalse(coordinator.isPresented)
    }
}

final class QuickAssistantTapGateTests: XCTestCase {
    func testPlainTapPasses() {
        var gate = QuickAssistantTapGate()
        XCTAssertTrue(gate.allowsTap(at: Date(timeIntervalSince1970: 100)))
    }

    func testReleaseAfterLongPressIsSwallowed() {
        var gate = QuickAssistantTapGate()
        gate.noteLongPress(at: Date(timeIntervalSince1970: 100))
        XCTAssertFalse(gate.allowsTap(at: Date(timeIntervalSince1970: 101)))
    }

    func testLaterTapPassesEvenWhenNoReleaseFired() {
        var gate = QuickAssistantTapGate()
        gate.noteLongPress(at: Date(timeIntervalSince1970: 100))
        XCTAssertTrue(gate.allowsTap(at: Date(timeIntervalSince1970: 110)))
    }

    func testOnlyOneReleaseIsSwallowed() {
        var gate = QuickAssistantTapGate()
        gate.noteLongPress(at: Date(timeIntervalSince1970: 100))
        XCTAssertFalse(gate.allowsTap(at: Date(timeIntervalSince1970: 101)))
        XCTAssertTrue(gate.allowsTap(at: Date(timeIntervalSince1970: 101.5)))
    }
}

@MainActor
final class PersistentAssistantRoutingTests: XCTestCase {
    private func sending(_ events: [PersistentAssistantStreamEvent]) async throws -> (PersistentAssistantViewModel, ScriptedAssistantService) {
        let service = ScriptedAssistantService(scripts: [events])
        let viewModel = PersistentAssistantViewModel(service: FullQService(base: service), sleep: { _ in })
        try await viewModel.selectConversation(id: "c1")
        viewModel.draft = "Hi"
        await viewModel.send()
        return (viewModel, service)
    }

    func testQuotaOpensThePaywallInsteadOfAnAlert() async throws {
        let (viewModel, _) = try await sending([.started, .error("Out of turns", code: "quota_exhausted"), .done])
        XCTAssertTrue(viewModel.isPaywallRequested)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testConsentCodePromptsInsteadOfAnAlert() async throws {
        let posted = expectation(forNotification: .aiConsentRequired, object: nil)
        let (viewModel, _) = try await sending([.started, .error("Allow first", code: "ai_consent_required"), .done])
        await fulfillment(of: [posted], timeout: 1)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isPaywallRequested)
    }

    func testOtherCodesStillShowTheMessage() async throws {
        let (viewModel, _) = try await sending([.started, .error("Busy"), .done])
        XCTAssertEqual(viewModel.errorMessage, "Busy")
        XCTAssertFalse(viewModel.isPaywallRequested)
    }

    func testFullQSendsContextWithoutAScreen() async throws {
        let (_, service) = try await sending([.started, .done])
        let context = service.contexts.first ?? nil
        XCTAssertNotNil(context)
        XCTAssertNil(context?.screen)
        XCTAssertEqual(context?.inputMode, .text)
    }
}

/// Answers the conversation fetch full Q needs and forwards the rest.
private struct FullQService: PersistentAssistantServicing {
    let base: ScriptedAssistantService

    func conversation(id: String) async throws -> AIConversationResponse {
        AIConversationResponse(id: id, title: "T", messages: [], createdAt: "2026-11-04T00:00:00Z", updatedAt: "2026-11-04T00:00:00Z")
    }
    func streamTurn(conversationID: String, content: String, attachments: [AssistantAttachment], context: AssistantTurnContext?) -> AsyncThrowingStream<PersistentAssistantStreamEvent, Error> {
        base.streamTurn(conversationID: conversationID, content: content, attachments: attachments, context: context)
    }
    func usage() async throws -> AIAssistantUsageResponse {
        AIAssistantUsageResponse(month: "2026-11", used: 1, limit: nil, remaining: nil, isPro: true)
    }
    func createConversation(title: String?, bindMessaging: Bool?) async throws -> AIConversationResponse { try await base.createConversation(title: title, bindMessaging: bindMessaging) }
    func conversations() async throws -> [AIConversationSummaryResponse] { [] }
    func deleteConversation(id: String) async throws { try await base.deleteConversation(id: id) }
    func turn(conversationID: String, content: String) async throws -> AIAssistantTurnResponse { try await base.turn(conversationID: conversationID, content: content) }
    func preferences() async throws -> AIAssistantPreferencesResponse { try await base.preferences() }
    func updatePreferences(_ payload: AIAssistantPreferencesResponse) async throws -> AIAssistantPreferencesResponse { try await base.updatePreferences(payload) }
    func tips() async throws -> [AITipResponse] { [] }
    func dismissTip(id: String) async throws { try await base.dismissTip(id: id) }
    func pendingActions() async throws -> [AIPendingActionResponse] { [] }
    func confirmAction(id: String) async throws -> AIConfirmedActionResponse { try await base.confirmAction(id: id) }
    func portfolioLists() async throws -> [PortfolioListDTOResponse] { [] }
    func confirmTrades(id _: String, portfolioListID _: String, trades _: [AIReviewedTrade]) async throws -> AIConfirmedActionResponse { throw ScriptedAssistantService.Unused() }
    func confirmHoldings(id _: String, body _: AIReviewedHoldings) async throws -> AIConfirmedActionResponse { throw ScriptedAssistantService.Unused() }
    func cancelAction(id: String) async throws { try await base.cancelAction(id: id) }
    func memos(bookmarked: Bool?, conversationID: String?) async throws -> [PositionMemoListItem] { [] }
    func memo(id: String) async throws -> PositionMemoDetail { try await base.memo(id: id) }
    func bookmarkMemo(id: String, bookmarked: Bool) async throws -> PositionMemoCard { try await base.bookmarkMemo(id: id, bookmarked: bookmarked) }
    func deleteMemo(id: String) async throws { try await base.deleteMemo(id: id) }
}
