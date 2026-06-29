import Foundation
import StockPlanShared

nonisolated struct OAuthLinkedAccount: Codable, Equatable, Sendable {
  let provider: OAuthProviderKind
  let connected: Bool
  let email: String?
  let emailVerified: Bool
  let connectedAt: Date?

  init(
    provider: OAuthProviderKind,
    connected: Bool,
    email: String? = nil,
    emailVerified: Bool = false,
    connectedAt: Date? = nil
  ) {
    self.provider = provider
    self.connected = connected
    self.email = email
    self.emailVerified = emailVerified
    self.connectedAt = connectedAt
  }
}

nonisolated struct OAuthLinkedAccountsResponse: Codable, Equatable, Sendable {
  let accounts: [OAuthLinkedAccount]
}

nonisolated struct OAuthLinkResponse: Codable, Equatable, Sendable {
  let provider: OAuthProviderKind
  let connected: Bool
  let email: String?
  let message: String

  init(
    provider: OAuthProviderKind,
    connected: Bool,
    email: String? = nil,
    message: String
  ) {
    self.provider = provider
    self.connected = connected
    self.email = email
    self.message = message
  }
}
