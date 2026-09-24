import Factory
import Foundation
import Observation
import StockPlanShared

@Observable @MainActor
final class PersistentAssistantViewModel {
    private(set) var conversations: [AIConversationSummaryResponse] = []
    private(set) var activeConversation: AIConversationResponse?
    private(set) var tips: [AITipResponse] = []
    private(set) var usage: AIAssistantUsageResponse?
    private(set) var preferences: AIAssistantPreferencesResponse?
    private(set) var pendingActions: [AIPendingActionResponse] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var activityLabel: String?
    /// Drives the Muse header's avatar ring and status line.
    private(set) var agentState = MuseAgentState.idle
    private(set) var activeActionID: String?
    private(set) var errorMessage: String?
    /// Memo cards keyed by the assistant message that announced them.
    private(set) var memoCards: [String: PositionMemoCard] = [:]
    private(set) var memoBookmarkInFlight: Set<String> = []
    /// Watch proposals from streamed turns, keyed by pending-action id. After
    /// a reload they are gone and the card redraws from the action's arguments.
    private(set) var watchProposals: [String: AIWatchProposalResponse] = [:]
    /// Standing-task cards the user answered but that stay on screen.
    private(set) var standingTaskOutcomes: [String: MuseStandingTaskOutcome] = [:]
    var draft = ""

    var memoService: any PersistentAssistantServicing { service }

    private let service: any PersistentAssistantServicing
    private let sleep: @Sendable (Duration) async throws -> Void
    private var celebrationTask: Task<Void, Never>?

    init(
        service: any PersistentAssistantServicing,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.service = service
        self.sleep = sleep
    }
    convenience init() { self.init(service: Container.shared.persistentAssistantService()) }

    /// Applies an agent event. The celebration after a turn ends on its own
    /// after `MuseAgentState.celebrationDuration`.
    func apply(_ event: MuseAgentEvent) {
        agentState = agentState.reduce(event)
        guard agentState.phase == .celebrating else {
            celebrationTask?.cancel()
            celebrationTask = nil
            return
        }
        guard event == .turn else { return }
        celebrationTask?.cancel()
        celebrationTask = Task { [weak self, sleep] in
            do { try await sleep(MuseAgentState.celebrationDuration) } catch { return }
            self?.apply(.celebrationEnded)
        }
    }

    func composerFocusChanged(_ focused: Bool) { apply(.composerFocus(focused)) }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let conversationsRequest = service.conversations()
            async let tipsRequest = service.tips()
            async let usageRequest = service.usage()
            async let preferencesRequest = service.preferences()
            async let actionsRequest = service.pendingActions()
            let (loadedConversations, loadedTips, loadedUsage, loadedPreferences, loadedActions) = try await (
                conversationsRequest, tipsRequest, usageRequest, preferencesRequest, actionsRequest
            )
            conversations = loadedConversations
            tips = loadedTips
            usage = loadedUsage
            preferences = loadedPreferences
            pendingActions = loadedActions
            if let first = conversations.first {
                try await selectConversation(id: first.id)
            } else {
                try await createConversation()
            }
        } catch {
            errorMessage = readable(error, fallback: "The assistant could not be loaded.")
        }
    }

    func createConversation() async throws {
        let created = try await service.createConversation(title: "New conversation")
        memoCards = [:]
        activeConversation = created
        await refreshConversations()
    }

    func newConversation() async {
        do { try await createConversation() }
        catch { errorMessage = readable(error, fallback: "A conversation could not be created.") }
    }

    func selectConversation(id: String) async throws {
        let conversation = try await service.conversation(id: id)
        activeConversation = conversation
        await attachMemoCards(to: conversation)
    }

    /// The stored assistant message only says "Memo on X is ready.", so cards
    /// for an older conversation are matched back to those lines by symbol,
    /// oldest first.
    private func attachMemoCards(to conversation: AIConversationResponse) async {
        memoCards = [:]
        guard conversation.messages.contains(where: { PositionMemoAnnouncement.symbol(in: $0) != nil }),
              let memos = try? await service.memos(bookmarked: nil, conversationID: conversation.id),
              activeConversation?.id == conversation.id
        else { return }
        var remaining = memos.sorted { $0.createdAt < $1.createdAt }
        for message in conversation.messages {
            guard let symbol = PositionMemoAnnouncement.symbol(in: message),
                  let index = remaining.firstIndex(where: { $0.primarySymbol == symbol })
            else { continue }
            let item = remaining.remove(at: index)
            memoCards[message.id] = PositionMemoCard(
                id: item.id, symbol: item.primarySymbol, title: item.title,
                verdict: item.verdict, bookmarked: item.bookmarked
            )
        }
    }

    func toggleBookmark(messageID: String) async {
        guard let card = memoCards[messageID], !memoBookmarkInFlight.contains(card.id) else { return }
        memoBookmarkInFlight.insert(card.id)
        defer { memoBookmarkInFlight.remove(card.id) }
        do { memoCards[messageID] = try await service.bookmarkMemo(id: card.id, bookmarked: !card.bookmarked) }
        catch { errorMessage = readable(error, fallback: "The memo could not be saved.") }
    }

    /// Keeps a card in step with changes made on the reader screen.
    func memoChanged(id: String, bookmarked: Bool?) {
        guard let key = memoCards.first(where: { $0.value.id == id })?.key, let card = memoCards[key] else { return }
        if let bookmarked {
            memoCards[key] = PositionMemoCard(
                id: card.id, symbol: card.symbol, title: card.title, verdict: card.verdict, bookmarked: bookmarked
            )
        } else {
            memoCards[key] = nil
        }
    }

    func select(id: String) async {
        do { try await selectConversation(id: id) }
        catch { errorMessage = readable(error, fallback: "The conversation could not be opened.") }
    }

    func send() async {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, let conversation = activeConversation, !isSending else { return }
        draft = ""
        isSending = true
        errorMessage = nil
        let optimistic = AIMessageResponse(
            id: UUID().uuidString,
            conversationId: conversation.id,
            role: .user,
            content: content,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        activeConversation = replacingMessages(in: conversation, with: conversation.messages + [optimistic])

        let outgoingContent: String
        switch AssistantCommandParser.resolve(content) {
        case let .local(reply):
            let localReply = AIMessageResponse(
                id: UUID().uuidString,
                conversationId: conversation.id,
                role: .assistant,
                content: reply,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            if let current = activeConversation {
                activeConversation = replacingMessages(in: current, with: current.messages + [localReply])
            }
            isSending = false
            return
        case let .command(_, expandedPrompt):
            outgoingContent = expandedPrompt
        case let .plain(text):
            outgoingContent = text
        }

        defer {
            isSending = false
            activityLabel = nil
        }
        apply(.started)
        do {
            var receivedTurn = false
            for try await event in service.streamTurn(conversationID: conversation.id, content: outgoingContent) {
                switch event {
                case .started:
                    activityLabel = "Reviewing your finances…"
                    apply(.started)
                case let .tool(label):
                    activityLabel = label
                    apply(.tool(label))
                case let .turn(turn):
                    receivedTurn = true
                    apply(.turn)
                    if let current = activeConversation {
                        activeConversation = replacingMessages(in: current, with: current.messages + [turn.message])
                    }
                    if let memo = turn.memo { memoCards[turn.message.id] = memo }
                    if let action = turn.pendingAction {
                        pendingActions.insert(action, at: 0)
                        if let proposal = turn.watchProposal { watchProposals[action.id] = proposal }
                    }
                case let .error(message):
                    throw PersistentAssistantStreamFailure(message: message)
                case .done:
                    break
                }
            }
            guard receivedTurn else {
                throw PersistentAssistantStreamFailure(message: "The assistant returned no response.")
            }
            async let usageRequest = service.usage()
            async let conversationsRequest = service.conversations()
            usage = try await usageRequest
            conversations = try await conversationsRequest
        } catch {
            // A turn that arrived before a later failure (e.g. refreshing
            // usage) still counts; only a turn that never landed is a snag.
            if agentState.phase == .working { apply(.failed) }
            if let current = activeConversation {
                activeConversation = replacingMessages(in: current, with: current.messages.filter { $0.id != optimistic.id })
            }
            draft = content
            errorMessage = readable(error, fallback: "The assistant could not respond.")
        }
    }

    /// The standing task a pending action proposes, or nil for other actions.
    func standingTask(for action: AIPendingActionResponse) -> MuseStandingTask? {
        MuseStandingTask.from(action, proposal: watchProposals[action.id])
    }

    func confirm(_ action: AIPendingActionResponse) async {
        guard activeActionID == nil, standingTaskOutcomes[action.id] == nil else { return }
        activeActionID = action.id
        defer { activeActionID = nil }
        let isStandingTask = action.toolName == MuseStandingTask.toolName
        do {
            let result = try await service.confirmAction(id: action.id)
            removePendingAction(id: action.id)
            if isStandingTask {
                await showStandingTaskConfirmation(result.message, conversationID: action.conversationId)
            } else {
                errorMessage = result.message
            }
        } catch let error where isStandingTask && (error as? any HTTPClientError)?.statusCode == 409 {
            // Already confirmed (twice-tapped, or from another device). The
            // card says so instead of an error; the thread may now hold the
            // confirmation the first confirm posted.
            standingTaskOutcomes[action.id] = .alreadySetUp
            await refreshActiveConversation()
        } catch {
            errorMessage = readable(error, fallback: "The action could not be applied.")
        }
    }

    /// The server appends the "Standing task" message to the thread; refetch
    /// to show it with its real id. If the refetch fails or predates it, the
    /// confirm response's text is shown as that message locally.
    private func showStandingTaskConfirmation(_ text: String, conversationID: String?) async {
        guard let conversation = activeConversation,
              conversationID == nil || conversationID == conversation.id
        else { return }
        await refreshActiveConversation()
        guard let current = activeConversation, current.id == conversation.id,
              !current.messages.contains(where: { $0.role == .assistant && $0.content == text })
        else { return }
        let local = AIMessageResponse(
            id: UUID().uuidString,
            conversationId: current.id,
            role: .assistant,
            content: text,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            origin: .proactive,
            sourceLabel: "Standing task"
        )
        activeConversation = replacingMessages(in: current, with: current.messages + [local])
    }

    private func refreshActiveConversation() async {
        guard let id = activeConversation?.id,
              let refreshed = try? await service.conversation(id: id),
              activeConversation?.id == id
        else { return }
        activeConversation = refreshed
    }

    private func removePendingAction(id: String) {
        pendingActions.removeAll { $0.id == id }
        watchProposals[id] = nil
        standingTaskOutcomes[id] = nil
    }

    func cancel(_ action: AIPendingActionResponse) async {
        guard activeActionID == nil else { return }
        activeActionID = action.id
        defer { activeActionID = nil }
        do {
            try await service.cancelAction(id: action.id)
            removePendingAction(id: action.id)
        } catch {
            errorMessage = readable(error, fallback: "The action could not be cancelled.")
        }
    }

    func dismiss(_ tip: AITipResponse) async {
        do { try await service.dismissTip(id: tip.id); tips.removeAll { $0.id == tip.id } }
        catch { errorMessage = readable(error, fallback: "The tip could not be dismissed.") }
    }

    func updatePreferences(proactiveTipsEnabled: Bool? = nil, pushEnabled: Bool? = nil) async {
        guard let current = preferences else { return }
        let payload = AIAssistantPreferencesResponse(
            proactiveTipsEnabled: proactiveTipsEnabled ?? current.proactiveTipsEnabled,
            pushEnabled: pushEnabled ?? current.pushEnabled,
            timezone: TimeZone.current.identifier
        )
        do { preferences = try await service.updatePreferences(payload) }
        catch { errorMessage = readable(error, fallback: "Preferences could not be updated.") }
    }

    func clearMessage() { errorMessage = nil }

    private func refreshConversations() async {
        if let updated = try? await service.conversations() { conversations = updated }
    }

    private func replacingMessages(in conversation: AIConversationResponse, with messages: [AIMessageResponse]) -> AIConversationResponse {
        AIConversationResponse(
            id: conversation.id,
            title: conversation.title,
            messages: messages,
            createdAt: conversation.createdAt,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    private func readable(_ error: Error, fallback: String) -> String {
        let value = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : value
    }
}

private struct PersistentAssistantStreamFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Reads the one-line pointer the server stores in place of a memo's body.
nonisolated enum PositionMemoAnnouncement {
    static func symbol(in message: AIMessageResponse) -> String? {
        guard message.role == .assistant else { return nil }
        let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("Memo on "), text.hasSuffix(" is ready.") else { return nil }
        let symbol = text.dropFirst("Memo on ".count).dropLast(" is ready.".count)
        return symbol.isEmpty || symbol.contains(" ") ? nil : String(symbol)
    }
}
