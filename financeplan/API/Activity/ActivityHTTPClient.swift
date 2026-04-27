import AnyAPI
import Foundation
import OSLog
import StockPlanShared


// MARK: - Session Protocol

protocol ActivityURLSessionProtocol: HTTPClientSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}
extension URLSession: ActivityURLSessionProtocol {}

// MARK: - Error Type (top-level to avoid actor isolation)

enum ActivityError: @preconcurrency LocalizedError, Equatable, @unchecked Sendable, HTTPClientError {
    case invalidResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response."
        case let .api(message): return message
        }
    }

    var isUnauthorized: Bool {
        if case .invalidResponse = self { return true }
        return false
    }

    var statusCode: Int? { nil }
}

// MARK: - Client

final class ActivityHTTPClient: BaseHTTPClient<ActivityError> {
    // Preserve nested typealias for compatibility
    typealias Error = ActivityError

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

    override func makeInvalidResponseError() -> ActivityError { .invalidResponse }
    override func makeInvalidStatusError(_ code: Int) -> ActivityError { .invalidResponse } // not used; map all invalid status to invalidResponse
    override func makeUnauthorizedError(_ message: String?) -> ActivityError { .invalidResponse } // not used; 401/403 handled specially below
    override func makeAPIError(_ message: String) -> ActivityError { .api(message) }

    // MARK: - Public API

    func fetchActivities(limit: Int? = nil) async throws -> [UserActivityResponse] {
        let endpoint = GetActivitiesEndpoint(limit: limit)
        let request = try makeURLRequest(for: endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActivityError.invalidResponse
        }

        // Status handling matches original:
        // - 2xx: decode
        // - 401/403: throw URLError(.userAuthenticationRequired)
        // - other: attempt envelope message extraction, else throw .invalidResponse
        if (200...299).contains(httpResponse.statusCode) {
            return try endpoint.decode(data)
        } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else {
            if let envelope = try? endpoint.decoder.decode(APIEnvelope<[UserActivityResponse]>.self, from: data),
               let message = envelope.message, !message.isEmpty {
                throw ActivityError.api(message)
            }
            throw ActivityError.invalidResponse
        }
    }
}
