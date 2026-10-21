import AnyAPI
import Foundation
import StockPlanShared

// Groups: Discord-style groups with text channels. Contract: StockPlanShared
// GroupsDTOs; routes in the backend's Groups/GroupsController.swift and
// GroupMessagesController.swift. The live stream is GroupsRealtimeClient.

private nonisolated func encodedParameters(_ payload: some Encodable) throws -> Parameters {
  let data = try JSONEncoder.stockPlanShared.encode(payload)
  return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
}

// MARK: - Groups

nonisolated struct ListMyGroupsEndpoint: Endpoint {
  typealias Response = GroupListResponse
  var method: HTTPMethod { .get }
  var path: String { "/v1/groups" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct CreateGroupEndpoint: Endpoint {
  typealias Response = GroupDetail
  let payload: CreateGroupRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/groups" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

/// Public groups. `query` searches names; a `$TICKER` query searches by ticker.
/// `tickers` asks for groups about the user's holdings.
nonisolated struct DiscoverGroupsEndpoint: Endpoint {
  typealias Response = GroupDirectoryPage
  let query: String?
  let ticker: String?
  let tickers: [String]
  let cursor: String?
  var method: HTTPMethod { .get }
  var path: String { "/v1/groups/discover" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters {
    var parameters: Parameters = [:]
    if let query, !query.isEmpty { parameters["q"] = query }
    if let ticker, !ticker.isEmpty { parameters["ticker"] = ticker }
    if !tickers.isEmpty { parameters["tickers"] = tickers.joined(separator: ",") }
    if let cursor { parameters["cursor"] = cursor }
    return parameters
  }
}

nonisolated struct GroupsUnreadCountEndpoint: Endpoint {
  typealias Response = GroupUnreadCount
  var method: HTTPMethod { .get }
  var path: String { "/v1/groups/unread-count" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetGroupEndpoint: Endpoint {
  typealias Response = GroupDetail
  let groupId: UUID
  var method: HTTPMethod { .get }
  var path: String { "/v1/groups/\(groupId.uuidString)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct UpdateGroupEndpoint: Endpoint {
  typealias Response = GroupDetail
  let groupId: UUID
  let payload: UpdateGroupRequest
  var method: HTTPMethod { .patch }
  var path: String { "/v1/groups/\(groupId.uuidString)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

nonisolated struct DeleteGroupEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let groupId: UUID
  var method: HTTPMethod { .delete }
  var path: String { "/v1/groups/\(groupId.uuidString)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct JoinGroupEndpoint: Endpoint {
  typealias Response = GroupDetail
  let groupId: UUID
  var method: HTTPMethod { .post }
  var path: String { "/v1/groups/\(groupId.uuidString)/join" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct LeaveGroupEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let groupId: UUID
  var method: HTTPMethod { .post }
  var path: String { "/v1/groups/\(groupId.uuidString)/leave" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct UpdateGroupNotificationsEndpoint: Endpoint {
  typealias Response = GroupMembership
  let groupId: UUID
  let payload: GroupNotificationSettingsRequest
  var method: HTTPMethod { .put }
  var path: String { "/v1/groups/\(groupId.uuidString)/notifications" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

// MARK: - Members

nonisolated struct ListGroupMembersEndpoint: Endpoint {
  typealias Response = GroupMemberPage
  let groupId: UUID
  let cursor: String?
  var method: HTTPMethod { .get }
  var path: String { "/v1/groups/\(groupId.uuidString)/members" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { cursor.map { ["cursor": $0] } ?? [:] }
}

nonisolated struct UpdateGroupMemberEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let groupId: UUID
  let userId: UUID
  let payload: UpdateGroupMemberRequest
  var method: HTTPMethod { .patch }
  var path: String { "/v1/groups/\(groupId.uuidString)/members/\(userId.uuidString)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

nonisolated struct KickGroupMemberEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let groupId: UUID
  let userId: UUID
  var method: HTTPMethod { .delete }
  var path: String { "/v1/groups/\(groupId.uuidString)/members/\(userId.uuidString)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct BanGroupMemberEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let groupId: UUID
  let payload: GroupBanRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/groups/\(groupId.uuidString)/bans" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

nonisolated struct TransferGroupOwnershipEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let groupId: UUID
  let payload: TransferGroupOwnershipRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/groups/\(groupId.uuidString)/transfer" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

// MARK: - Channels

nonisolated struct CreateGroupChannelEndpoint: Endpoint {
  typealias Response = GroupChannel
  let groupId: UUID
  let payload: CreateGroupChannelRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/groups/\(groupId.uuidString)/channels" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

nonisolated struct UpdateGroupChannelEndpoint: Endpoint {
  typealias Response = GroupChannel
  let channelId: UUID
  let payload: UpdateGroupChannelRequest
  var method: HTTPMethod { .patch }
  var path: String { "/v1/group-channels/\(channelId.uuidString)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

nonisolated struct DeleteGroupChannelEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let channelId: UUID
  var method: HTTPMethod { .delete }
  var path: String { "/v1/group-channels/\(channelId.uuidString)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

// MARK: - Messages

/// The latest page with neither bound; `before`/`after` page by `seq`. Items
/// come back oldest first.
nonisolated struct ListGroupMessagesEndpoint: Endpoint {
  typealias Response = GroupMessagePage
  let channelId: UUID
  let before: Int64?
  let after: Int64?
  let limit: Int?
  var method: HTTPMethod { .get }
  var path: String { "/v1/group-channels/\(channelId.uuidString)/messages" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters {
    var parameters: Parameters = [:]
    if let before { parameters["before"] = before }
    if let after { parameters["after"] = after }
    if let limit { parameters["limit"] = limit }
    return parameters
  }
}

/// 201 for a new message, 200 with the original when `clientMessageId` was
/// already sent; both decode the same.
nonisolated struct SendGroupMessageEndpoint: Endpoint {
  typealias Response = GroupMessage
  let channelId: UUID
  let payload: SendGroupMessageRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/group-channels/\(channelId.uuidString)/messages" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

nonisolated struct MarkGroupChannelReadEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let channelId: UUID
  let payload: MarkGroupChannelReadRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/group-channels/\(channelId.uuidString)/read" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

nonisolated struct DeleteGroupMessageEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let messageId: UUID
  var method: HTTPMethod { .delete }
  var path: String { "/v1/group-messages/\(messageId.uuidString)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct ReportGroupMessageEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let messageId: UUID
  let payload: GroupMessageReportRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/group-messages/\(messageId.uuidString)/report" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

// MARK: - Invites

nonisolated struct CreateGroupInviteLinkEndpoint: Endpoint {
  typealias Response = GroupInviteLink
  let groupId: UUID
  let payload: CreateGroupInviteRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/groups/\(groupId.uuidString)/invites" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

nonisolated struct InviteFriendsToGroupEndpoint: Endpoint {
  typealias Response = GroupDirectInvitationResponse
  let groupId: UUID
  let payload: GroupDirectInvitationRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/groups/\(groupId.uuidString)/invitations" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try encodedParameters(payload) }
}

nonisolated struct ListGroupInvitationsEndpoint: Endpoint {
  typealias Response = GroupInvitationList
  var method: HTTPMethod { .get }
  var path: String { "/v1/groups/invitations" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct AcceptGroupInvitationEndpoint: Endpoint {
  typealias Response = GroupDetail
  let invitationId: UUID
  var method: HTTPMethod { .post }
  var path: String { "/v1/groups/invitations/\(invitationId.uuidString)/accept" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct DeclineGroupInvitationEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let invitationId: UUID
  var method: HTTPMethod { .post }
  var path: String { "/v1/groups/invitations/\(invitationId.uuidString)/decline" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct PreviewGroupInviteEndpoint: Endpoint {
  typealias Response = GroupInvitePreview
  let code: String
  var method: HTTPMethod { .get }
  var path: String { "/v1/group-invites/\(code)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct RedeemGroupInviteEndpoint: Endpoint {
  typealias Response = GroupDetail
  let code: String
  var method: HTTPMethod { .post }
  var path: String { "/v1/group-invites/\(code)/redeem" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}
