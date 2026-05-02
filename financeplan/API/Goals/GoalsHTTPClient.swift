import AnyAPI
import Foundation
import OSLog
import StockPlanShared

// MARK: - Client

struct GoalsHTTPClient: Sendable {
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

        nonisolated static func == (lhs: Error, rhs: Error) -> Bool {
            switch (lhs, rhs) {
            case (.invalidResponse, .invalidResponse): return true
            case let (.invalidStatus(l), .invalidStatus(r)): return l == r
            case let (.unauthorized(l), .unauthorized(r)): return l == r
            case let (.api(l), .api(r)): return l == r
            default: return false
            }
        }

        static func makeInvalidResponse() -> Error { .invalidResponse }
        static func makeInvalidStatus(_ code: Int) -> Error { .invalidStatus(code) }
        static func makeUnauthorized(_ message: String?) -> Error { .unauthorized(message) }
        static func makeAPI(_ message: String) -> Error { .api(message) }
    }

    private let client: BaseHTTPClient

    init(baseURL: URL, session: any HTTPClientSession = URLSession.shared, authTokenProvider: @escaping @Sendable () -> String? = { nil }) {
        self.client = BaseHTTPClient(
            baseURL: baseURL,
            session: session,
            authTokenProvider: authTokenProvider,
            logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "GoalsHTTPClient"),
            decoder: .stockPlanShared
        )
    }

    func getGoals() async throws -> [GoalResponse] {
        try await client.call(GetGoalsEndpoint(), errorType: Error.self)
    }

    func createGoal(_ payload: GoalRequest) async throws -> GoalResponse {
        try await client.call(CreateGoalEndpoint(payload: payload), errorType: Error.self)
    }

    func updateGoal(id: String, payload: GoalRequest) async throws -> GoalResponse {
        try await client.call(UpdateGoalEndpoint(id: id, payload: payload), errorType: Error.self)
    }

    func updateGoalStatus(id: String, payload: GoalStatusUpdateRequest) async throws -> GoalResponse {
        try await client.call(UpdateGoalStatusEndpoint(id: id, payload: payload), errorType: Error.self)
    }

    func deleteGoal(id: String) async throws {
        try await client.callWithoutResponse(DeleteGoalEndpoint(id: id), errorType: Error.self)
    }
}
