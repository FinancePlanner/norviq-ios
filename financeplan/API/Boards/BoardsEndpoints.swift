import AnyAPI
import Foundation
import StockPlanShared

// Community boards. Contract: StockPlanShared BoardsDTOs; routes in the
// backend's Community/BoardsController.swift and CommunityAdminController.swift.

private nonisolated func encodedParameters(_ payload: some Encodable) throws -> Parameters {
  let data = try JSONEncoder.stockPlanShared.encode(payload)
  return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
}

nonisolated struct GetCommunityViewerEndpoint: Endpoint {
  typealias Response = CommunityViewerStatus
  var method: HTTPMethod { .get }
  var path: String { "/v1/community/me" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct AcceptCommunityGuidelinesEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  var method: HTTPMethod { .post }
  var path: String { "/v1/community/guidelines/accept" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct BlockCommunityUserEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let username: String
  var method: HTTPMethod { .post }
  var path: String { "/v1/community/blocks" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { ["username": username] }
}

nonisolated struct ListBoardsEndpoint: Endpoint {
  typealias Response = BoardListResponse
  let cursor: String?
  var method: HTTPMethod { .get }
  var path: String { "/v1/boards" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { cursor.map { ["cursor": $0] } ?? [:] }
}

nonisolated struct CreateBoardEndpoint: Endpoint {
  typealias Response = BoardSummary
  let payload: CreateBoardRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/boards" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

nonisolated struct ListBoardPostsEndpoint: Endpoint {
  typealias Response = BoardPostPage
  let slug: String
  let sort: BoardPostSort
  let kind: BoardPostKind?
  let tag: String?
  let cursor: String?
  var method: HTTPMethod { .get }
  var path: String { "/v1/boards/\(slug)/posts" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters {
    var parameters: Parameters = ["sort": sort.rawValue]
    if let kind { parameters["kind"] = kind.rawValue }
    if let tag, !tag.isEmpty { parameters["tag"] = tag }
    if let cursor { parameters["cursor"] = cursor }
    return parameters
  }
}

nonisolated struct CreateBoardPostEndpoint: Endpoint {
  typealias Response = BoardPostSummary
  let slug: String
  let payload: CreateBoardPostRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/boards/\(slug)/posts" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

nonisolated struct GetBoardPostEndpoint: Endpoint {
  typealias Response = BoardPostDetail
  let postId: UUID
  var method: HTTPMethod { .get }
  var path: String { "/v1/board-posts/\(postId.uuidString)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct DeleteBoardPostEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let postId: UUID
  var method: HTTPMethod { .delete }
  var path: String { "/v1/board-posts/\(postId.uuidString)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct VoteBoardPostEndpoint: Endpoint {
  typealias Response = BoardVoteResponse
  let postId: UUID
  var method: HTTPMethod { .post }
  var path: String { "/v1/board-posts/\(postId.uuidString)/vote" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct CreateBoardCommentEndpoint: Endpoint {
  typealias Response = BoardComment
  let postId: UUID
  let payload: CreateBoardCommentRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/board-posts/\(postId.uuidString)/comments" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

nonisolated struct DeleteBoardCommentEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let commentId: UUID
  var method: HTTPMethod { .delete }
  var path: String { "/v1/board-comments/\(commentId.uuidString)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct ReportBoardContentEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let payload: BoardReportRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/board-reports" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

// MARK: - Admin

nonisolated struct AdminDeleteBoardEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let slug: String
  var method: HTTPMethod { .delete }
  var path: String { "/v1/admin/boards/\(slug)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct AdminCreateSanctionEndpoint: Endpoint {
  typealias Response = UserSanction
  let payload: CreateSanctionRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/admin/community/sanctions" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

// MARK: - Notifications

nonisolated struct ListBoardNotificationsEndpoint: Endpoint {
  typealias Response = BoardNotificationPage
  let cursor: String?
  var method: HTTPMethod { .get }
  var path: String { "/v1/community/notifications" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { cursor.map { ["cursor": $0] } ?? [:] }
}

nonisolated struct BoardUnreadCountEndpoint: Endpoint {
  typealias Response = BoardUnreadCount
  var method: HTTPMethod { .get }
  var path: String { "/v1/community/notifications/unread-count" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

/// Marks `ids` read, or everything when `ids` is nil.
nonisolated struct MarkBoardNotificationsReadEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let ids: [UUID]?
  var method: HTTPMethod { .post }
  var path: String { "/v1/community/notifications/read" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters {
    if let ids { return ["ids": ids.map(\.uuidString)] }
    // An empty dictionary sends no body at all; the server wants `{"ids": null}`.
    return ["ids": NSNull()]
  }
}

nonisolated struct GetBoardNotificationSettingsEndpoint: Endpoint {
  typealias Response = BoardNotificationSettings
  var method: HTTPMethod { .get }
  var path: String { "/v1/community/notification-settings" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct UpdateBoardNotificationSettingsEndpoint: Endpoint {
  typealias Response = BoardNotificationSettings
  let settings: BoardNotificationSettings
  var method: HTTPMethod { .put }
  var path: String { "/v1/community/notification-settings" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(settings) }
}
