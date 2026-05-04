import AnyAPI
import Foundation
import OSLog
import StockPlanShared

// MARK: - Client

final class NewsHTTPClient: Sendable {

    // MARK: - Error Type

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

    init(baseURL: URL, session: any HTTPClientSession = URLSession.shared, authTokenProvider: @escaping @Sendable () async -> String? = { nil }) {
        self.client = BaseHTTPClient(
            baseURL: baseURL,
            session: session,
            authTokenProvider: authTokenProvider,
            logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "NewsHTTPClient"),
            decoder: .stockPlanShared
        )
    }

    // MARK: - Public API (delegated)

    func getNews(symbol: String? = nil, cursor: String? = nil, limit: Int? = nil) async throws -> (items: [NewsItemResponse], nextCursor: String?) {
        let endpoint = GetNewsEndpoint(symbol: symbol, cursor: cursor, limit: limit)
        let (response, httpResponse) = try await client.callWithHeaders(endpoint, errorType: Error.self)
        let nextCursor = httpResponse.value(forHTTPHeaderField: "X-Next-Cursor")
        return (response, nextCursor)
    }

    func createNews(payload: NewsItemRequest) async throws -> NewsItemResponse {
        try await client.call(CreateNewsEndpoint(payload: payload), errorType: Error.self)
    }

    func updateNews(newsId: String, payload: NewsItemRequest) async throws -> NewsItemResponse {
        try await client.call(UpdateNewsEndpoint(newsId: newsId, payload: payload), errorType: Error.self)
    }

    func deleteNews(newsId: String) async throws {
        try await client.callWithoutResponse(DeleteNewsEndpoint(newsId: newsId), errorType: Error.self)
    }
}
