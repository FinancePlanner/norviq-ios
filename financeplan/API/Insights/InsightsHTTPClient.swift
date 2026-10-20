import Algorithms
import AnyAPI
import Foundation
import OSLog
import StockPlanShared

// MARK: - Client

nonisolated final class InsightsHTTPClient: Sendable {

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
            logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "InsightsHTTPClient"),
            decoder: .stockPlanShared
        )
    }

    // MARK: - Public API

    func getTickerSentiment(symbol: String, days: Int? = 14, limit: Int? = 20) async throws -> TickerSentimentResponse {
        try await client.call(GetTickerSentimentEndpoint(symbol: symbol, days: days, limit: limit), errorType: Error.self)
    }

    // MARK: - Retail sentiment

    /// Server caps the batch at 100 symbols; chunking here keeps a large
    /// portfolio from turning into a 400.
    static let maxBatchSymbols = 100

    func getSymbolSentiment(symbols: [String]) async throws -> [String: SymbolSentiment] {
        var merged: [String: SymbolSentiment] = [:]
        for batch in Self.symbolBatches(symbols) {
            let response = try await client.call(
                GetSymbolSentimentBatchEndpoint(symbols: batch),
                errorType: Error.self
            )
            for (symbol, sentiment) in response.symbols {
                merged[symbol.uppercased()] = sentiment
            }
        }
        return merged
    }

    func getPortfolioSentiment(portfolioListId: String? = nil) async throws -> PortfolioSentimentResponse {
        try await client.call(
            GetPortfolioSentimentEndpoint(portfolioListId: portfolioListId),
            errorType: Error.self
        )
    }

    func getWatchlistSentiment(watchlistListId: String? = nil) async throws -> PortfolioSentimentResponse {
        try await client.call(
            GetWatchlistSentimentEndpoint(watchlistListId: watchlistListId),
            errorType: Error.self
        )
    }

    func getMarketTrendingSentiment(limit: Int? = 20) async throws -> MarketTrendingResponse {
        try await client.call(GetMarketTrendingSentimentEndpoint(limit: limit), errorType: Error.self)
    }

    func getSentimentHistory(symbol: String, limit: Int? = 30) async throws -> [SymbolSentiment] {
        try await client.call(
            GetSentimentHistoryEndpoint(symbol: symbol, limit: limit),
            errorType: Error.self
        )
    }

    /// Normalized symbols in request-sized batches; empty when nothing is left.
    static func symbolBatches(_ symbols: [String]) -> [[String]] {
        normalize(symbols).chunks(ofCount: maxBatchSymbols).map(Array.init)
    }

    static func normalize(_ symbols: [String]) -> [String] {
        let cleaned = symbols
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
        return Array(cleaned.uniqued())
    }
}
