import Factory
import Foundation
import Observation
import PhotosUI
import StockPlanShared
import SwiftUI
import UniformTypeIdentifiers

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
    /// Trades cards (`record_trades`) by action id, built when the action
    /// arrives. The user's edits live here, so they outlive scrolling and reloads.
    private(set) var tradesReviews: [String: AssistantTradesReview] = [:]
    /// The portfolios a trades card can pick from. Nil until a card needs them,
    /// or when loading failed: the card then saves to the list it proposed.
    private(set) var portfolioLists: [PortfolioListDTOResponse]?
    /// Holdings cards (`update_holdings`) by action id, kept like `tradesReviews`.
    private(set) var holdingsReviews: [String: AssistantHoldingsReview] = [:]
    var draft = ""

    /// The backend's limits for one turn (`maxTurnImages`, `maxTurnImageBytes`).
    static let maxAttachments = AssistantAttachmentLimits.maxFiles
    static let maxAttachmentBytes = AssistantAttachmentLimits.maxImageBytes
    /// Images, PDFs and CSVs waiting to go with the next message.
    private(set) var attachments: [AssistantAttachment] = []
    private(set) var preparingAttachmentCount = 0
    /// Why a file did not attach or go through. Shown in the composer, where
    /// it is still readable once a paywall sheet closes.
    private(set) var attachmentNotice: String?
    var pickedItems: [PhotosPickerItem] = [] {
        didSet { handlePicked() }
    }

    /// Absent from a backend that predates images, which means no.
    var imagesEnabled: Bool { preferences?.imagesEnabled ?? false }

    /// Absent from a backend that predates documents, which means no.
    var documentsEnabled: Bool { preferences?.documentsEnabled ?? false }

    var attachmentRoom: Int { max(Self.maxAttachments - attachments.count - preparingAttachmentCount, 0) }

    var canSend: Bool {
        let hasText = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || !attachments.isEmpty) && !isSending && preparingAttachmentCount == 0
    }

    var memoService: any PersistentAssistantServicing { service }

    private let service: any PersistentAssistantServicing
    private let sleep: @Sendable (Duration) async throws -> Void
    private let now: @Sendable () -> Date
    /// Bumped when the conversation changes, so a pick still loading is dropped.
    private var attachmentEpoch = 0
    private var celebrationTask: Task<Void, Never>?

    init(
        service: any PersistentAssistantServicing,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = service
        self.sleep = sleep
        self.now = now
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
            rebuildTradesReviews()
            if let preferredConversationID, (try? await selectConversation(id: preferredConversationID)) != nil {
                // Opened from a push or link.
            } else if let first = conversations.first {
                try await selectConversation(id: first.id)
            } else {
                try await createConversation()
            }
            await loadPortfolioListsIfNeeded()
        } catch {
            errorMessage = readable(error, fallback: "The assistant could not be loaded.")
        }
    }

    func createConversation() async throws {
        let created = try await service.createConversation(title: "New conversation")
        memoCards = [:]
        dropAttachments()
        activeConversation = created
        await refreshConversations()
    }

    func newConversation() async {
        do { try await createConversation() }
        catch { errorMessage = readable(error, fallback: "A conversation could not be created.") }
    }

    func selectConversation(id: String) async throws {
        let conversation = try await service.conversation(id: id)
        if activeConversation?.id != conversation.id { dropAttachments() }
        activeConversation = conversation
        await attachMemoCards(to: conversation)
    }

    /// A pick belongs to the conversation it was made in; one still loading is dropped too.
    private func dropAttachments() {
        attachments = []
        attachmentNotice = nil
        preparingAttachmentCount = 0
        attachmentEpoch += 1
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
        // The picker is disabled mid-turn; this is a pick that lost the race
        // with Send, which a failed turn's restore would otherwise add to.
        guard !isSending else {
            pickedItems = []
            return
        }
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
        // A pick loaded after Send would go with the next message instead.
        guard !isSending else { return }
        attachmentNotice = nil
        let room = attachmentRoom
        if sources.count > room {
            attachmentNotice = AttachmentCheckError.tooMany.errorDescription
        }
        let taken = sources.prefix(room)
        preparingAttachmentCount += taken.count
        let cap = Self.maxAttachmentBytes
        let epoch = attachmentEpoch
        for source in taken {
            let prepared = await Task.detached(priority: .userInitiated) { () -> ScreenshotUploadImage? in
                guard let data = await source() else { return nil }
                return UploadImagePreparer.prepare(data, maxBytes: cap)
            }.value
            // The conversation changed meanwhile and the count was zeroed.
            guard epoch == attachmentEpoch else { return }
            preparingAttachmentCount -= 1
            if let prepared {
                attachments.append(.image(prepared))
            } else {
                attachmentNotice = String(localized: "This image could not be attached. Try another one.")
            }
        }
    }

    /// Reads what the document picker returned, checks each file the way the
    /// server will, and attaches what passes. A file that fails says why and
    /// leaves the rest alone.
    func addFiles(_ urls: [URL]) async {
        guard !isSending else { return }
        attachmentNotice = nil
        let cap = Self.maxAttachmentBytes
        let epoch = attachmentEpoch
        for url in urls {
            // Counted per file, so a second pick during this one sees the room it takes.
            guard attachmentRoom > 0 else {
                attachmentNotice = AttachmentCheckError.tooMany.errorDescription
                break
            }
            preparingAttachmentCount += 1
            let result = await Task.detached(priority: .userInitiated) {
                AssistantAttachmentChecker.load(url: url, maxImageBytes: cap)
            }.value
            guard epoch == attachmentEpoch else { return }
            preparingAttachmentCount -= 1
            // Send may have started while the file was read; the rest of the pick would go with the next message, so stop.
            guard !isSending else { return }
            do {
                let attachment = try result.get()
                try AssistantAttachmentChecker.admit(attachment, into: attachments)
                attachments.append(attachment)
            } catch {
                attachmentNotice = (error as? AttachmentCheckError)?.errorDescription
            }
        }
    }

    func removeAttachment(id: AssistantAttachment.ID) {
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
        let outgoingImages: [AssistantAttachment]
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
            content: outgoingImages.isEmpty ? content : AssistantAttachmentChecker.turnText(content, attachments: outgoingImages),
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
                attachments: outgoingImages,
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
                        rebuildTradesReviews()
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
            // Off the turn's path, so the composer is free as soon as the reply lands.
            Task { await loadPortfolioListsIfNeeded() }
            async let usageRequest = service.usage()
            async let conversationsRequest = service.conversations()
            usage = try await usageRequest
            conversations = try await conversationsRequest
        } catch {
            // A turn that arrived before a later failure (e.g. refreshing
            // usage) still counts; only a turn that never landed is a snag.
            if agentState.phase == .working { apply(.failed) }
            // The reply is stored and on screen; only a refresh after it
            // failed. Taking the message back would invite sending it twice.
            guard !receivedTurn else { return }
            if let current = activeConversation {
                activeConversation = replacingMessages(in: current, with: current.messages.filter { $0.id != optimistic.id })
            }
            // In front of whatever was typed while the turn ran.
            draft = [content, draft].filter { !$0.isEmpty }.joined(separator: "\n")
            attachments = Array((outgoingImages + attachments).prefix(Self.maxAttachments))
            switch AssistantTurnRecovery(error) {
            case .askForConsent:
                AIConsentRequired.post()
            case .showPaywall:
                isPaywallRequested = true
                if !outgoingImages.isEmpty, AssistantAttachmentChecker.isUpgradeRefusal(error) {
                    attachmentNotice = AssistantAttachmentChecker.upgradeNotice(for: outgoingImages)
                }
            case .recreateConversation, .showMessage:
                errorMessage = readable(error, fallback: "The assistant could not respond.")
            }
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
        tradesReviews[id] = nil
        holdingsReviews[id] = nil
    }

    // MARK: - Trades cards

    /// Takes the card's edits. A card that is gone stays gone.
    func updateTradesReview(_ review: AssistantTradesReview) {
        guard tradesReviews[review.actionID] != nil else { return }
        tradesReviews[review.actionID] = review
    }

    /// A card for each `record_trades` action whose arguments read; one
    /// already on screen keeps its edits. Others get the plain card.
    private func rebuildTradesReviews() {
        var reviews: [String: AssistantTradesReview] = [:]
        for action in pendingActions {
            reviews[action.id] = tradesReviews[action.id] ?? AssistantTradesReview(action: action)
        }
        tradesReviews = reviews
        var holdings: [String: AssistantHoldingsReview] = [:]
        for action in pendingActions {
            holdings[action.id] = holdingsReviews[action.id] ?? AssistantHoldingsReview(action: action)
        }
        holdingsReviews = holdings
    }

    // MARK: - Holdings cards

    /// Takes the card's edits. A card that is gone stays gone.
    func updateHoldingsReview(_ review: AssistantHoldingsReview) {
        guard holdingsReviews[review.actionID] != nil else { return }
        holdingsReviews[review.actionID] = review
    }

    /// Turns "Replace existing" on or off. Turning it on resends, which is
    /// what the collision refusal asked for.
    func setReplaceExisting(_ on: Bool, for action: AIPendingActionResponse) async {
        guard var review = holdingsReviews[action.id], review.replaceExisting != on else { return }
        review.replaceExisting = on
        holdingsReviews[action.id] = review
        if on { await confirmHoldings(action) }
    }

    /// Saves the card's ticked rows as they stand. A 422 keeps the card with
    /// its collision and row errors, unless the save failed after the backend
    /// claimed the action, which settles it. A 409, a 404 and a lost answer
    /// follow the trades card's rules (`confirmTrades`). A 402 or
    /// 403 is the Pro limit. Success settles the card with the backend's
    /// message, which names what was saved and, on a partial save, what was not.
    func confirmHoldings(_ action: AIPendingActionResponse) async {
        guard activeActionID == nil, var review = holdingsReviews[action.id], review.canSave else { return }
        activeActionID = action.id
        defer { activeActionID = nil }
        let triedBefore = review.hasAttemptedSave
        review.hasAttemptedSave = true
        holdingsReviews[action.id] = review
        do {
            let result = try await service.confirmHoldings(id: action.id, body: review.confirmBody)
            review.completedMessage = result.message
            review.refusal = nil
        } catch let PersistentAssistantHTTPClient.Error.holdingsRefused(refusal) {
            let reason = refusal.reason.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            let isCollision = refusal.code == AIHoldingsRefusalResponse.collisionCode
            if await isStillPending(action.id) == false {
                review.closedMessage = reason.map { "\($0) \(AssistantHoldingsReview.closedCopy)" } ?? AssistantHoldingsReview.closedCopy
            } else {
                review.refuse(reason ?? AssistantHoldingsReview.retryCopy, isCollision: isCollision, rowErrors: refusal.rows)
            }
        } catch let PersistentAssistantHTTPClient.Error.unprocessable(reason, _) {
            let reason = reason.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            if await isStillPending(action.id) == false {
                review.closedMessage = reason.map { "\($0) \(AssistantHoldingsReview.closedCopy)" } ?? AssistantHoldingsReview.closedCopy
            } else {
                review.refuse(reason ?? AssistantHoldingsReview.retryCopy, rowErrors: [])
            }
        } catch PersistentAssistantHTTPClient.Error.conflict {
            review.closedMessage = mayHaveBeenSaved(triedBefore: triedBefore, expiresAt: action.expiresAt)
                ? AssistantHoldingsReview.maybeSavedCopy : AssistantHoldingsReview.expiredCopy
        } catch PersistentAssistantHTTPClient.Error.invalidStatus(404) {
            review.closedMessage = mayHaveBeenSaved(triedBefore: triedBefore, expiresAt: action.expiresAt)
                ? AssistantHoldingsReview.maybeSavedCopy : AssistantHoldingsReview.expiredCopy
        } catch PersistentAssistantHTTPClient.Error.upgradeRequired {
            review.refuse(AssistantHoldingsReview.upgradeCopy, rowErrors: [])
        } catch {
            switch await lostAnswer(error, actionID: action.id) {
            case .refused: review.refuse(AssistantHoldingsReview.retryCopy, rowErrors: [])
            case .gone: review.closedMessage = AssistantHoldingsReview.maybeSavedCopy
            case .stillPending: review.refuse(AssistantHoldingsReview.unconfirmedCopy, rowErrors: [])
            }
        }
        holdingsReviews[action.id] = review
    }

    private var isLoadingPortfolioLists = false

    /// Loads the picker's lists once a card needs them. A failed load leaves
    /// them nil and is tried again the next time a card appears or asks, so a
    /// card blocked by sync is never left with no other portfolio to pick.
    func loadPortfolioListsIfNeeded() async {
        guard !tradesReviews.isEmpty, portfolioLists == nil, !isLoadingPortfolioLists else { return }
        isLoadingPortfolioLists = true
        defer { isLoadingPortfolioLists = false }
        portfolioLists = try? await service.portfolioLists()
    }

    /// Saves the card's kept rows as they stand. A 422 keeps the card with its
    /// errors on the rows, unless the save failed after the backend claimed
    /// the action, which settles it: a 422 then looks the same, so the action
    /// is fetched again, and a card no longer pending is closed. A 409 means
    /// it expired or was already answered.
    ///
    /// The backend finishes a claimed save even when the client has gone, so
    /// a lost answer (a timeout, a dropped connection, a 5xx) may hide a save
    /// (R30). The action is fetched again: gone means it may have been saved,
    /// and the card says to check before sending the screenshot again; still
    /// waiting means the save could not be confirmed either way. A 409 or a
    /// 404 closes the card: as "may have been saved" once this card has tried
    /// or while the review has not expired, as expired otherwise.
    func confirmTrades(_ action: AIPendingActionResponse) async {
        guard activeActionID == nil, var review = tradesReviews[action.id], review.canSave else { return }
        activeActionID = action.id
        defer { activeActionID = nil }
        let triedBefore = review.hasAttemptedSave
        review.hasAttemptedSave = true
        tradesReviews[action.id] = review
        let body = review.confirmBody
        do {
            let result = try await service.confirmTrades(id: action.id, portfolioListID: body.portfolioListId, trades: body.trades)
            removePendingAction(id: action.id)
            errorMessage = result.message
            return
        } catch let PersistentAssistantHTTPClient.Error.unprocessable(reason, rowErrors) {
            let reason = reason.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            if await isStillPending(action.id) == false {
                review.closedMessage = reason.map { "\($0) \(AssistantTradesReview.closedCopy)" } ?? AssistantTradesReview.closedCopy
            } else {
                review.refuse(reason ?? AssistantTradesReview.retryCopy, rowErrors: rowErrors)
            }
        } catch PersistentAssistantHTTPClient.Error.conflict {
            review.closedMessage = mayHaveBeenSaved(triedBefore: triedBefore, expiresAt: action.expiresAt)
                ? AssistantTradesReview.maybeSavedCopy : AssistantTradesReview.expiredCopy
        } catch PersistentAssistantHTTPClient.Error.invalidStatus(404) {
            // The backend's NotFound for this action, with no body.
            review.closedMessage = mayHaveBeenSaved(triedBefore: triedBefore, expiresAt: action.expiresAt)
                ? AssistantTradesReview.maybeSavedCopy : AssistantTradesReview.expiredCopy
        } catch PersistentAssistantHTTPClient.Error.upgradeRequired {
            review.refuse(AssistantTradesReview.upgradeCopy, rowErrors: [])
        } catch {
            switch await lostAnswer(error, actionID: action.id) {
            case .refused: review.refuse(AssistantTradesReview.retryCopy, rowErrors: [])
            case .gone: review.closedMessage = AssistantTradesReview.maybeSavedCopy
            case .stillPending: review.refuse(AssistantTradesReview.unconfirmedCopy, rowErrors: [])
            }
        }
        tradesReviews[action.id] = review
    }

    /// For a 409 or a 404: the action can no longer be confirmed. Before its
    /// expiry something claimed it, perhaps this card's own save whose answer
    /// was lost; so may a card that already tried.
    private func mayHaveBeenSaved(triedBefore: Bool, expiresAt: String) -> Bool {
        if triedBefore { return true }
        guard let expiry = AssistantTradesReview.expiryDate(expiresAt) else { return false }
        return expiry > now()
    }

    private enum LostAnswer { case refused, gone, stillPending }

    /// What a failed confirm with no usable answer means. A 4xx saved nothing;
    /// otherwise the action is fetched again (R30): gone may mean saved, and
    /// still waiting (or a failed refetch) means the save is unconfirmed.
    private func lostAnswer(_ error: any Error, actionID: String) async -> LostAnswer {
        if Self.isClientRefusal(error) { return .refused }
        return await isStillPending(actionID) == false ? .gone : .stillPending
    }

    /// A 4xx the backend answered, which means it saved nothing. Anything else
    /// (no answer, a 5xx, an unreadable one) may hide a finished save. A
    /// transport failure arrives as `.api`, so `.api` is never counted as a refusal.
    private static func isClientRefusal(_ error: any Error) -> Bool {
        switch error as? PersistentAssistantHTTPClient.Error {
        case .unauthorized?: true
        case let .invalidStatus(code)?: (400..<500).contains(code)
        default: false
        }
    }

    /// Whether the action still waits for an answer; nil when that cannot be told.
    private func isStillPending(_ id: String) async -> Bool? {
        guard let actions = try? await service.pendingActions() else { return nil }
        return actions.contains { $0.id.caseInsensitiveCompare(id) == .orderedSame && $0.status == .pending }
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
