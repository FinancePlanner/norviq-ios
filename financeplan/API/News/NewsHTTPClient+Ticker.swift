import Foundation
import StockPlanShared

extension NewsHTTPClient {
    func newsTicker(limit: Int) async throws -> NewsTickerResponse {
        try await call(GetNewsTickerEndpoint(limit: limit))
    }

    func newsTickerSettings() async throws -> NewsTickerSettings {
        try await call(GetNewsTickerSettingsEndpoint())
    }

    func updateNewsTickerSettings(enabled: Bool) async throws -> NewsTickerSettings {
        try await call(UpdateNewsTickerSettingsEndpoint(enabled: enabled))
    }

    func listNewsTickerFeeds() async throws -> NewsTickerFeedsResponse {
        try await call(ListNewsTickerFeedsEndpoint())
    }

    func addNewsTickerFeed(url: String) async throws -> NewsTickerFeed {
        try await call(AddNewsTickerFeedEndpoint(url: url))
    }

    func deleteNewsTickerFeed(id: String) async throws {
        try await callWithoutResponse(DeleteNewsTickerFeedEndpoint(feedId: id))
    }
}
