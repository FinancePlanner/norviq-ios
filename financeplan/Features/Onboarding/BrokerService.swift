import Foundation
import StockPlanShared
import Factory

enum BrokerConnectionAuthError: LocalizedError {
  case invalidAuthorizationURL
  case cancelled
  case failed(String)

  var errorDescription: String? {
    switch self {
    case .invalidAuthorizationURL:
      return "Broker authorization URL is invalid."
    case .cancelled:
      return "Broker connection was cancelled."
    case let .failed(message):
      return message
    }
  }
}

protocol BrokerServicing {
  func listConnections() async throws -> [BrokerConnectionResponse]
  func getConnection(provider: String) async throws -> BrokerConnectionResponse
  @MainActor
  func connectIBKR(portfolioListId: String?) async throws -> BrokerConnectionResponse
  func syncIBKR() async throws -> BrokerSyncResponse
  func disconnectIBKR() async throws -> BrokerConnectionResponse
  func previewCsvImport(provider: String, portfolioListId: String?, csvData: Data) async throws -> CsvImportPreviewResponse
  func commitCsvImport(provider: String, portfolioListId: String?, csvData: Data) async throws -> CsvImportCommitResponse
}

struct BrokerService: BrokerServicing {
  private let environmentManager: AppEnvironmentManager
  private let authSessionManager: AuthSessionManaging
  private let session: any HTTPClientSession
  private let webAuthenticator: OAuthWebAuthenticating

  init(
    environmentManager: AppEnvironmentManager,
    authSessionManager: AuthSessionManaging,
    session: any HTTPClientSession = URLSession.shared,
    webAuthenticator: OAuthWebAuthenticating = OAuthWebAuthenticator()
  ) {
    self.environmentManager = environmentManager
    self.authSessionManager = authSessionManager
    self.session = session
    self.webAuthenticator = webAuthenticator
  }

  func listConnections() async throws -> [BrokerConnectionResponse] {
    try await performAuthenticated { client in
      try await client.getBrokers()
    }
  }

  func getConnection(provider: String) async throws -> BrokerConnectionResponse {
    try await performAuthenticated { client in
      try await client.getBroker(provider: provider)
    }
  }

  @MainActor
  func connectIBKR(portfolioListId: String?) async throws -> BrokerConnectionResponse {
    let callbackScheme = oauthCallbackScheme()
    let redirectURI = brokerRedirectURI(for: callbackScheme)

    let startResponse = try await performAuthenticated { client in
      try await client.startIBKRConnect(
        redirectURI: redirectURI,
        portfolioListId: portfolioListId
      )
    }

    guard let authorizationURL = URL(string: startResponse.authorizationURL) else {
      throw BrokerConnectionAuthError.invalidAuthorizationURL
    }

    let callbackURL: URL
    do {
      callbackURL = try await webAuthenticator.authenticate(
        url: authorizationURL,
        callbackScheme: callbackScheme
      )
    } catch let error as OAuthWebAuthenticationError {
      switch error {
      case .cancelled:
        throw BrokerConnectionAuthError.cancelled
      default:
        throw error
      }
    }

    let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
    let queryItems = components?.queryItems ?? []
    let status = queryItems.first(where: { $0.name == "status" })?.value?.lowercased()
    if status != "success" {
      let message = queryItems.first(where: { $0.name == "error" })?.value ?? "Broker connection failed."
      throw BrokerConnectionAuthError.failed(message)
    }

    return try await getConnection(provider: "ibkr")
  }

  func syncIBKR() async throws -> BrokerSyncResponse {
    try await performAuthenticated { client in
      try await client.syncIBKR()
    }
  }

  func disconnectIBKR() async throws -> BrokerConnectionResponse {
    try await performAuthenticated { client in
      try await client.disconnectIBKR()
    }
  }

  func previewCsvImport(
    provider: String,
    portfolioListId: String?,
    csvData: Data
  ) async throws -> CsvImportPreviewResponse {
    try await performAuthenticated { client in
      try await client.previewCsvImport(
        provider: provider,
        portfolioListId: portfolioListId,
        csvData: csvData
      )
    }
  }

  func commitCsvImport(
    provider: String,
    portfolioListId: String?,
    csvData: Data
  ) async throws -> CsvImportCommitResponse {
    try await performAuthenticated { client in
      try await client.commitCsvImport(
        provider: provider,
        portfolioListId: portfolioListId,
        csvData: csvData
      )
    }
  }

  private func performAuthenticated<T: Sendable>(
    _ operation: (BrokerHTTPClient) async throws -> T
  ) async throws -> T {
    do {
      let client = try await makeClient()
      return try await operation(client)
    } catch let error as BrokerHTTPClient.Error where error.isUnauthorized {
      let refreshedClient = try await makeClient(forceRefresh: true)
      do {
        return try await operation(refreshedClient)
      } catch let retryError as BrokerHTTPClient.Error where retryError.isUnauthorized {
        await authSessionManager.invalidateSession()
        throw retryError
      }
    }
  }

  private func makeClient(forceRefresh: Bool = false) async throws -> BrokerHTTPClient {
    let token = try await resolvedAccessToken(forceRefresh: forceRefresh)
    return BrokerHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: session,
      authTokenProvider: { token }
    )
  }

  private func resolvedAccessToken(forceRefresh: Bool) async throws -> String {
    if forceRefresh {
      guard let token = try await authSessionManager.refreshAccessToken(),
            !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw AuthSessionError.notAuthenticated
      }
      return token
    }

    guard let token = try await authSessionManager.validAccessToken(),
          !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuthSessionError.notAuthenticated
    }
    return token
  }

  private func oauthCallbackScheme() -> String {
    let configured = (Bundle.main.object(forInfoDictionaryKey: "OAuthCallbackScheme") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if let configured, !configured.isEmpty {
      return configured
    }
    return "norviqa"
  }

  private func brokerRedirectURI(for callbackScheme: String) -> String {
    "\(callbackScheme)://oauth/broker-callback"
  }
}

