import Factory
import Foundation
import StockPlanShared

protocol NewsServicing: Sendable {
    func getNews(symbol: String?, cursor: String?, limit: Int?) async throws -> (items: [NewsItemResponse], nextCursor: String?)
    func createNews(payload: NewsItemRequest) async throws -> NewsItemResponse
    func updateNews(newsId: String, payload: NewsItemRequest) async throws -> NewsItemResponse
    func deleteNews(newsId: String) async throws
}

extension NewsServicing {
    func getNews(symbol: String? = nil, cursor: String? = nil, limit: Int? = nil) async throws -> (items: [NewsItemResponse], nextCursor: String?) {
        try await getNews(symbol: symbol, cursor: cursor, limit: limit)
    }
}

struct NewsHTTPService: NewsServicing {
    private let client: NewsHTTPClient

    init(environmentManager: AppEnvironmentManager, authSessionManager: any AuthSessionManaging) {
        self.client = NewsHTTPClient(
            baseURL: environmentManager.current.apiBaseUrl,
            session: URLSession.shared,
            authTokenProvider: { Container.shared.authSessionStore().authToken }
        )
    }

    func getNews(symbol: String? = nil, cursor: String? = nil, limit: Int? = nil) async throws -> (items: [NewsItemResponse], nextCursor: String?) {
        try await client.getNews(symbol: symbol, cursor: cursor, limit: limit)
    }

    func createNews(payload: NewsItemRequest) async throws -> NewsItemResponse {
        try await client.createNews(payload: payload)
    }

    func updateNews(newsId: String, payload: NewsItemRequest) async throws -> NewsItemResponse {
        try await client.updateNews(newsId: newsId, payload: payload)
    }

    func deleteNews(newsId: String) async throws {
        try await client.deleteNews(newsId: newsId)
    }
}


