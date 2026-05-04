import AnyAPI
import Foundation
import OSLog
import StockPlanShared

// MARK: - Client

struct CryptoHTTPClient: Sendable {
    enum Error: HTTPClientError {
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
            if case .unauthorized = self {
                return true
            }
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
            logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "CryptoHTTPClient"),
            decoder: .stockPlanShared
        )
    }

    // MARK: - Market Data

    func fetchCryptoList() async throws -> [CryptoAssetResponse] {
        try await client.call(GetCryptoListEndpoint(), errorType: Error.self)
    }

    func fetchCryptoQuote(symbols: String) async throws -> [CryptoQuoteResponse] {
        try await client.call(GetCryptoQuoteEndpoint(symbols: symbols), errorType: Error.self)
    }

    func fetchCryptoBatchQuotes(short: Bool = false) async throws -> [CryptoQuoteShortResponse] {
        try await client.call(GetCryptoBatchQuotesEndpoint(short: short), errorType: Error.self)
    }

    func fetchGeneralCryptoNews() async throws -> [NewsItemResponse] {
        try await client.call(GetGeneralCryptoNewsEndpoint(), errorType: Error.self)
    }

    // MARK: - Portfolio

    func listPortfolio() async throws -> [CryptoPortfolioItemResponse] {
        try await client.call(ListCryptoPortfolioEndpoint(), errorType: Error.self)
    }

    func addToPortfolio(payload: CryptoPortfolioItemRequest) async throws -> CryptoPortfolioItemResponse {
        try await client.call(AddToCryptoPortfolioEndpoint(payload: payload), errorType: Error.self)
    }

    func updatePortfolioItem(itemId: String, payload: CryptoPortfolioItemRequest) async throws -> CryptoPortfolioItemResponse {
        try await client.call(UpdateCryptoPortfolioItemEndpoint(itemId: itemId, payload: payload), errorType: Error.self)
    }

    func removeFromPortfolio(itemId: String) async throws {
        try await client.callWithoutResponse(RemoveFromCryptoPortfolioEndpoint(itemId: itemId), errorType: Error.self)
    }
}
