import AnyAPI
import Foundation
import StockPlanShared

struct NewsViewPayload: Codable, Sendable, Equatable {
    let newsId: UUID?
    let symbol: String?
    let headline: String
    let url: String?
}

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

struct RecordNewsViewEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let payload: NewsViewPayload

    var method: HTTPMethod { .post }
    var path: String { "/v1/news/view" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        let data = try JSONEncoder.stockPlanShared.encode(payload)
        return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
    }
}

struct GetThesisWatchEndpoint: Endpoint {
    typealias Response = ThesisWatchFeedResponse
    let scope: ThesisWatchScope
    let sector: String?
    let cursor: String?
    let limit: Int

    var method: HTTPMethod { .get }
    var path: String { "/v1/news/thesis-watch" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        var parameters: Parameters = ["scope": scope.rawValue, "limit": String(limit)]
        if let sector { parameters["sector"] = sector }
        if let cursor { parameters["cursor"] = cursor }
        return parameters
    }
}

struct ThesisWatchFeedbackEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let storyId: String
    let signal: ThesisWatchFeedbackSignal

    var method: HTTPMethod { .post }
    var path: String { "/v1/news/thesis-watch/\(storyId)/feedback" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters { ["signal": signal.rawValue] }
}

struct MarkThesisWatchReadEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let storyId: String

    var method: HTTPMethod { .post }
    var path: String { "/v1/news/thesis-watch/\(storyId)/view" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters { [:] }
}

struct GetThesisWatchNotificationPreferencesEndpoint: Endpoint {
    typealias Response = ThesisWatchNotificationPreferences

    var method: HTTPMethod { .get }
    var path: String { "/v1/news/thesis-watch/notifications" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters { [:] }
}

struct UpdateThesisWatchNotificationPreferencesEndpoint: Endpoint {
    typealias Response = ThesisWatchNotificationPreferences
    let payload: UpdateThesisWatchNotificationPreferences

    var method: HTTPMethod { .put }
    var path: String { "/v1/news/thesis-watch/notifications" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        ["enabled": payload.enabled, "timezone": payload.timezone]
    }
}
