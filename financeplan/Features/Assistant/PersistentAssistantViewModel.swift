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
    private(set) var activeActionID: String?
    private(set) var errorMessage: String?
    var draft = ""

    private let service: any PersistentAssistantServicing

    init(service: any PersistentAssistantServicing) { self.service = service }
    convenience init() { self.init(service: Container.shared.persistentAssistantService()) }

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
        activeConversation = created
        await refreshConversations()
    }

    func newConversation() async {
        do { try await createConversation() }
        catch { errorMessage = readable(error, fallback: "A conversation could not be created.") }
    }

    func selectConversation(id: String) async throws {
        activeConversation = try await service.conversation(id: id)
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
        defer { isSending = false }
        do {
            let turn = try await service.turn(conversationID: conversation.id, content: content)
            if let current = activeConversation {
                activeConversation = replacingMessages(in: current, with: current.messages + [turn.message])
            }
            if let action = turn.pendingAction { pendingActions.insert(action, at: 0) }
            async let usageRequest = service.usage()
            async let conversationsRequest = service.conversations()
            usage = try await usageRequest
            conversations = try await conversationsRequest
        } catch {
            if let current = activeConversation {
                activeConversation = replacingMessages(in: current, with: current.messages.filter { $0.id != optimistic.id })
            }
            draft = content
            errorMessage = readable(error, fallback: "The assistant could not respond.")
        }
    }

    func confirm(_ action: AIPendingActionResponse) async {
        guard activeActionID == nil else { return }
        activeActionID = action.id
        defer { activeActionID = nil }
        do {
            let result = try await service.confirmAction(id: action.id)
            pendingActions.removeAll { $0.id == action.id }
            errorMessage = result.message
        } catch {
            errorMessage = readable(error, fallback: "The action could not be applied.")
        }
    }

    func cancel(_ action: AIPendingActionResponse) async {
        guard activeActionID == nil else { return }
        activeActionID = action.id
        defer { activeActionID = nil }
        do {
            try await service.cancelAction(id: action.id)
            pendingActions.removeAll { $0.id == action.id }
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
