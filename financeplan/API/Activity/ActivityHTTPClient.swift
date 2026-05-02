import AnyAPI
import Foundation
import OSLog
import StockPlanShared

// MARK: - Client

final class ActivityHTTPClient: BaseHTTPClient<ActivityHTTPClient.Error>, @unchecked Sendable {
    
    // MARK: - Error Type
    
    enum Error: LocalizedError, Equatable, Sendable, HTTPClientError {
        case invalidResponse
        case invalidStatus(Int)
        case unauthorized(String?)
        case api(String)
        
        nonisolated var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid server response."
            case let .invalidStatus(code):
                return "Request failed (\(code))."
            case let .unauthorized(message):
                return message ?? "Your session expired. Please sign in again."
            case let .api(message):
                return message
            }
        }
        
        var isUnauthorized: Bool {
            if case .unauthorized = self { return true }
            return false
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
    }
    
    init(baseURL: URL, session: any HTTPClientSession = URLSession.shared, authTokenProvider: @escaping () -> String? = { nil }) {
        super.init(
            baseURL: baseURL,
            session: session,
            authTokenProvider: authTokenProvider,
            logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "ActivityHTTPClient"),
            decoder: .stockPlanShared
        )
    }
    
    // MARK: - Error Factory Overrides
    
    override func makeInvalidResponseError() -> Error { .invalidResponse }
    override func makeInvalidStatusError(_ code: Int) -> Error { .invalidStatus(code) }
    override func makeUnauthorizedError(_ message: String?) -> Error { .unauthorized(message) }
    override func makeAPIError(_ message: String) -> Error { .api(message) }
    
    // MARK: - Public API
    
    func fetchActivities(limit: Int? = nil) async throws -> [UserActivityResponse] {
        try await call(GetActivitiesEndpoint(limit: limit))
    }
}
