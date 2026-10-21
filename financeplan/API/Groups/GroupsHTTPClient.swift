import AnyAPI
import Foundation
import OSLog
import StockPlanShared

/// The `code` of the backend's error envelope (`{ error, code, reason }`).
private nonisolated struct GroupsErrorCode: Decodable {
  let code: String
}

nonisolated struct GroupsHTTPClient: Sendable {
  enum Error: HTTPClientError {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)
    /// A 4xx with the server's machine code (`content_rejected`,
    /// `group_full`, `invite_expired`…), read from the error envelope so the
    /// UI never matches on reason text.
    case coded(status: Int, code: String, message: String?)

    nonisolated var errorDescription: String? {
      switch self {
      case .invalidResponse: return "Invalid server response."
      case let .invalidStatus(code): return "Request failed (\(code))."
      case let .unauthorized(message): return message ?? "Your session expired. Please sign in again."
      case let .api(message): return message
      case let .coded(status, _, message): return message ?? "Request failed (\(status))."
      }
    }

    nonisolated var statusCode: Int? {
      switch self {
      case let .invalidStatus(code): return code
      case let .coded(status, _, _): return status
      default: return nil
      }
    }

    /// The server's error code, when it sent one.
    nonisolated var code: String? {
      if case let .coded(_, code, _) = self { return code }
      return nil
    }

    nonisolated static func == (lhs: Error, rhs: Error) -> Bool {
      switch (lhs, rhs) {
      case (.invalidResponse, .invalidResponse): return true
      case let (.invalidStatus(l), .invalidStatus(r)): return l == r
      case let (.unauthorized(l), .unauthorized(r)): return l == r
      case let (.api(l), .api(r)): return l == r
      case let (.coded(ls, lc, lm), .coded(rs, rc, rm)): return ls == rs && lc == rc && lm == rm
      default: return false
      }
    }

    static func makeInvalidResponse() -> Error { .invalidResponse }
    static func makeInvalidStatus(_ code: Int) -> Error { .invalidStatus(code) }
    static func makeUnauthorized(_ message: String?) -> Error { .unauthorized(message) }
    static func makeAPI(_ message: String) -> Error { .api(message) }

    static func makeStatus(_ code: Int, message: String?, body: Data) -> Error {
      if (400..<500).contains(code), let envelope = try? JSONDecoder().decode(GroupsErrorCode.self, from: body),
         !envelope.code.isEmpty {
        return .coded(status: code, code: envelope.code, message: message)
      }
      if let message, !message.isEmpty { return .api(message) }
      return .invalidStatus(code)
    }
  }

  private let client: BaseHTTPClient

  init(
    baseURL: URL,
    session: any HTTPClientSession = URLSession.shared,
    authTokenProvider: @escaping @Sendable () async -> String? = { nil }
  ) {
    self.client = BaseHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: authTokenProvider,
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "GroupsHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func myGroups() async throws -> GroupListResponse {
    try await client.call(ListMyGroupsEndpoint(), errorType: Error.self)
  }

  func create(_ request: CreateGroupRequest) async throws -> GroupDetail {
    try await client.call(CreateGroupEndpoint(payload: request), errorType: Error.self)
  }

  func discover(query: String?, ticker: String?, tickers: [String], cursor: String?) async throws -> GroupDirectoryPage {
    try await client.call(
      DiscoverGroupsEndpoint(query: query, ticker: ticker, tickers: tickers, cursor: cursor),
      errorType: Error.self
    )
  }

  func unreadCount() async throws -> GroupUnreadCount {
    try await client.call(GroupsUnreadCountEndpoint(), errorType: Error.self)
  }

  func group(id: UUID) async throws -> GroupDetail {
    try await client.call(GetGroupEndpoint(groupId: id), errorType: Error.self)
  }

  func update(groupId: UUID, _ request: UpdateGroupRequest) async throws -> GroupDetail {
    try await client.call(UpdateGroupEndpoint(groupId: groupId, payload: request), errorType: Error.self)
  }

  func delete(groupId: UUID) async throws {
    try await client.callWithoutResponse(DeleteGroupEndpoint(groupId: groupId), errorType: Error.self)
  }

  func join(groupId: UUID) async throws -> GroupDetail {
    try await client.call(JoinGroupEndpoint(groupId: groupId), errorType: Error.self)
  }

  func leave(groupId: UUID) async throws {
    try await client.callWithoutResponse(LeaveGroupEndpoint(groupId: groupId), errorType: Error.self)
  }

  func setPushEnabled(groupId: UUID, _ enabled: Bool) async throws -> GroupMembership {
    try await client.call(
      UpdateGroupNotificationsEndpoint(groupId: groupId, payload: GroupNotificationSettingsRequest(pushEnabled: enabled)),
      errorType: Error.self
    )
  }

  func members(groupId: UUID, cursor: String?) async throws -> GroupMemberPage {
    try await client.call(ListGroupMembersEndpoint(groupId: groupId, cursor: cursor), errorType: Error.self)
  }

  func setRole(groupId: UUID, userId: UUID, role: GroupRole) async throws {
    try await client.callWithoutResponse(
      UpdateGroupMemberEndpoint(groupId: groupId, userId: userId, payload: UpdateGroupMemberRequest(role: role)),
      errorType: Error.self
    )
  }

  func kick(groupId: UUID, userId: UUID) async throws {
    try await client.callWithoutResponse(KickGroupMemberEndpoint(groupId: groupId, userId: userId), errorType: Error.self)
  }

  func ban(groupId: UUID, userId: UUID) async throws {
    try await client.callWithoutResponse(
      BanGroupMemberEndpoint(groupId: groupId, payload: GroupBanRequest(userId: userId, reason: nil)),
      errorType: Error.self
    )
  }

  func transferOwnership(groupId: UUID, to userId: UUID) async throws {
    try await client.callWithoutResponse(
      TransferGroupOwnershipEndpoint(groupId: groupId, payload: TransferGroupOwnershipRequest(userId: userId)),
      errorType: Error.self
    )
  }

  func createChannel(groupId: UUID, _ request: CreateGroupChannelRequest) async throws -> GroupChannel {
    try await client.call(CreateGroupChannelEndpoint(groupId: groupId, payload: request), errorType: Error.self)
  }

  func updateChannel(id: UUID, _ request: UpdateGroupChannelRequest) async throws -> GroupChannel {
    try await client.call(UpdateGroupChannelEndpoint(channelId: id, payload: request), errorType: Error.self)
  }

  func deleteChannel(id: UUID) async throws {
    try await client.callWithoutResponse(DeleteGroupChannelEndpoint(channelId: id), errorType: Error.self)
  }

  func messages(channelId: UUID, before: Int64?, after: Int64?, limit: Int?) async throws -> GroupMessagePage {
    try await client.call(
      ListGroupMessagesEndpoint(channelId: channelId, before: before, after: after, limit: limit),
      errorType: Error.self
    )
  }

  func send(channelId: UUID, _ request: SendGroupMessageRequest) async throws -> GroupMessage {
    try await client.call(SendGroupMessageEndpoint(channelId: channelId, payload: request), errorType: Error.self)
  }

  func markRead(channelId: UUID, seq: Int64) async throws {
    try await client.callWithoutResponse(
      MarkGroupChannelReadEndpoint(channelId: channelId, payload: MarkGroupChannelReadRequest(seq: seq)),
      errorType: Error.self
    )
  }

  func deleteMessage(id: UUID) async throws {
    try await client.callWithoutResponse(DeleteGroupMessageEndpoint(messageId: id), errorType: Error.self)
  }

  func reportMessage(id: UUID, _ request: GroupMessageReportRequest) async throws {
    try await client.callWithoutResponse(ReportGroupMessageEndpoint(messageId: id, payload: request), errorType: Error.self)
  }

  func createInviteLink(groupId: UUID, _ request: CreateGroupInviteRequest) async throws -> GroupInviteLink {
    try await client.call(CreateGroupInviteLinkEndpoint(groupId: groupId, payload: request), errorType: Error.self)
  }

  func inviteFriends(groupId: UUID, userIds: [UUID]) async throws -> GroupDirectInvitationResponse {
    try await client.call(
      InviteFriendsToGroupEndpoint(groupId: groupId, payload: GroupDirectInvitationRequest(userIds: userIds)),
      errorType: Error.self
    )
  }

  func invitations() async throws -> GroupInvitationList {
    try await client.call(ListGroupInvitationsEndpoint(), errorType: Error.self)
  }

  func acceptInvitation(id: UUID) async throws -> GroupDetail {
    try await client.call(AcceptGroupInvitationEndpoint(invitationId: id), errorType: Error.self)
  }

  func declineInvitation(id: UUID) async throws {
    try await client.callWithoutResponse(DeclineGroupInvitationEndpoint(invitationId: id), errorType: Error.self)
  }

  func invitePreview(code: String) async throws -> GroupInvitePreview {
    try await client.call(PreviewGroupInviteEndpoint(code: code), errorType: Error.self)
  }

  func redeemInvite(code: String) async throws -> GroupDetail {
    try await client.call(RedeemGroupInviteEndpoint(code: code), errorType: Error.self)
  }
}
