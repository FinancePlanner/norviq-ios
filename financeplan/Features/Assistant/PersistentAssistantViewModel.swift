import Factory
import Foundation
import Observation
import PhotosUI
import StockPlanShared
import SwiftUI

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
    /// The server said this turn needs Pro or a fresh quota.
    var isPaywallRequested = false
    /// Memo cards keyed by the assistant message that announced them.
    private(set) var memoCards: [String: PositionMemoCard] = [:]
    private(set) var memoBookmarkInFlight: Set<String> = []
    /// Watch proposals from streamed turns, keyed by pending-action id. After
    /// a reload they are gone and the card redraws from the action's arguments.
    private(set) var watchProposals: [String: AIWatchProposalResponse] = [:]
    /// Standing-task cards the user answered but that stay on screen.
    private(set) var standingTaskOutcomes: [String: MuseStandingTaskOutcome] = [:]
    var draft = ""

    /// The backend's limits for one turn (`maxTurnImages`, `maxTurnImageBytes`).
    static let maxAttachments = 3
    static let maxAttachmentBytes = 5 << 20
    /// Images waiting to go with the next message.
    private(set) var attachments: [ScreenshotUploadImage] = []
    private(set) var preparingAttachmentCount = 0
    /// Why an image did not attach or go through. Shown in the composer, where
    /// it is still readable once a paywall sheet closes.
    private(set) var attachmentNotice: String?
    var pickedItems: [PhotosPickerItem] = [] {
        didSet { handlePicked() }
    }

    /// Absent from a backend that predates images, which means no.
    var imagesEnabled: Bool { preferences?.imagesEnabled ?? false }

    var attachmentRoom: Int { max(Self.maxAttachments - attachments.count - preparingAttachmentCount, 0) }

    var canSend: Bool {
        let hasText = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || !attachments.isEmpty) && !isSending && preparingAttachmentCount == 0
    }

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

    /// Opens on `preferredConversationID` when given and loadable, otherwise
    /// on the most recent conversation.
    func load(preferredConversationID: String? = nil) async {
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
            if let preferredConversationID, (try? await selectConversation(id: preferredConversationID)) != nil {
                // Opened from a push or link.
            } else if let first = conversations.first {
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

    /// A push or link acting on the assistant already on screen.
    func handle(_ command: AssistantInPlaceCommand) async {
        switch command {
        case let .open(conversationID):
            await select(id: conversationID)
            await refreshConversations()
        case let .refresh(conversationID):
            guard let active = activeConversation?.id,
                  AssistantDeepLink.normalizedConversationID(active) == AssistantDeepLink.normalizedConversationID(conversationID)
            else { return }
            await refreshActiveConversation()
            await refreshConversations()
        }
    }

    func select(id: String) async {
        do { try await selectConversation(id: id) }
        catch { errorMessage = readable(error, fallback: "The conversation could not be opened.") }
    }

    private func handlePicked() {
        guard !pickedItems.isEmpty else { return }
        // Emptied so the picker never reopens on the last selection.
        let items = pickedItems
        pickedItems = []
        Task {
            await addAttachments(items.map { item in { try? await item.loadTransferable(type: Data.self) } })
        }
    }

    /// Downscales and attaches what fits. Off the main actor, because a full-size
    /// photo takes long enough to decode and encode that the composer would hitch.
    func addAttachments(_ sources: [@Sendable () async -> Data?]) async {
        attachmentNotice = nil
        let room = attachmentRoom
        if sources.count > room {
            attachmentNotice = String(localized: "Attach up to \(Self.maxAttachments) images.")
        }
        let taken = sources.prefix(room)
        preparingAttachmentCount += taken.count
        let cap = Self.maxAttachmentBytes
        for source in taken {
            let prepared = await Task.detached(priority: .userInitiated) { () -> ScreenshotUploadImage? in
                guard let data = await source() else { return nil }
                return UploadImagePreparer.prepare(data, maxBytes: cap)
            }.value
            preparingAttachmentCount -= 1
            if let prepared {
                attachments.append(prepared)
            } else {
                attachmentNotice = String(localized: "This image could not be attached. Try another one.")
            }
        }
    }

    func removeAttachment(id: ScreenshotUploadImage.ID) {
        attachments.removeAll { $0.id == id }
        attachmentNotice = nil
    }

    func send() async {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty || !attachments.isEmpty,
              let conversation = activeConversation,
              !isSending,
              preparingAttachmentCount == 0
        else { return }
        let resolution = AssistantCommandParser.resolve(content)
        // A command answered on the device sends nothing, so its images stay put.
        let outgoingImages: [ScreenshotUploadImage]
        if case .local = resolution {
            outgoingImages = []
        } else {
            outgoingImages = attachments
            attachments = []
        }
        draft = ""
        attachmentNotice = nil
        isSending = true
        errorMessage = nil
        let optimistic = AIMessageResponse(
            id: UUID().uuidString,
            conversationId: conversation.id,
            role: .user,
            content: outgoingImages.isEmpty ? content : Self.storedImageTurnText(content),
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        activeConversation = replacingMessages(in: conversation, with: conversation.messages + [optimistic])

        let outgoingContent: String
        switch resolution {
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
        var receivedTurn = false
        do {
            for try await event in service.streamTurn(
                conversationID: conversation.id,
                content: outgoingContent,
                images: outgoingImages,
                context: .current()
            ) {
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
                case let .error(message, code):
                    throw AssistantTurnFailure(message: message, code: code)
                case .done:
                    break
                }
            }
            guard receivedTurn else {
                throw AssistantTurnFailure(message: "The assistant returned no response.")
            }
            async let usageRequest = service.usage()
            async let conversationsRequest = service.conversations()
            usage = try await usageRequest
            conversations = try await conversationsRequest
        } catch {
            // A turn that arrived before a later failure (e.g. refreshing
            // usage) still counts; only a turn that never landed is a snag.
            if agentState.phase == .working { apply(.failed) }
            // An image turn whose reply arrived is stored, and its images are
            // gone from the server: sending them again could only repeat it.
            if !(receivedTurn && !outgoingImages.isEmpty) {
                if let current = activeConversation {
                    activeConversation = replacingMessages(in: current, with: current.messages.filter { $0.id != optimistic.id })
                }
                // In front of whatever was typed while the turn ran.
                draft = [content, draft].filter { !$0.isEmpty }.joined(separator: "\n")
                attachments = outgoingImages + attachments
            }
            switch AssistantTurnRecovery(error) {
            case .askForConsent:
                AIConsentRequired.post()
            case .showPaywall:
                isPaywallRequested = true
                if !outgoingImages.isEmpty, Self.isUpgradeRefusal(error) {
                    attachmentNotice = String(localized: "Attaching images is part of Pro. Upgrade to use it.")
                }
            case .recreateConversation, .showMessage:
                errorMessage = readable(error, fallback: "The assistant could not respond.")
            }
        }
    }

    /// The text the server stores for an image turn, so the bubble reads the
    /// same before and after a reload. `defaultImagePrompt` and `imageMarker` in
    /// the backend's `images.go`.
    private static func storedImageTurnText(_ content: String) -> String {
        (content.isEmpty ? "What's in this image?" : content) + " [image attached]"
    }

    private static func isUpgradeRefusal(_ error: any Error) -> Bool {
        if let failure = error as? AssistantTurnFailure { return failure.code == "upgrade_required" }
        if case .upgradeRequired? = error as? AssistantStreamClient.Failure { return true }
        return false
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
        if AIConsentRequired.matches(error) { return "Allow AI data sharing to use the assistant." }
        let value = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : value
    }
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
