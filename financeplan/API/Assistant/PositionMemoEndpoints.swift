import AnyAPI
import Foundation
import StockPlanShared

nonisolated struct ListPositionMemosEndpoint: Endpoint {
    typealias Response = [PositionMemoListItem]
    let bookmarked: Bool?
    let conversationID: String?
    var method: HTTPMethod { .get }
    var path: String { "/v1/ai/memos" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        var parameters: Parameters = [:]
        if let bookmarked { parameters["bookmarked"] = bookmarked ? "true" : "false" }
        if let conversationID { parameters["conversationId"] = conversationID }
        return parameters
    }
}

nonisolated struct GetPositionMemoEndpoint: Endpoint {
    typealias Response = PositionMemoDetail
    let id: String
    var method: HTTPMethod { .get }
    var path: String { "/v1/ai/memos/\(id)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

nonisolated struct BookmarkPositionMemoEndpoint: Endpoint {
    typealias Response = PositionMemoCard
    let id: String
    let payload: PositionMemoBookmarkRequest
    var method: HTTPMethod { .post }
    var path: String { "/v1/ai/memos/\(id)/bookmark" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { ["bookmarked": payload.bookmarked] }
}

nonisolated struct DeletePositionMemoEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let id: String
    var method: HTTPMethod { .delete }
    var path: String { "/v1/ai/memos/\(id)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}
