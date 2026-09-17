import AnyAPI
import Foundation
import StockPlanShared

// Breaking-news ticker: headline, source, time and a link. The backend reads
// the cluster's shared feed aggregator; the app never talks to publishers.

nonisolated struct GetNewsTickerEndpoint: Endpoint {
    typealias Response = NewsTickerResponse
    let limit: Int

    var method: HTTPMethod { .get }
    var path: String { "/v1/news/ticker" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters { ["limit": String(limit)] }
}

nonisolated struct GetNewsTickerSettingsEndpoint: Endpoint {
    typealias Response = NewsTickerSettings

    var method: HTTPMethod { .get }
    var path: String { "/v1/news/ticker/settings" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters { [:] }
}

nonisolated struct UpdateNewsTickerSettingsEndpoint: Endpoint {
    typealias Response = NewsTickerSettings
    let enabled: Bool

    var method: HTTPMethod { .put }
    var path: String { "/v1/news/ticker/settings" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters { ["enabled": enabled] }
}

nonisolated struct ListNewsTickerFeedsEndpoint: Endpoint {
    typealias Response = NewsTickerFeedsResponse

    var method: HTTPMethod { .get }
    var path: String { "/v1/news/ticker/feeds" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters { [:] }
}

nonisolated struct AddNewsTickerFeedEndpoint: Endpoint {
    typealias Response = NewsTickerFeed
    let url: String

    var method: HTTPMethod { .post }
    var path: String { "/v1/news/ticker/feeds" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters { ["url": url] }
}

nonisolated struct DeleteNewsTickerFeedEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let feedId: String

    var method: HTTPMethod { .delete }
    var path: String { "/v1/news/ticker/feeds/\(feedId)" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters { [:] }
}
