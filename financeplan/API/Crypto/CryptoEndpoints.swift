import AnyAPI
import Foundation
import StockPlanShared

// MARK: - Market Data Endpoints

struct GetCryptoListEndpoint: Endpoint {
    typealias Response = [CryptoAssetResponse]
    var method: HTTPMethod { .get }
    var path: String { "/v1/crypto/list" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct GetCryptoQuoteEndpoint: Endpoint {
    typealias Response = [CryptoQuoteResponse]
    let symbols: String
    var method: HTTPMethod { .get }
    var path: String { "/v1/crypto/quote/\(symbols.uppercased())" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct GetCryptoBatchQuotesEndpoint: Endpoint {
    typealias Response = [CryptoQuoteShortResponse]
    let short: Bool
    var method: HTTPMethod { .get }
    var path: String { "/v1/crypto/batch-quotes" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        ["short": String(short)]
    }
}

struct GetGeneralCryptoNewsEndpoint: Endpoint {
    typealias Response = [NewsItemResponse]
    var method: HTTPMethod { .get }
    var path: String { "/v1/crypto/news" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct GetCryptoHistoryEndpoint: Endpoint {
    typealias Response = [CryptoHistoricalPoint]
    let symbol: String
    let resolution: CryptoChartResolution
    let from: String?
    let to: String?
    var method: HTTPMethod { .get }
    var path: String { "/v1/crypto/history/\(resolution.rawValue)/\(symbol.uppercased())" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let from { params["from"] = from }
        if let to { params["to"] = to }
        return params
    }
}

// MARK: - Portfolio Endpoints

struct ListCryptoPortfolioEndpoint: Endpoint {
    typealias Response = [CryptoPortfolioItemResponse]
    var method: HTTPMethod { .get }
    var path: String { "/v1/crypto/portfolio" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct AddToCryptoPortfolioEndpoint: Endpoint {
    typealias Response = CryptoPortfolioItemResponse
    let payload: CryptoPortfolioItemRequest
    var method: HTTPMethod { .post }
    var path: String { "/v1/crypto/portfolio" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        [
            "symbol": payload.symbol,
            "name": payload.name,
            "quantity": payload.quantity,
            "average_buy_price": payload.averageBuyPrice
        ]
    }
}

struct UpdateCryptoPortfolioItemEndpoint: Endpoint {
    typealias Response = CryptoPortfolioItemResponse
    let itemId: String
    let payload: CryptoPortfolioItemRequest
    var method: HTTPMethod { .put }
    var path: String { "/v1/crypto/portfolio/\(itemId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        [
            "symbol": payload.symbol,
            "name": payload.name,
            "quantity": payload.quantity,
            "average_buy_price": payload.averageBuyPrice
        ]
    }
}

struct RemoveFromCryptoPortfolioEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let itemId: String
    var method: HTTPMethod { .delete }
    var path: String { "/v1/crypto/portfolio/\(itemId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

// MARK: - Watchlist Endpoints

private func cryptoWatchlistParameters(_ payload: CryptoWatchlistItemRequest) -> Parameters {
    var params: Parameters = [
        "symbol": payload.symbol,
        "name": payload.name
    ]
    if let note = payload.note { params["note"] = note }
    if let status = payload.status { params["status"] = status.rawValue }
    return params
}

struct ListCryptoWatchlistEndpoint: Endpoint {
    typealias Response = [CryptoWatchlistItemResponse]
    var method: HTTPMethod { .get }
    var path: String { "/v1/crypto/watchlist" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct AddToCryptoWatchlistEndpoint: Endpoint {
    typealias Response = CryptoWatchlistItemResponse
    let payload: CryptoWatchlistItemRequest
    var method: HTTPMethod { .post }
    var path: String { "/v1/crypto/watchlist" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { cryptoWatchlistParameters(payload) }
}

struct UpdateCryptoWatchlistItemEndpoint: Endpoint {
    typealias Response = CryptoWatchlistItemResponse
    let itemId: String
    let payload: CryptoWatchlistItemRequest
    var method: HTTPMethod { .put }
    var path: String { "/v1/crypto/watchlist/\(itemId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { cryptoWatchlistParameters(payload) }
}

struct RemoveFromCryptoWatchlistEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let itemId: String
    var method: HTTPMethod { .delete }
    var path: String { "/v1/crypto/watchlist/\(itemId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}
