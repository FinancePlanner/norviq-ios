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
    private(set) var attachments: [AssistantAttachment] = []
    private(set) var attachmentNotice: String?
    private(set) var preparingAttachmentCount = 0
    private(set) var imagesEnabled = false
    private(set) var documentsEnabled = false

    static let maxAttachments = AssistantAttachmentLimits.maxFiles
    private static let maxAttachmentBytes = AssistantAttachmentLimits.maxImageBytes

    var attachmentRoom: Int { max(Self.maxAttachments - attachments.count - preparingAttachmentCount, 0) }

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

    /// One preferences request per app session; later presentations reuse it.
    /// A failure leaves both off, which only hides the "+" menu.
    func loadAttachmentFlags() async {
        let userID = await currentUserID()
        if let cached = conversations.flags.flags(forUser: userID) {
            imagesEnabled = cached.images
            documentsEnabled = cached.documents
            return
        }
        guard let prefs = try? await service.preferences() else { return }
        let flags = AttachmentFlagCache.Flags(images: prefs.imagesEnabled ?? false, documents: prefs.documentsEnabled ?? false)
        conversations.flags.set(flags, forUser: userID)
        imagesEnabled = flags.images
        documentsEnabled = flags.documents
    }

    /// Downscales and attaches what fits, off the main actor.
    func addAttachments(_ sources: [@Sendable () async -> Data?]) async {
        guard !isThinking else { return }
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
                attachments.append(.image(prepared))
            } else {
                attachmentNotice = String(localized: "This image could not be attached. Try another one.")
            }
        }
    }

    /// Checks each picked file the way the server will and attaches what
    /// passes. A file that fails says why and leaves the rest alone.
    func addFiles(_ urls: [URL]) async {
        // A pick loaded after Send would go with the next message instead.
        guard !isThinking else { return }
        attachmentNotice = nil
        let cap = Self.maxAttachmentBytes
        for url in urls {
            guard attachmentRoom > 0 else {
                attachmentNotice = AttachmentCheckError.tooMany.errorDescription
                break
            }
            preparingAttachmentCount += 1
            let result = await Task.detached(priority: .userInitiated) {
                AssistantAttachmentChecker.load(url: url, maxImageBytes: cap)
            }.value
            preparingAttachmentCount -= 1
            guard !isThinking else { return }
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

    func send(scope: AIViewScope?, inputMode: AssistantTurnContext.InputMode = .text) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !attachments.isEmpty, !isThinking, preparingAttachmentCount == 0 else { return }
        clearExchange()
        let outgoing = attachments
        attachments = []
        attachmentNotice = nil
        draft = ""
        question = outgoing.isEmpty ? text : AssistantAttachmentChecker.turnText(text, attachments: outgoing)
        phase = .thinking(activity: nil)
        let context = AssistantTurnContext.current(screen: scope, inputMode: inputMode)
        do {
            try await runTurn(text, attachments: outgoing, context: context, mayRecreate: true)
            phase = .answered
        } catch is CancellationError {
            attachments = outgoing
            return
        } catch {
            if Task.isCancelled {
                attachments = outgoing
                return
            }
            handle(error, question: text, attachments: outgoing)
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
        attachments = []
        attachmentNotice = nil
        phase = .idle
    }

    private func clearExchange() {
        question = nil
        answer = nil
        pendingAction = nil
        actionError = nil
        needsFullQ = false
    }

    private func runTurn(_ text: String, attachments: [AssistantAttachment], context: AssistantTurnContext, mayRecreate: Bool) async throws {
        let id = try await resolveConversation()
        do {
            var receivedTurn = false
            for try await event in service.streamTurn(conversationID: id, content: text, attachments: attachments, context: context) {
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
            try await runTurn(text, attachments: attachments, context: context, mayRecreate: false)
        }
    }

    private func apply(_ turn: AIAssistantTurnResponse) {
        answer = turn.message.content
        if turn.memo != nil { needsFullQ = true }
        guard let action = turn.pendingAction else { return }
        if action.toolName == MuseStandingTask.toolName
            || action.toolName == AssistantTradesReview.toolName
            || action.toolName == AssistantHoldingsReview.toolName {
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

    private func handle(_ error: any Error, question text: String, attachments outgoing: [AssistantAttachment]) {
        draft = text
        // Back in the composer, ahead of anything picked while the turn ran.
        attachments = Array((outgoing + attachments).prefix(Self.maxAttachments))
        if !outgoing.isEmpty, AssistantAttachmentChecker.isUpgradeRefusal(error) {
            attachmentNotice = AssistantAttachmentChecker.upgradeNotice(for: outgoing)
        }
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
