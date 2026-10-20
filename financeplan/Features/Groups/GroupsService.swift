import Factory
import Foundation
import StockPlanShared

protocol GroupsServicing: Sendable {
  func myGroups() async throws -> GroupListResponse
  func create(_ request: CreateGroupRequest) async throws -> GroupDetail
  func discover(query: String?, ticker: String?, tickers: [String], cursor: String?) async throws -> GroupDirectoryPage
  func unreadCount() async throws -> GroupUnreadCount
  func group(id: UUID) async throws -> GroupDetail
  func update(groupId: UUID, _ request: UpdateGroupRequest) async throws -> GroupDetail
  func delete(groupId: UUID) async throws
  func join(groupId: UUID) async throws -> GroupDetail
  func leave(groupId: UUID) async throws
  func setPushEnabled(groupId: UUID, _ enabled: Bool) async throws -> GroupMembership
  func members(groupId: UUID, cursor: String?) async throws -> GroupMemberPage
  func setRole(groupId: UUID, userId: UUID, role: GroupRole) async throws
  func kick(groupId: UUID, userId: UUID) async throws
  func ban(groupId: UUID, userId: UUID) async throws
  func transferOwnership(groupId: UUID, to userId: UUID) async throws
  func createChannel(groupId: UUID, _ request: CreateGroupChannelRequest) async throws -> GroupChannel
  func updateChannel(id: UUID, _ request: UpdateGroupChannelRequest) async throws -> GroupChannel
  func deleteChannel(id: UUID) async throws
  func messages(channelId: UUID, before: Int64?, after: Int64?, limit: Int?) async throws -> GroupMessagePage
  func send(channelId: UUID, _ request: SendGroupMessageRequest) async throws -> GroupMessage
  func markRead(channelId: UUID, seq: Int64) async throws
  func deleteMessage(id: UUID) async throws
  func reportMessage(id: UUID, _ request: GroupMessageReportRequest) async throws
  func createInviteLink(groupId: UUID, _ request: CreateGroupInviteRequest) async throws -> GroupInviteLink
  func inviteFriends(groupId: UUID, userIds: [UUID]) async throws -> GroupDirectInvitationResponse
  func invitations() async throws -> GroupInvitationList
  func acceptInvitation(id: UUID) async throws -> GroupDetail
  func declineInvitation(id: UUID) async throws
  func invitePreview(code: String) async throws -> GroupInvitePreview
  func redeemInvite(code: String) async throws -> GroupDetail
  /// The live stream, opened fresh on each call.
  func realtime() -> AsyncThrowingStream<GroupsRealtimeSignal, Error>
  /// The signed-in user, to tell their own messages apart.
  func currentUserID() async -> UUID?
}

struct DefaultGroupsService: GroupsServicing {
  let client: GroupsHTTPClient
  let realtimeClient: GroupsRealtimeClient

  init(environmentManager: AppEnvironmentManager) {
    let tokenProvider: @Sendable () async -> String? = { await Container.shared.authSessionStore().authToken }
    self.client = GroupsHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: URLSession.shared,
      authTokenProvider: tokenProvider
    )
    self.realtimeClient = GroupsRealtimeClient(
      baseURL: environmentManager.current.apiBaseUrl,
      authTokenProvider: tokenProvider
    )
  }

  func myGroups() async throws -> GroupListResponse { try await client.myGroups() }
  func create(_ request: CreateGroupRequest) async throws -> GroupDetail { try await client.create(request) }
  func discover(query: String?, ticker: String?, tickers: [String], cursor: String?) async throws -> GroupDirectoryPage {
    try await client.discover(query: query, ticker: ticker, tickers: tickers, cursor: cursor)
  }
  func unreadCount() async throws -> GroupUnreadCount { try await client.unreadCount() }
  func group(id: UUID) async throws -> GroupDetail { try await client.group(id: id) }
  func update(groupId: UUID, _ request: UpdateGroupRequest) async throws -> GroupDetail {
    try await client.update(groupId: groupId, request)
  }
  func delete(groupId: UUID) async throws { try await client.delete(groupId: groupId) }
  func join(groupId: UUID) async throws -> GroupDetail { try await client.join(groupId: groupId) }
  func leave(groupId: UUID) async throws { try await client.leave(groupId: groupId) }
  func setPushEnabled(groupId: UUID, _ enabled: Bool) async throws -> GroupMembership {
    try await client.setPushEnabled(groupId: groupId, enabled)
  }
  func members(groupId: UUID, cursor: String?) async throws -> GroupMemberPage {
    try await client.members(groupId: groupId, cursor: cursor)
  }
  func setRole(groupId: UUID, userId: UUID, role: GroupRole) async throws {
    try await client.setRole(groupId: groupId, userId: userId, role: role)
  }
  func kick(groupId: UUID, userId: UUID) async throws { try await client.kick(groupId: groupId, userId: userId) }
  func ban(groupId: UUID, userId: UUID) async throws { try await client.ban(groupId: groupId, userId: userId) }
  func transferOwnership(groupId: UUID, to userId: UUID) async throws {
    try await client.transferOwnership(groupId: groupId, to: userId)
  }
  func createChannel(groupId: UUID, _ request: CreateGroupChannelRequest) async throws -> GroupChannel {
    try await client.createChannel(groupId: groupId, request)
  }
  func updateChannel(id: UUID, _ request: UpdateGroupChannelRequest) async throws -> GroupChannel {
    try await client.updateChannel(id: id, request)
  }
  func deleteChannel(id: UUID) async throws { try await client.deleteChannel(id: id) }
  func messages(channelId: UUID, before: Int64?, after: Int64?, limit: Int?) async throws -> GroupMessagePage {
    try await client.messages(channelId: channelId, before: before, after: after, limit: limit)
  }
  func send(channelId: UUID, _ request: SendGroupMessageRequest) async throws -> GroupMessage {
    try await client.send(channelId: channelId, request)
  }
  func markRead(channelId: UUID, seq: Int64) async throws { try await client.markRead(channelId: channelId, seq: seq) }
  func deleteMessage(id: UUID) async throws { try await client.deleteMessage(id: id) }
  func reportMessage(id: UUID, _ request: GroupMessageReportRequest) async throws {
    try await client.reportMessage(id: id, request)
  }
  func createInviteLink(groupId: UUID, _ request: CreateGroupInviteRequest) async throws -> GroupInviteLink {
    try await client.createInviteLink(groupId: groupId, request)
  }
  func inviteFriends(groupId: UUID, userIds: [UUID]) async throws -> GroupDirectInvitationResponse {
    try await client.inviteFriends(groupId: groupId, userIds: userIds)
  }
  func invitations() async throws -> GroupInvitationList { try await client.invitations() }
  func acceptInvitation(id: UUID) async throws -> GroupDetail { try await client.acceptInvitation(id: id) }
  func declineInvitation(id: UUID) async throws { try await client.declineInvitation(id: id) }
  func invitePreview(code: String) async throws -> GroupInvitePreview { try await client.invitePreview(code: code) }
  func redeemInvite(code: String) async throws -> GroupDetail { try await client.redeemInvite(code: code) }
  func realtime() -> AsyncThrowingStream<GroupsRealtimeSignal, Error> { realtimeClient.connect() }
  func currentUserID() async -> UUID? { UUID(uuidString: await Container.shared.authSessionStore().currentUserID) }
}
