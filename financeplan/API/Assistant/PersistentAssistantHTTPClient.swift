import AnyAPI
import Foundation
import OSLog
import StockPlanShared

struct PersistentAssistantHTTPClient: Sendable {
    enum Error: HTTPClientError {
        case invalidResponse
        case invalidStatus(Int)
        case unauthorized(String?)
        case api(String)

        nonisolated var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid server response."
            case let .invalidStatus(code): return "Request failed (\(code))."
            case let .unauthorized(message): return message ?? "Your session expired. Please sign in again."
            case let .api(message): return message
            }
        }

        nonisolated var statusCode: Int? {
            if case let .invalidStatus(code) = self { return code }
            return nil
        }

        static func makeInvalidResponse() -> Error { .invalidResponse }
        static func makeInvalidStatus(_ code: Int) -> Error { .invalidStatus(code) }
        static func makeUnauthorized(_ message: String?) -> Error { .unauthorized(message) }
        static func makeAPI(_ message: String) -> Error { .api(message) }
    }

    private let client: BaseHTTPClient

    init(
        baseURL: URL,
        session: any HTTPClientSession = URLSession.shared,
        authTokenProvider: @escaping @Sendable () async -> String? = { nil }
    ) {
        client = BaseHTTPClient(
            baseURL: baseURL,
            session: session,
            authTokenProvider: authTokenProvider,
            logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "PersistentAssistantHTTPClient"),
            decoder: .stockPlanShared
        )
    }

    func conversations() async throws -> [AIConversationSummaryResponse] {
        try await client.call(ListAssistantConversationsEndpoint(), errorType: Error.self)
    }

    func createConversation(title: String?) async throws -> AIConversationResponse {
        try await client.call(CreateAssistantConversationEndpoint(payload: .init(title: title)), errorType: Error.self)
    }

    func conversation(id: String) async throws -> AIConversationResponse {
        try await client.call(GetAssistantConversationEndpoint(id: id), errorType: Error.self)
    }

    func deleteConversation(id: String) async throws {
        try await client.callWithoutResponse(DeleteAssistantConversationEndpoint(id: id), errorType: Error.self)
    }

    func turn(conversationID: String, content: String) async throws -> AIAssistantTurnResponse {
        try await client.call(CreateAssistantTurnEndpoint(id: conversationID, payload: .init(content: content)), errorType: Error.self)
    }

    func preferences() async throws -> AIAssistantPreferencesResponse {
        try await client.call(GetAssistantPreferencesEndpoint(), errorType: Error.self)
    }

    func updatePreferences(_ payload: AIAssistantPreferencesResponse) async throws -> AIAssistantPreferencesResponse {
        try await client.call(UpdateAssistantPreferencesEndpoint(payload: payload), errorType: Error.self)
    }

    func tips() async throws -> [AITipResponse] {
        try await client.call(ListAssistantTipsEndpoint(), errorType: Error.self)
    }

    func dismissTip(id: String) async throws {
        try await client.callWithoutResponse(DismissAssistantTipEndpoint(id: id), errorType: Error.self)
    }

    func usage() async throws -> AIAssistantUsageResponse {
        try await client.call(GetAssistantUsageEndpoint(), errorType: Error.self)
    }

    func pendingActions() async throws -> [AIPendingActionResponse] {
        try await client.call(ListAssistantActionsEndpoint(), errorType: Error.self)
    }

    func confirmAction(id: String) async throws -> AIConfirmedActionResponse {
        try await client.call(ConfirmAssistantActionEndpoint(id: id), errorType: Error.self)
    }

    func cancelAction(id: String) async throws {
        try await client.callWithoutResponse(CancelAssistantActionEndpoint(id: id), errorType: Error.self)
    }
}

extension PersistentAssistantHTTPClient.Error: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse): true
        case let (.invalidStatus(lhs), .invalidStatus(rhs)): lhs == rhs
        case let (.unauthorized(lhs), .unauthorized(rhs)): lhs == rhs
        case let (.api(lhs), .api(rhs)): lhs == rhs
        default: false
        }
    }
}
