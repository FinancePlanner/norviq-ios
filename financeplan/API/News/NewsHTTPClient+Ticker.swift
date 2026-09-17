import Foundation
import StockPlanShared

extension NewsHTTPClient {
    func newsTicker(limit: Int) async throws -> NewsTickerResponse {
        try await client.call(GetNewsTickerEndpoint(limit: limit), errorType: Error.self)
    }

    func newsTickerSettings() async throws -> NewsTickerSettings {
        try await client.call(GetNewsTickerSettingsEndpoint(), errorType: Error.self)
    }

    func updateNewsTickerSettings(enabled: Bool) async throws -> NewsTickerSettings {
        try await client.call(UpdateNewsTickerSettingsEndpoint(enabled: enabled), errorType: Error.self)
    }

    func listNewsTickerFeeds() async throws -> NewsTickerFeedsResponse {
        try await client.call(ListNewsTickerFeedsEndpoint(), errorType: Error.self)
    }

    func addNewsTickerFeed(url: String) async throws -> NewsTickerFeed {
        try await client.call(AddNewsTickerFeedEndpoint(url: url), errorType: Error.self)
    }

    func deleteNewsTickerFeed(id: String) async throws {
        try await client.callWithoutResponse(DeleteNewsTickerFeedEndpoint(feedId: id), errorType: Error.self)
    }
}
