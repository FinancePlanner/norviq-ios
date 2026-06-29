import Foundation
import StockPlanShared

protocol AccountLinkingServiceProtocol: Sendable {
  func linkedAccounts() async throws -> [OAuthLinkedAccount]
  func connect(provider: OAuthProviderKind) async throws -> OAuthLinkResponse
}

final class AccountLinkingService: AccountLinkingServiceProtocol, @unchecked Sendable {
  private let environmentManager: AppEnvironmentManager
  private let session: any HTTPClientSession
  private let authSessionManager: AuthSessionManaging
  private let webAuthenticator: OAuthWebAuthenticating

  init(
    environmentManager: AppEnvironmentManager,
    session: any HTTPClientSession = URLSession.shared,
    authSessionManager: AuthSessionManaging,
    webAuthenticator: OAuthWebAuthenticating = OAuthWebAuthenticator()
  ) {
    self.environmentManager = environmentManager
    self.session = session
    self.authSessionManager = authSessionManager
    self.webAuthenticator = webAuthenticator
  }

  func linkedAccounts() async throws -> [OAuthLinkedAccount] {
    let response: OAuthLinkedAccountsResponse = try await performAuthenticated { client in
      try await client.listLinkedAccounts()
    }
    return response.accounts
  }

  func connect(provider: OAuthProviderKind) async throws -> OAuthLinkResponse {
    let callbackScheme = oauthCallbackScheme(for: provider)
    let redirectURI = oauthRedirectURI(for: provider, callbackScheme: callbackScheme)

    let startResponse: OAuthStartResponsePayload = try await performAuthenticated { client in
      try await client.linkStart(provider: provider, redirectURI: redirectURI)
    }

    guard let authorizationURL = URL(string: startResponse.authorizationURL) else {
      throw OAuthWebAuthenticationError.invalidAuthorizationURL
    }

    let callbackURL = try await webAuthenticator.authenticate(
      url: authorizationURL,
      callbackScheme: callbackScheme
    )

    let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
    guard let code = queryItems.first(where: { $0.name == "code" })?.value,
          !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw OAuthWebAuthenticationError.missingCode
    }
    guard let state = queryItems.first(where: { $0.name == "state" })?.value,
          !state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw OAuthWebAuthenticationError.missingState
    }

    return try await performAuthenticated { client in
      try await client.linkExchange(
        provider: provider,
        request: OAuthExchangeRequestPayload(
          flowId: startResponse.flowId,
          code: code,
          state: state,
          redirectURI: redirectURI
        )
      )
    }
  }

  private func makeClient(forceRefresh: Bool = false) async throws -> AccountLinkingHTTPClient {
    let token = try await resolvedAccessToken(forceRefresh: forceRefresh)
    return AccountLinkingHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: session,
      authTokenProvider: { token }
    )
  }

  private func performAuthenticated<T: Sendable>(
    _ operation: (AccountLinkingHTTPClient) async throws -> T
  ) async throws -> T {
    do {
      let client = try await makeClient()
      return try await operation(client)
    } catch let error as AccountLinkingHTTPClient.Error where error.isUnauthorized {
      do {
        let client = try await makeClient(forceRefresh: true)
        return try await operation(client)
      } catch let retryError as AccountLinkingHTTPClient.Error where retryError.isUnauthorized {
        await authSessionManager.invalidateSession()
        throw retryError
      } catch {
        throw error
      }
    }
  }

  private func resolvedAccessToken(forceRefresh: Bool) async throws -> String {
    let token = forceRefresh
      ? try await authSessionManager.refreshAccessToken()
      : try await authSessionManager.validAccessToken()

    guard let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuthSessionError.notAuthenticated
    }

    return token
  }

  private func oauthCallbackScheme(for provider: OAuthProviderKind) -> String {
    if provider == .google, let reversed = googleReversedClientID() {
      return reversed
    }
    let configured = (Bundle.main.object(forInfoDictionaryKey: "OAuthCallbackScheme") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if let configured, !configured.isEmpty {
      return configured
    }
    return "norviqa"
  }

  private func oauthRedirectURI(for provider: OAuthProviderKind, callbackScheme: String) -> String {
    if provider == .google {
      return "\(callbackScheme):/oauth2redirect"
    }
    if (provider == .x || provider == .apple), let bridge = httpsBridgeURL(for: provider) {
      return bridge
    }
    return "\(callbackScheme)://oauth/callback"
  }

  private func httpsBridgeURL(for provider: OAuthProviderKind) -> String? {
    let host = environmentManager.current.apiBaseUrl.absoluteString
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return "\(host)/v1/auth/oauth/\(provider.rawValue)/callback"
  }

  private func googleReversedClientID() -> String? {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String else {
      return nil
    }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let suffix = ".apps.googleusercontent.com"
    let prefix = trimmed.hasSuffix(suffix) ? String(trimmed.dropLast(suffix.count)) : trimmed
    return "com.googleusercontent.apps.\(prefix)"
  }
}

final class AccountLinkingServiceStub: AccountLinkingServiceProtocol, @unchecked Sendable {
  func linkedAccounts() async throws -> [OAuthLinkedAccount] {
    [
      OAuthLinkedAccount(provider: .apple, connected: false),
      OAuthLinkedAccount(provider: .google, connected: false),
      OAuthLinkedAccount(provider: .x, connected: false)
    ]
  }

  func connect(provider: OAuthProviderKind) async throws -> OAuthLinkResponse {
    OAuthLinkResponse(provider: provider, connected: true, message: "\(provider.displayName) connected.")
  }
}

private extension OAuthProviderKind {
  var displayName: String {
    switch self {
    case .apple: return "Apple"
    case .google: return "Google"
    case .x: return "X"
    @unknown default: return rawValue
    }
  }
}
