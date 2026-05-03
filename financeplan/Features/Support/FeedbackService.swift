import Foundation
import StockPlanShared

protocol FeedbackServicing: Sendable {
  func submitFeedback(topic: String, message: String) async throws -> FeedbackResponse
}

final class FeedbackService: FeedbackServicing, @unchecked Sendable {
  private let environmentManager: AppEnvironmentManager
  private let session: StockURLSessionProtocol
  private let authSessionManager: AuthSessionManaging

  init(
    environmentManager: AppEnvironmentManager,
    session: StockURLSessionProtocol = URLSession.shared,
    authSessionManager: AuthSessionManaging
  ) {
    self.environmentManager = environmentManager
    self.session = session
    self.authSessionManager = authSessionManager
  }

  func submitFeedback(topic: String, message: String) async throws -> FeedbackResponse {
    try await performAuthenticated { client in
      let payload = FeedbackRequest(topic: topic, message: message)
      let endpoint = SubmitFeedbackEndpoint(payload: payload)
      return try await client.call(endpoint)
    }
  }

  private func makeClient(forceRefresh: Bool = false) async throws -> StockHTTPClient {
    let token = try await resolvedAccessToken(forceRefresh: forceRefresh)
    return StockHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: session,
      authTokenProvider: { token }
    )
  }

  private func performAuthenticated<T: Sendable>(
    _ operation: (StockHTTPClient) async throws -> T
  ) async throws -> T {
    do {
      let client = try await makeClient()
      return try await operation(client)
    } catch let error as StockHTTPClient.Error where error.isUnauthorized {
      let refreshedClient = try await makeClient(forceRefresh: true)

      do {
        return try await operation(refreshedClient)
      } catch let retryError as StockHTTPClient.Error where retryError.isUnauthorized {
        await authSessionManager.invalidateSession()
        throw retryError
      }
    }
  }

  private func resolvedAccessToken(forceRefresh: Bool = false) async throws -> String {
    if forceRefresh {
      guard let token = try await authSessionManager.refreshAccessToken(),
            !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw AuthSessionError.notAuthenticated
      }
      return token
    } else {
      guard let token = try await authSessionManager.validAccessToken(),
            !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw AuthSessionError.notAuthenticated
      }
      return token
    }
  }
}
