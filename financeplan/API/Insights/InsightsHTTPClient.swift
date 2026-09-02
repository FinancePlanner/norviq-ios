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
        let normalized = Self.normalize(symbols)
        guard !normalized.isEmpty else { return [:] }

        var merged: [String: SymbolSentiment] = [:]
        for chunk in normalized.chunked(into: Self.maxBatchSymbols) {
            let response = try await client.call(
                GetSymbolSentimentBatchEndpoint(symbols: chunk),
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

    static func normalize(_ symbols: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for symbol in symbols {
            let cleaned = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !cleaned.isEmpty, seen.insert(cleaned).inserted else { continue }
            ordered.append(cleaned)
        }
        return ordered
    }
}

nonisolated extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
