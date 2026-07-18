import Factory
import Foundation
import StockPlanShared

protocol BankServicing: Sendable {
  func createLinkSession() async throws -> BankLinkSessionResponse
  func exchange(publicToken: String, institutionId: String?, institutionName: String?) async throws -> BankConnectionResponse
  func listConnections() async throws -> [BankConnectionResponse]
  func disconnect(connectionId: String) async throws
  func sync(connectionId: String) async throws -> BankSyncResponse
  func listSuggestedTransactions() async throws -> [BankTransactionResponse]
  func importTransaction(transactionId: String, pillar: BudgetPillar, categoryId: String?, titleOverride: String?) async throws -> ExpenseResponse
  func dismiss(transactionId: String) async throws
}

struct BankService: BankServicing {
  private let environmentManager: AppEnvironmentManager
  private let authSessionManager: AuthSessionManaging
  private let session: any HTTPClientSession

  init(
    environmentManager: AppEnvironmentManager,
    authSessionManager: AuthSessionManaging,
    session: any HTTPClientSession = URLSession.shared
  ) {
    self.environmentManager = environmentManager
    self.authSessionManager = authSessionManager
    self.session = session
  }

  func createLinkSession() async throws -> BankLinkSessionResponse {
    try await performAuthenticated { try await $0.createLinkSession() }
  }

  func exchange(publicToken: String, institutionId: String?, institutionName: String?) async throws -> BankConnectionResponse {
    try await performAuthenticated { try await $0.exchange(publicToken: publicToken, institutionId: institutionId, institutionName: institutionName) }
  }

  func listConnections() async throws -> [BankConnectionResponse] {
    try await performAuthenticated { try await $0.listConnections() }
  }

  func disconnect(connectionId: String) async throws {
    try await performAuthenticated { try await $0.disconnect(connectionId: connectionId) }
  }

  func sync(connectionId: String) async throws -> BankSyncResponse {
    try await performAuthenticated { try await $0.sync(connectionId: connectionId) }
  }

  func listSuggestedTransactions() async throws -> [BankTransactionResponse] {
    try await performAuthenticated { try await $0.listTransactions(status: BankTransactionStatus.suggested.rawValue) }
  }

  func importTransaction(transactionId: String, pillar: BudgetPillar, categoryId: String?, titleOverride: String?) async throws -> ExpenseResponse {
    try await performAuthenticated { try await $0.importTransaction(transactionId: transactionId, pillar: pillar, categoryId: categoryId, titleOverride: titleOverride) }
  }

  func dismiss(transactionId: String) async throws {
    try await performAuthenticated { try await $0.dismiss(transactionId: transactionId) }
  }

  private func performAuthenticated<T: Sendable>(
    _ operation: @Sendable (BankHTTPClient) async throws -> T
  ) async throws -> T {
    do {
      let client = try await makeClient()
      return try await operation(client)
    } catch let error as BankHTTPClient.Error where error.isUnauthorized {
      let refreshedClient = try await makeClient(forceRefresh: true)
      do {
        return try await operation(refreshedClient)
      } catch let retryError as BankHTTPClient.Error where retryError.isUnauthorized {
        await authSessionManager.invalidateSession()
        throw retryError
      }
    }
  }

  private func makeClient(forceRefresh: Bool = false) async throws -> BankHTTPClient {
    let token = try await resolvedAccessToken(forceRefresh: forceRefresh)
    return BankHTTPClient(
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
}
