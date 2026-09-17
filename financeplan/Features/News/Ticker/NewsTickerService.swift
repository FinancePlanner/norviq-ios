import Factory
import Foundation
import StockPlanShared

/// Everything the ticker UI needs from the backend. Kept apart from
/// `NewsServicing` so the (large) news mock surface in tests stays untouched.
protocol NewsTickerServicing: Sendable {
    func ticker(limit: Int) async throws -> NewsTickerResponse
    func settings() async throws -> NewsTickerSettings
    func updateSettings(enabled: Bool) async throws -> NewsTickerSettings
    func listFeeds() async throws -> NewsTickerFeedsResponse
    func addFeed(url: String) async throws -> NewsTickerFeed
    func removeFeed(id: String) async throws
}

struct NewsTickerHTTPService: NewsTickerServicing {
    private let client: NewsHTTPClient

    init(client: NewsHTTPClient) {
        self.client = client
    }

    func ticker(limit: Int) async throws -> NewsTickerResponse { try await client.newsTicker(limit: limit) }
    func settings() async throws -> NewsTickerSettings { try await client.newsTickerSettings() }
    func updateSettings(enabled: Bool) async throws -> NewsTickerSettings { try await client.updateNewsTickerSettings(enabled: enabled) }
    func listFeeds() async throws -> NewsTickerFeedsResponse { try await client.listNewsTickerFeeds() }
    func addFeed(url: String) async throws -> NewsTickerFeed { try await client.addNewsTickerFeed(url: url) }
    func removeFeed(id: String) async throws { try await client.deleteNewsTickerFeed(id: id) }
}

extension Container {
    var newsTickerService: Factory<NewsTickerServicing> {
        self { @MainActor [unowned self] in
            NewsTickerHTTPService(client: self.newsHTTPClient())
        }
    }
}
