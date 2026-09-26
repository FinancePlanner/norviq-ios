import AnyAPI
import Foundation
import OSLog
import StockPlanShared

nonisolated struct SocialHTTPClient: Sendable {
  enum Error: HTTPClientError {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)

    nonisolated var errorDescription: String? {
      switch self {
      case .invalidResponse: return "Invalid server response."
      case let .invalidStatus(code): return "Request failed (\(code))."
      case let .unauthorized(message): return message ?? "Your session expired. Please sign in again."
      case let .api(message): return message
      }
    }

    nonisolated var statusCode: Int? {
      if case let .invalidStatus(code) = self { return code }
      return nil
    }

    nonisolated static func == (lhs: Error, rhs: Error) -> Bool {
      switch (lhs, rhs) {
      case (.invalidResponse, .invalidResponse): return true
      case let (.invalidStatus(l), .invalidStatus(r)): return l == r
      case let (.unauthorized(l), .unauthorized(r)): return l == r
      case let (.api(l), .api(r)): return l == r
      default: return false
      }
    }

    static func makeInvalidResponse() -> Error { .invalidResponse }
    static func makeInvalidStatus(_ code: Int) -> Error { .invalidStatus(code) }
    static func makeUnauthorized(_ message: String?) -> Error { .unauthorized(message) }
    static func makeAPI(_ message: String) -> Error { .api(message) }
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
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "SocialHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func config() async throws -> SocialConfig {
    try await client.call(GetSocialConfigEndpoint(), errorType: Error.self)
  }

  func searchUsers(query: String) async throws -> UserSearchResponse {
    try await client.call(SearchSocialUsersEndpoint(query: query), errorType: Error.self)
  }

  func profile(userId: String) async throws -> SocialProfile {
    try await client.call(GetSocialProfileEndpoint(userId: userId), errorType: Error.self)
  }

  func friends() async throws -> FriendsListResponse {
    try await client.call(GetFriendsEndpoint(), errorType: Error.self)
  }

  func removeFriend(userId: String) async throws {
    try await client.callWithoutResponse(RemoveFriendEndpoint(userId: userId), errorType: Error.self)
  }

  func friendRequests() async throws -> FriendRequestsResponse {
    try await client.call(GetFriendRequestsEndpoint(), errorType: Error.self)
  }

  func sendFriendRequest(userId: String) async throws -> FriendRequest {
    try await client.call(
      SendFriendRequestEndpoint(payload: SendFriendRequestRequest(userId: userId)),
      errorType: Error.self
    )
  }

  func respond(to requestId: String, accept: Bool) async throws {
    try await client.callWithoutResponse(
      RespondFriendRequestEndpoint(requestId: requestId, action: accept ? .accept : .decline),
      errorType: Error.self
    )
  }

  func cancelFriendRequest(requestId: String) async throws {
    try await client.callWithoutResponse(CancelFriendRequestEndpoint(requestId: requestId), errorType: Error.self)
  }

  func createInvite() async throws -> InviteLink {
    try await client.call(CreateInviteEndpoint(), errorType: Error.self)
  }

  func invitePreview(code: String) async throws -> SocialUserSummary {
    try await client.call(GetInviteEndpoint(code: code), errorType: Error.self)
  }

  func redeemInvite(code: String) async throws -> InviteRedeemResponse {
    try await client.call(RedeemInviteEndpoint(code: code), errorType: Error.self)
  }

  func privacy() async throws -> SocialPrivacySettings {
    try await client.call(GetSocialPrivacyEndpoint(), errorType: Error.self)
  }

  func updatePrivacy(_ settings: SocialPrivacySettings) async throws -> SocialPrivacySettings {
    try await client.call(UpdateSocialPrivacyEndpoint(payload: settings), errorType: Error.self)
  }

  func blockedUsers() async throws -> BlockedUsersResponse {
    try await client.call(GetBlockedUsersEndpoint(), errorType: Error.self)
  }

  func setBlocked(userId: String, blocked: Bool) async throws {
    try await client.callWithoutResponse(SetBlockEndpoint(userId: userId, blocked: blocked), errorType: Error.self)
  }

  func report(_ request: ReportRequest) async throws {
    try await client.callWithoutResponse(SubmitReportEndpoint(payload: request), errorType: Error.self)
  }
}
