import AnyAPI
import Foundation
import StockPlanShared

nonisolated struct GetSocialConfigEndpoint: Endpoint {
  typealias Response = SocialConfig
  var method: HTTPMethod { .get }
  var path: String { "/v1/social/config" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct SearchSocialUsersEndpoint: Endpoint {
  typealias Response = UserSearchResponse
  let query: String
  var method: HTTPMethod { .get }
  var path: String { "/v1/social/users/search" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { ["q": query] }
}

nonisolated struct GetSocialProfileEndpoint: Endpoint {
  typealias Response = SocialProfile
  let userId: String
  var method: HTTPMethod { .get }
  var path: String { "/v1/social/users/\(userId)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetFriendsEndpoint: Endpoint {
  typealias Response = FriendsListResponse
  var method: HTTPMethod { .get }
  var path: String { "/v1/social/friends" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct RemoveFriendEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let userId: String
  var method: HTTPMethod { .delete }
  var path: String { "/v1/social/friends/\(userId)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetFriendRequestsEndpoint: Endpoint {
  typealias Response = FriendRequestsResponse
  var method: HTTPMethod { .get }
  var path: String { "/v1/social/friend-requests" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct SendFriendRequestEndpoint: Endpoint {
  typealias Response = FriendRequest
  let payload: SendFriendRequestRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/social/friend-requests" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { ["userId": payload.userId] }
}

nonisolated struct RespondFriendRequestEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  nonisolated enum Action: String, Sendable, Codable { case accept, decline }
  let requestId: String
  let action: Action
  var method: HTTPMethod { .post }
  var path: String { "/v1/social/friend-requests/\(requestId)/\(action.rawValue)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct CancelFriendRequestEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let requestId: String
  var method: HTTPMethod { .delete }
  var path: String { "/v1/social/friend-requests/\(requestId)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct CreateInviteEndpoint: Endpoint {
  typealias Response = InviteLink
  var method: HTTPMethod { .post }
  var path: String { "/v1/social/invites" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetInviteEndpoint: Endpoint {
  typealias Response = SocialUserSummary
  let code: String
  var method: HTTPMethod { .get }
  var path: String { "/v1/social/invites/\(code)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct RedeemInviteEndpoint: Endpoint {
  typealias Response = InviteRedeemResponse
  let code: String
  var method: HTTPMethod { .post }
  var path: String { "/v1/social/invites/\(code)/redeem" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetSocialPrivacyEndpoint: Endpoint {
  typealias Response = SocialPrivacySettings
  var method: HTTPMethod { .get }
  var path: String { "/v1/social/privacy" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct UpdateSocialPrivacyEndpoint: Endpoint {
  typealias Response = SocialPrivacySettings
  let payload: SocialPrivacySettings
  var method: HTTPMethod { .put }
  var path: String { "/v1/social/privacy" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters {
    let data = try JSONEncoder.stockPlanShared.encode(payload)
    return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
  }
}

nonisolated struct GetBlockedUsersEndpoint: Endpoint {
  typealias Response = BlockedUsersResponse
  var method: HTTPMethod { .get }
  var path: String { "/v1/social/blocks" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct SetBlockEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let userId: String
  let blocked: Bool
  var method: HTTPMethod { blocked ? .post : .delete }
  var path: String { "/v1/social/blocks/\(userId)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct SubmitReportEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let payload: ReportRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/social/reports" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters {
    let data = try JSONEncoder.stockPlanShared.encode(payload)
    return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
  }
}
