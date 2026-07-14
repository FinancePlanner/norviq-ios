import Foundation
import StockPlanShared

protocol PushNotificationsServicing: Sendable {
  func registerDevice(
    deviceToken: String,
    apnsEnvironment: PushAPNSEnvironment,
    authorizationStatus: PushAuthorizationStatus
  )
    async throws -> PushDeviceRegistrationResponse
  func deactivateDevice(deviceToken: String) async throws
  func fetchEarningsPreferences() async throws -> EarningsNotificationPreferencesResponse
  func updateEarningsPreferences(enabled: Bool) async throws -> EarningsNotificationPreferencesResponse
}

struct PushNotificationsService: PushNotificationsServicing, @unchecked Sendable {
  private let environmentManager: AppEnvironmentManager
  private let authSessionManager: AuthSessionManaging
  private let session: PushNotificationsURLSessionProtocol

  init(
    environmentManager: AppEnvironmentManager,
    authSessionManager: AuthSessionManaging,
    session: PushNotificationsURLSessionProtocol = URLSession.shared
  ) {
    self.environmentManager = environmentManager
    self.authSessionManager = authSessionManager
    self.session = session
  }

  func registerDevice(
    deviceToken: String,
    apnsEnvironment: PushAPNSEnvironment,
    authorizationStatus: PushAuthorizationStatus
  )
    async throws -> PushDeviceRegistrationResponse
  {
    let payload = PushDeviceRegistrationRequest(
      deviceToken: deviceToken,
      platform: .ios,
      apnsEnvironment: apnsEnvironment,
      authorizationStatus: authorizationStatus,
      capabilities: ["rebalance_drift_v1"]
    )

    return try await performAuthenticated { client in
      try await client.registerDevice(payload)
    }
  }

  func deactivateDevice(deviceToken: String) async throws {
    let payload = PushDeviceDeactivateRequest(deviceToken: deviceToken)

    _ = try await performAuthenticated { client in
      try await client.deactivateDevice(payload)
    }
  }

  func fetchEarningsPreferences() async throws -> EarningsNotificationPreferencesResponse {
    try await performAuthenticated { client in
      try await client.fetchEarningsPreferences()
    }
  }

  func updateEarningsPreferences(enabled: Bool) async throws -> EarningsNotificationPreferencesResponse {
    let payload = UpdateEarningsNotificationPreferencesRequest(enabled: enabled)
    return try await performAuthenticated { client in
      try await client.updateEarningsPreferences(payload)
    }
  }

  private func performAuthenticated<T: Sendable>(
    _ operation: (PushNotificationsHTTPClient) async throws -> T
  )
    async throws -> T
  {
    do {
      let client = try await makeClient(forceRefresh: false)
      return try await operation(client)
    } catch let error as PushNotificationsHTTPClient.Error where error.isUnauthorized {
      let client = try await makeClient(forceRefresh: true)
      do {
        return try await operation(client)
      } catch let retryError as PushNotificationsHTTPClient.Error where retryError.isUnauthorized {
        await authSessionManager.invalidateSession()
        throw retryError
      }
    }
  }

  private func makeClient(forceRefresh: Bool) async throws -> PushNotificationsHTTPClient {
    let token = try await resolvedAccessToken(forceRefresh: forceRefresh)
    return PushNotificationsHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: session,
      authTokenProvider: { token }
    )
  }

  private func resolvedAccessToken(forceRefresh: Bool) async throws -> String {
    let token = forceRefresh
      ? try await authSessionManager.refreshAccessToken()
      : try await authSessionManager.validAccessToken()

    guard
      let token,
      !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw AuthSessionError.notAuthenticated
    }

    return token
  }
}
