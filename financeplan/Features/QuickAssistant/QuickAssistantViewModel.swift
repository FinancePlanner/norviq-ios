import Factory
import Foundation
import Observation
import StockPlanShared

/// One question and one answer at a time, over the Quick Q conversation.
///
/// Separate from `PersistentAssistantViewModel` because that one's `load()`
/// needs five requests to succeed before anything can be asked.
@Observable @MainActor
final class QuickAssistantViewModel {
    enum Phase: Equatable {
        case idle
        case thinking(activity: String?)
        case answered
        case failed(String)
    }

    private(set) var phase = Phase.idle
    private(set) var question: String?
    private(set) var answer: String?
    private(set) var pendingAction: AIPendingActionResponse?
    private(set) var isActing = false
    private(set) var actionError: String?
    /// The turn produced something only full Q can show: a memo, a watch
    /// proposal, or a trades card, whose confirm needs the reviewed rows.
    private(set) var needsFullQ = false
    private(set) var conversationID: String?
    var isPaywallRequested = false
    var draft = ""

    private let service: any PersistentAssistantServicing
    private let conversations: QuickAssistantConversationStore
    private let currentUserID: @Sendable () async -> String

    init(
        service: any PersistentAssistantServicing,
        conversations: QuickAssistantConversationStore = QuickAssistantConversationStore(),
        currentUserID: @escaping @Sendable () async -> String
    ) {
        self.service = service
        self.conversations = conversations
        self.currentUserID = currentUserID
    }

    convenience init() {
        self.init(
            service: Container.shared.persistentAssistantService(),
            currentUserID: { await Container.shared.authSessionStore().currentUserID }
        )
    }

    var isThinking: Bool {
        if case .thinking = phase { return true }
        return false
    }

    func send(scope: AIViewScope?, inputMode: AssistantTurnContext.InputMode = .text) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        clearExchange()
        draft = ""
        question = text
        phase = .thinking(activity: nil)
        let context = AssistantTurnContext.current(screen: scope, inputMode: inputMode)
        do {
            try await runTurn(text, context: context, mayRecreate: true)
            phase = .answered
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            handle(error, question: text)
        }
    }

    func confirmPendingAction() async {
        guard let action = pendingAction, !isActing else { return }
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            let result = try await service.confirmAction(id: action.id)
            pendingAction = nil
            answer = result.message
        } catch {
            actionError = readable(error, fallback: "The action could not be applied.")
        }
    }

    func cancelPendingAction() async {
        guard let action = pendingAction, !isActing else { return }
        isActing = true
        actionError = nil
        defer { isActing = false }
        do {
            try await service.cancelAction(id: action.id)
            pendingAction = nil
            answer = String(localized: "Nothing was changed.")
        } catch {
            actionError = readable(error, fallback: "The action could not be cancelled.")
        }
    }

    /// Empties the card for its next opening. The conversation carries on.
    func reset() {
        clearExchange()
        draft = ""
        phase = .idle
    }

    private func clearExchange() {
        question = nil
        answer = nil
        pendingAction = nil
        actionError = nil
        needsFullQ = false
    }

    private func runTurn(_ text: String, context: AssistantTurnContext, mayRecreate: Bool) async throws {
        let id = try await resolveConversation()
        do {
            var receivedTurn = false
            for try await event in service.streamTurn(conversationID: id, content: text, context: context) {
                switch event {
                case .started:
                    break
                case let .tool(label):
                    phase = .thinking(activity: label)
                case let .turn(turn):
                    receivedTurn = true
                    apply(turn)
                case let .error(message, code):
                    throw AssistantTurnFailure(message: message, code: code)
                case .done:
                    break
                }
            }
            guard receivedTurn else {
                throw AssistantTurnFailure(message: String(localized: "The assistant returned no response."))
            }
        } catch where mayRecreate && AssistantTurnRecovery(error) == .recreateConversation {
            // Conversations expire after 30 days without a message.
            await forgetConversation()
            try await runTurn(text, context: context, mayRecreate: false)
        }
    }

    private func apply(_ turn: AIAssistantTurnResponse) {
        answer = turn.message.content
        if turn.memo != nil { needsFullQ = true }
        guard let action = turn.pendingAction else { return }
        if action.toolName == MuseStandingTask.toolName || action.toolName == AssistantTradesReview.toolName {
            needsFullQ = true
        } else {
            pendingAction = action
        }
    }

    private func resolveConversation() async throws -> String {
        if let conversationID { return conversationID }
        let userID = await currentUserID()
        if let stored = conversations.conversationID(forUser: userID) {
            conversationID = stored
            return stored
        }
        let created = try await service.createConversation(title: "Quick Q", bindMessaging: false)
        conversationID = created.id
        conversations.setConversationID(created.id, forUser: userID)
        return created.id
    }

    private func forgetConversation() async {
        conversationID = nil
        conversations.setConversationID(nil, forUser: await currentUserID())
    }

    private func handle(_ error: any Error, question text: String) {
        draft = text
        switch AssistantTurnRecovery(error) {
        case .askForConsent:
            AIConsentRequired.post()
            clearExchange()
            phase = .idle
        case .showPaywall:
            isPaywallRequested = true
            clearExchange()
            phase = .idle
        case .recreateConversation, .showMessage:
            question = nil
            phase = .failed(readable(error, fallback: "The assistant could not respond."))
        }
    }

    private func readable(_ error: any Error, fallback: String) -> String {
        let value = (error as? LocalizedError)?.errorDescription ?? ""
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: String.LocalizationValue(fallback)) : trimmed
    }
}
