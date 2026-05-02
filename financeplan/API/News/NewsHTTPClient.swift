import AnyAPI
import Foundation
import OSLog
import StockPlanShared

// MARK: - Client

final class NewsHTTPClient: BaseHTTPClient<NewsHTTPClient.Error>, @unchecked Sendable {

    // MARK: - Error Type

    enum Error: LocalizedError, Equatable, Sendable, HTTPClientError {
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
    }

    init(baseURL: URL, session: any HTTPClientSession = URLSession.shared, authTokenProvider: @escaping () -> String? = { nil }) {
        super.init(
            baseURL: baseURL,
            session: session,
            authTokenProvider: authTokenProvider,
            logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "NewsHTTPClient"),
            decoder: .stockPlanShared
        )
    }

    // MARK: - Error Factory Overrides

    override func makeInvalidResponseError() -> Error { .invalidResponse }
    override func makeInvalidStatusError(_ code: Int) -> Error { .invalidStatus(code) }
    override func makeUnauthorizedError(_ message: String?) -> Error { .unauthorized(message) }
    override func makeAPIError(_ message: String) -> Error { .api(message) }

    // MARK: - Public API (unchanged)

    func getNews(symbol: String? = nil, cursor: String? = nil, limit: Int? = nil) async throws -> (items: [NewsItemResponse], nextCursor: String?) {
        let endpoint = GetNewsEndpoint(symbol: symbol, cursor: cursor, limit: limit)
        let (response, httpResponse) = try await callWithHeaders(endpoint)
        let nextCursor = httpResponse.value(forHTTPHeaderField: "X-Next-Cursor")
        return (response, nextCursor)
    }

    func createNews(payload: NewsItemRequest) async throws -> NewsItemResponse {
        try await call(CreateNewsEndpoint(payload: payload))
    }

    func updateNews(newsId: String, payload: NewsItemRequest) async throws -> NewsItemResponse {
        try await call(UpdateNewsEndpoint(newsId: newsId, payload: payload))
    }

    func deleteNews(newsId: String) async throws -> EmptyAPIResponse {
        try await call(DeleteNewsEndpoint(newsId: newsId))
    }

    // MARK: - Custom Envelope

    override func decodeCustomEnvelope<E: Endpoint>(data: Data, for endpoint: E) throws -> E.Response? where E.Response: Codable & Sendable {
        if let envelope = try? decoder.decode(HTTPEnvelope<E.Response>.self, from: data) {
            if let payload = envelope.data {
                return payload
            }
            if let message = envelope.message, !message.isEmpty {
                throw Error.api(message)
            }
        }
        return nil
    }

    // Preserve local envelope for servers that wrap payload in { data: ..., message: ... }.
    private struct HTTPEnvelope<T: Codable>: Codable {
        let data: T?
        let message: String?
    }
}
