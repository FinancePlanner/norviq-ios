import AnyAPI
import Foundation
import StockPlanShared

struct GetNewsEndpoint: Endpoint {
    typealias Response = [NewsItemResponse]
    let symbol: String?
    let cursor: String?
    let limit: Int?

    var method: HTTPMethod { .get }
    var path: String { "/v1/news" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let symbol { params["symbol"] = symbol }
        if let cursor { params["cursor"] = cursor }
        if let limit { params["limit"] = String(limit) }
        return params
    }
}

struct CreateNewsEndpoint: Endpoint {
    typealias Response = NewsItemResponse
    let payload: NewsItemRequest

    var method: HTTPMethod { .post }
    var path: String { "/v1/news" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        params["symbol"] = payload.symbol
        params["headline"] = payload.headline
        if let source = payload.source { params["source"] = source }
        if let url = payload.url { params["url"] = url }
        if let summary = payload.summary { params["summary"] = summary }
        if let publishedAt = payload.publishedAt { params["publishedAt"] = publishedAt }
        return params
    }
}

struct UpdateNewsEndpoint: Endpoint {
    typealias Response = NewsItemResponse
    let newsId: String
    let payload: NewsItemRequest

    var method: HTTPMethod { .put }
    var path: String { "/v1/news/\(newsId)" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        params["symbol"] = payload.symbol
        params["headline"] = payload.headline
        if let source = payload.source { params["source"] = source }
        if let url = payload.url { params["url"] = url }
        if let summary = payload.summary { params["summary"] = summary }
        if let publishedAt = payload.publishedAt { params["publishedAt"] = publishedAt }
        return params
    }
}

struct DeleteNewsEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let newsId: String

    var method: HTTPMethod { .delete }
    var path: String { "/v1/news/\(newsId)" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters { [:] }
}
