import Factory
import Foundation
import StockPlanShared

protocol SocialServicing: Sendable {
  func config() async throws -> SocialConfig
  func searchUsers(query: String) async throws -> [SocialUserSummary]
  func profile(userId: String) async throws -> SocialProfile
  func friends() async throws -> [SocialUserSummary]
  func removeFriend(userId: String) async throws
  func friendRequests() async throws -> FriendRequestsResponse
  func sendFriendRequest(userId: String) async throws -> FriendRequest
  func respond(to requestId: String, accept: Bool) async throws
  func cancelFriendRequest(requestId: String) async throws
  func createInvite() async throws -> InviteLink
  func invitePreview(code: String) async throws -> SocialUserSummary
  func redeemInvite(code: String) async throws -> InviteRedeemResponse
  func privacy() async throws -> SocialPrivacySettings
  func updatePrivacy(_ settings: SocialPrivacySettings) async throws -> SocialPrivacySettings
  func blockedUsers() async throws -> [SocialUserSummary]
  func setBlocked(userId: String, blocked: Bool) async throws
  func report(_ request: ReportRequest) async throws
  func matchContacts(_ request: ContactMatchRequest) async throws -> [ContactMatch]
  func startXImport(redirectURI: String) async throws -> OAuthStartResponsePayload
  func finishXImport(_ request: OAuthExchangeRequestPayload) async throws -> XImportMatchesResponse
  func importFacebookFriends(_ request: FacebookLimitedLoginRequest) async throws -> FacebookImportMatchesResponse
  func disconnectFacebook() async throws
}

struct DefaultSocialService: SocialServicing {
  let client: SocialHTTPClient

  init(environmentManager: AppEnvironmentManager) {
    self.client = SocialHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: URLSession.shared,
      authTokenProvider: { await Container.shared.authSessionStore().authToken }
    )
  }

  func config() async throws -> SocialConfig { try await client.config() }
  func searchUsers(query: String) async throws -> [SocialUserSummary] { try await client.searchUsers(query: query).users }
  func profile(userId: String) async throws -> SocialProfile { try await client.profile(userId: userId) }
  func friends() async throws -> [SocialUserSummary] { try await client.friends().friends }
  func removeFriend(userId: String) async throws { try await client.removeFriend(userId: userId) }
  func friendRequests() async throws -> FriendRequestsResponse { try await client.friendRequests() }
  func sendFriendRequest(userId: String) async throws -> FriendRequest { try await client.sendFriendRequest(userId: userId) }
  func respond(to requestId: String, accept: Bool) async throws { try await client.respond(to: requestId, accept: accept) }
  func cancelFriendRequest(requestId: String) async throws { try await client.cancelFriendRequest(requestId: requestId) }
  func createInvite() async throws -> InviteLink { try await client.createInvite() }
  func invitePreview(code: String) async throws -> SocialUserSummary { try await client.invitePreview(code: code) }
  func redeemInvite(code: String) async throws -> InviteRedeemResponse { try await client.redeemInvite(code: code) }
  func privacy() async throws -> SocialPrivacySettings { try await client.privacy() }
  func updatePrivacy(_ settings: SocialPrivacySettings) async throws -> SocialPrivacySettings {
    try await client.updatePrivacy(settings)
  }
  func blockedUsers() async throws -> [SocialUserSummary] { try await client.blockedUsers().users }
  func setBlocked(userId: String, blocked: Bool) async throws { try await client.setBlocked(userId: userId, blocked: blocked) }
  func report(_ request: ReportRequest) async throws { try await client.report(request) }
  func matchContacts(_ request: ContactMatchRequest) async throws -> [ContactMatch] {
    try await client.matchContacts(request).matches
  }
  func startXImport(redirectURI: String) async throws -> OAuthStartResponsePayload {
    try await client.startXImport(redirectURI: redirectURI)
  }
  func finishXImport(_ request: OAuthExchangeRequestPayload) async throws -> XImportMatchesResponse {
    try await client.finishXImport(request)
  }
  func importFacebookFriends(_ request: FacebookLimitedLoginRequest) async throws -> FacebookImportMatchesResponse {
    try await client.importFacebookFriends(request)
  }
  func disconnectFacebook() async throws { try await client.disconnectFacebook() }
}
