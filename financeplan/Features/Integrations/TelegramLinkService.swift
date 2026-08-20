import Foundation

protocol TelegramLinkServiceProtocol: Sendable {
  func status() async throws -> TelegramStatus
  func createCode() async throws -> TelegramPairingCode
  func disconnect() async throws
  func preferences() async throws -> [TelegramAlertPreference]
  func setAlert(kind: String, enabled: Bool) async throws -> [TelegramAlertPreference]
}

final class TelegramLinkService: TelegramLinkServiceProtocol, @unchecked Sendable {
  private let environmentManager: AppEnvironmentManager
  private let session: any HTTPClientSession
  private let authSessionManager: AuthSessionManaging

  init(
    environmentManager: AppEnvironmentManager,
    session: any HTTPClientSession = URLSession.shared,
    authSessionManager: AuthSessionManaging
  ) {
    self.environmentManager = environmentManager
    self.session = session
    self.authSessionManager = authSessionManager
  }

  func status() async throws -> TelegramStatus {
    try await performAuthenticated { try await $0.status() }
  }

  func createCode() async throws -> TelegramPairingCode {
    try await performAuthenticated { try await $0.createCode() }
  }

  func disconnect() async throws {
    try await performAuthenticated { try await $0.disconnect() }
  }

  func preferences() async throws -> [TelegramAlertPreference] {
    try await performAuthenticated { try await $0.preferences() }
  }

  func setAlert(kind: String, enabled: Bool) async throws -> [TelegramAlertPreference] {
    try await performAuthenticated {
      try await $0.updatePreference(
        TelegramPreferenceUpdate(
          kind: kind,
          enabled: enabled,
          quietHoursStart: nil,
          quietHoursEnd: nil,
          timezone: TimeZone.current.identifier
        )
      )
    }
  }

  private func makeClient(forceRefresh: Bool = false) async throws -> TelegramHTTPClient {
    let token = try await resolvedAccessToken(forceRefresh: forceRefresh)
    return TelegramHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: session,
      authTokenProvider: { token }
    )
  }

  /// Retries once on a 401 with a refreshed token, and only signs the user out
  /// if that also fails.
  private func performAuthenticated<T: Sendable>(
    _ operation: (TelegramHTTPClient) async throws -> T
  ) async throws -> T {
    do {
      let client = try await makeClient()
      return try await operation(client)
    } catch let error as TelegramHTTPClient.Error where error.isUnauthorized {
      do {
        let client = try await makeClient(forceRefresh: true)
        return try await operation(client)
      } catch let retryError as TelegramHTTPClient.Error where retryError.isUnauthorized {
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
}

/// In-memory stand-in for previews and tests.
final class TelegramLinkServiceStub: TelegramLinkServiceProtocol, @unchecked Sendable {
  var statusResult: TelegramStatus
  var codeResult: TelegramPairingCode
  var preferencesResult: [TelegramAlertPreference]

  init(
    statusResult: TelegramStatus = TelegramStatus(
      available: true, connected: false, botUsername: "norviq_bot",
      lastSeenAt: nil, connectedAt: nil
    ),
    codeResult: TelegramPairingCode = TelegramPairingCode(
      code: "ABCD2345",
      expiresAt: Date().addingTimeInterval(900),
      deepLink: "https://t.me/norviq_bot?start=ABCD2345"
    ),
    preferencesResult: [TelegramAlertPreference] = []
  ) {
    self.statusResult = statusResult
    self.codeResult = codeResult
    self.preferencesResult = preferencesResult
  }

  func status() async throws -> TelegramStatus { statusResult }
  func createCode() async throws -> TelegramPairingCode { codeResult }
  func disconnect() async throws { statusResult = TelegramStatus(
    available: true, connected: false, botUsername: statusResult.botUsername,
    lastSeenAt: nil, connectedAt: nil
  ) }
  func preferences() async throws -> [TelegramAlertPreference] { preferencesResult }
  func setAlert(kind: String, enabled: Bool) async throws -> [TelegramAlertPreference] {
    preferencesResult = preferencesResult.map { pref in
      pref.kind == kind
        ? TelegramAlertPreference(
            kind: pref.kind, enabled: enabled,
            quietHoursStart: pref.quietHoursStart, quietHoursEnd: pref.quietHoursEnd,
            timezone: pref.timezone
          )
        : pref
    }
    return preferencesResult
  }
}
