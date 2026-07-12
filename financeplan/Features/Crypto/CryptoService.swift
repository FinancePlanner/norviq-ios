import Foundation
import StockPlanShared

@MainActor
protocol CryptoServicing: Sendable {
    func fetchCryptoList() async throws -> [CryptoAssetResponse]
    func fetchCryptoQuote(symbols: String) async throws -> [CryptoQuoteResponse]
    func fetchCryptoBatchQuotes(short: Bool) async throws -> [CryptoQuoteShortResponse]
    func fetchGeneralCryptoNews() async throws -> [NewsItemResponse]
    func fetchHistory(symbol: String, resolution: CryptoChartResolution, from: String?, to: String?) async throws -> [CryptoHistoricalPoint]
    func fetchPortfolio() async throws -> [CryptoPortfolioItemResponse]
    func addToPortfolio(payload: CryptoPortfolioItemRequest) async throws -> CryptoPortfolioItemResponse
    func updatePortfolioItem(itemId: String, payload: CryptoPortfolioItemRequest) async throws -> CryptoPortfolioItemResponse
    func removeFromPortfolio(itemId: String) async throws
    func fetchWatchlist() async throws -> [CryptoWatchlistItemResponse]
    func addToWatchlist(payload: CryptoWatchlistItemRequest) async throws -> CryptoWatchlistItemResponse
    func updateWatchlistItem(itemId: String, payload: CryptoWatchlistItemRequest) async throws -> CryptoWatchlistItemResponse
    func removeFromWatchlist(itemId: String) async throws
}

final class CryptoHTTPService: CryptoServicing {
    private let environmentManager: AppEnvironmentManager
    private let session: MarketDataURLSessionProtocol
    private let authSessionManager: AuthSessionManaging

    init(
        environmentManager: AppEnvironmentManager,
        session: MarketDataURLSessionProtocol = URLSession.shared,
        authSessionManager: AuthSessionManaging
    ) {
        self.environmentManager = environmentManager
        self.session = session
        self.authSessionManager = authSessionManager
    }

    func fetchCryptoList() async throws -> [CryptoAssetResponse] {
        try await performAuthenticated { client in
            try await client.fetchCryptoList()
        }
    }

    func fetchCryptoQuote(symbols: String) async throws -> [CryptoQuoteResponse] {
        try await performAuthenticated { client in
            try await client.fetchCryptoQuote(symbols: symbols)
        }
    }

    func fetchCryptoBatchQuotes(short: Bool = false) async throws -> [CryptoQuoteShortResponse] {
        try await performAuthenticated { client in
            try await client.fetchCryptoBatchQuotes(short: short)
        }
    }

    func fetchGeneralCryptoNews() async throws -> [NewsItemResponse] {
        try await performAuthenticated { client in
            try await client.fetchGeneralCryptoNews()
        }
    }

    func fetchHistory(symbol: String, resolution: CryptoChartResolution, from: String?, to: String?) async throws -> [CryptoHistoricalPoint] {
        try await performAuthenticated { client in
            try await client.fetchHistory(symbol: symbol, resolution: resolution, from: from, to: to)
        }
    }

    func fetchPortfolio() async throws -> [CryptoPortfolioItemResponse] {
        try await performAuthenticated { client in
            try await client.listPortfolio()
        }
    }

    func addToPortfolio(payload: CryptoPortfolioItemRequest) async throws -> CryptoPortfolioItemResponse {
        try await performAuthenticated { client in
            try await client.addToPortfolio(payload: payload)
        }
    }

    func updatePortfolioItem(itemId: String, payload: CryptoPortfolioItemRequest) async throws -> CryptoPortfolioItemResponse {
        try await performAuthenticated { client in
            try await client.updatePortfolioItem(itemId: itemId, payload: payload)
        }
    }

    func removeFromPortfolio(itemId: String) async throws {
        try await performAuthenticated { client in
            try await client.removeFromPortfolio(itemId: itemId)
        }
    }

    func fetchWatchlist() async throws -> [CryptoWatchlistItemResponse] {
        try await performAuthenticated { client in
            try await client.listWatchlist()
        }
    }

    func addToWatchlist(payload: CryptoWatchlistItemRequest) async throws -> CryptoWatchlistItemResponse {
        try await performAuthenticated { client in
            try await client.addToWatchlist(payload: payload)
        }
    }

    func updateWatchlistItem(itemId: String, payload: CryptoWatchlistItemRequest) async throws -> CryptoWatchlistItemResponse {
        try await performAuthenticated { client in
            try await client.updateWatchlistItem(itemId: itemId, payload: payload)
        }
    }

    func removeFromWatchlist(itemId: String) async throws {
        try await performAuthenticated { client in
            try await client.removeFromWatchlist(itemId: itemId)
        }
    }

    private func makeClient(forceRefresh: Bool = false) async throws -> CryptoHTTPClient {
        let token = try await resolvedAccessToken(forceRefresh: forceRefresh)
        return CryptoHTTPClient(
            baseURL: environmentManager.current.apiBaseUrl,
            session: session,
            authTokenProvider: { token }
        )
    }

    private func performAuthenticated<T: Sendable>(
        _ operation: (CryptoHTTPClient) async throws -> T
    ) async throws -> T {
        do {
            let client = try await makeClient()
            return try await operation(client)
        } catch let error as CryptoHTTPClient.Error where error.isUnauthorized {
            do {
                let client = try await makeClient(forceRefresh: true)
                return try await operation(client)
            } catch let retryError as CryptoHTTPClient.Error where retryError.isUnauthorized {
                await authSessionManager.invalidateSession()
                throw retryError
            } catch {
                throw error
            }
        }
    }

    private func resolvedAccessToken(forceRefresh: Bool) async throws -> String {
        let token = forceRefresh
            ? try await authSessionManager.refreshAccessToken()
            : try await authSessionManager.validAccessToken()

        guard let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthSessionError.notAuthenticated
        }

        return token
    }
}
