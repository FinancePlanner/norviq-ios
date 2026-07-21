import Factory
import Foundation
import StockPlanShared

protocol NewsServicing: Sendable {
    func getNews(symbol: String?, cursor: String?, limit: Int?) async throws -> (items: [NewsItemResponse], nextCursor: String?)
    func createNews(payload: NewsItemRequest) async throws -> NewsItemResponse
    func updateNews(newsId: String, payload: NewsItemRequest) async throws -> NewsItemResponse
    func deleteNews(newsId: String) async throws
    func recordNewsView(payload: NewsViewPayload) async throws
    func thesisWatch(scope: ThesisWatchScope, sector: String?, cursor: String?, limit: Int) async throws -> ThesisWatchFeedResponse
    func sendThesisWatchFeedback(storyId: String, signal: ThesisWatchFeedbackSignal) async throws
    func markThesisWatchRead(storyId: String) async throws
    func thesisWatchNotificationPreferences() async throws -> ThesisWatchNotificationPreferences
    func updateThesisWatchNotificationPreferences(enabled: Bool, timezone: String) async throws -> ThesisWatchNotificationPreferences
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
            authTokenProvider: { await Container.shared.authSessionStore().authToken }
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

    func recordNewsView(payload: NewsViewPayload) async throws {
        try await client.recordNewsView(payload: payload)
    }

    func thesisWatch(scope: ThesisWatchScope, sector: String?, cursor: String?, limit: Int) async throws -> ThesisWatchFeedResponse {
        try await client.thesisWatch(scope: scope, sector: sector, cursor: cursor, limit: limit)
    }

    func sendThesisWatchFeedback(storyId: String, signal: ThesisWatchFeedbackSignal) async throws {
        try await client.sendThesisWatchFeedback(storyId: storyId, signal: signal)
    }

    func markThesisWatchRead(storyId: String) async throws {
        try await client.markThesisWatchRead(storyId: storyId)
    }

    func thesisWatchNotificationPreferences() async throws -> ThesisWatchNotificationPreferences {
        try await client.thesisWatchNotificationPreferences()
    }

    func updateThesisWatchNotificationPreferences(enabled: Bool, timezone: String) async throws -> ThesisWatchNotificationPreferences {
        try await client.updateThesisWatchNotificationPreferences(enabled: enabled, timezone: timezone)
    }
}
