import Factory
import Foundation
import StockPlanShared

protocol PersistentAssistantServicing: Sendable {
    func conversations() async throws -> [AIConversationSummaryResponse]
    func createConversation(title: String?) async throws -> AIConversationResponse
    func conversation(id: String) async throws -> AIConversationResponse
    func deleteConversation(id: String) async throws
    func turn(conversationID: String, content: String) async throws -> AIAssistantTurnResponse
    func preferences() async throws -> AIAssistantPreferencesResponse
    func updatePreferences(_ payload: AIAssistantPreferencesResponse) async throws -> AIAssistantPreferencesResponse
    func tips() async throws -> [AITipResponse]
    func dismissTip(id: String) async throws
    func usage() async throws -> AIAssistantUsageResponse
    func pendingActions() async throws -> [AIPendingActionResponse]
    func confirmAction(id: String) async throws -> AIConfirmedActionResponse
    func cancelAction(id: String) async throws
}

struct DefaultPersistentAssistantService: PersistentAssistantServicing, Sendable {
    private let client: PersistentAssistantHTTPClient

    init(environmentManager: AppEnvironmentManager, authSessionManager _: any AuthSessionManaging) {
        client = PersistentAssistantHTTPClient(
            baseURL: environmentManager.current.apiBaseUrl,
            authTokenProvider: { await Container.shared.authSessionStore().authToken }
        )
    }

    func conversations() async throws -> [AIConversationSummaryResponse] { try await client.conversations() }
    func createConversation(title: String?) async throws -> AIConversationResponse { try await client.createConversation(title: title) }
    func conversation(id: String) async throws -> AIConversationResponse { try await client.conversation(id: id) }
    func deleteConversation(id: String) async throws { try await client.deleteConversation(id: id) }
    func turn(conversationID: String, content: String) async throws -> AIAssistantTurnResponse { try await client.turn(conversationID: conversationID, content: content) }
    func preferences() async throws -> AIAssistantPreferencesResponse { try await client.preferences() }
    func updatePreferences(_ payload: AIAssistantPreferencesResponse) async throws -> AIAssistantPreferencesResponse { try await client.updatePreferences(payload) }
    func tips() async throws -> [AITipResponse] { try await client.tips() }
    func dismissTip(id: String) async throws { try await client.dismissTip(id: id) }
    func usage() async throws -> AIAssistantUsageResponse { try await client.usage() }
    func pendingActions() async throws -> [AIPendingActionResponse] { try await client.pendingActions() }
    func confirmAction(id: String) async throws -> AIConfirmedActionResponse { try await client.confirmAction(id: id) }
    func cancelAction(id: String) async throws { try await client.cancelAction(id: id) }
}
