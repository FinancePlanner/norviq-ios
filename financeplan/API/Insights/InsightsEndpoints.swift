import AnyAPI
import Foundation
import StockPlanShared

struct GetTickerSentimentEndpoint: Endpoint {
    typealias Response = TickerSentimentResponse
    let symbol: String
    let days: Int?
    let limit: Int?

    var method: HTTPMethod { .get }
    var path: String { "/v1/insights/tickers/\(symbol)/sentiment" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let days { params["days"] = String(days) }
        if let limit { params["limit"] = String(limit) }
        return params
    }
}

/// Batch sentiment for many symbols in one call. The alternative — one request
/// per row — would put a request per holding on every portfolio load.
struct GetSymbolSentimentBatchEndpoint: Endpoint {
    typealias Response = SymbolSentimentBatchResponse
    let symbols: [String]

    var method: HTTPMethod { .get }
    var path: String { "/v1/insights/sentiment/symbols" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        ["symbols": symbols.joined(separator: ",")]
    }
}

struct GetPortfolioSentimentEndpoint: Endpoint {
    typealias Response = PortfolioSentimentResponse
    let portfolioListId: String?

    var method: HTTPMethod { .get }
    var path: String { "/v1/insights/sentiment/portfolio" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let portfolioListId { params["portfolioListId"] = portfolioListId }
        return params
    }
}

struct GetWatchlistSentimentEndpoint: Endpoint {
    typealias Response = PortfolioSentimentResponse
    let watchlistListId: String?

    var method: HTTPMethod { .get }
    var path: String { "/v1/insights/sentiment/watchlist" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let watchlistListId { params["watchlistListId"] = watchlistListId }
        return params
    }
}

struct GetMarketTrendingSentimentEndpoint: Endpoint {
    typealias Response = MarketTrendingResponse
    let limit: Int?

    var method: HTTPMethod { .get }
    var path: String { "/v1/insights/sentiment/trending" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let limit { params["limit"] = String(limit) }
        return params
    }
}

/// Pro-gated upstream: a non-subscriber gets a 402, which surfaces as a thrown
/// error the caller degrades on.
struct GetSentimentHistoryEndpoint: Endpoint {
    typealias Response = [SymbolSentiment]
    let symbol: String
    let limit: Int?

    var method: HTTPMethod { .get }
    var path: String { "/v1/insights/sentiment/history/\(symbol)" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let limit { params["limit"] = String(limit) }
        return params
    }
}
