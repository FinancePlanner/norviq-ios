import Foundation
import StockPlanShared
import Factory

protocol BrokerServicing {
  func listConnections() async throws -> [BrokerConnectionResponse]
  func getConnection(provider: String) async throws -> BrokerConnectionResponse
  func syncIBKR() async throws -> BrokerSyncResponse
  func previewCsvImport(provider: String, portfolioListId: String?, csvData: Data) async throws -> CsvImportPreviewResponse
  func commitCsvImport(provider: String, portfolioListId: String?, csvData: Data) async throws -> CsvImportCommitResponse
}

struct BrokerService: BrokerServicing {
  private let environmentManager: AppEnvironmentManager
  private let authSessionManager: AuthSessionManaging
  private let session: BrokerURLSessionProtocol

  init(
    environmentManager: AppEnvironmentManager,
    authSessionManager: AuthSessionManaging,
    session: BrokerURLSessionProtocol = URLSession.shared
  ) {
    self.environmentManager = environmentManager
    self.authSessionManager = authSessionManager
    self.session = session
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

  func syncIBKR() async throws -> BrokerSyncResponse {
    try await performAuthenticated { client in
      try await client.syncIBKR()
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

  private func performAuthenticated<T>(
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
}

struct BrokerServiceStub: BrokerServicing {
  func listConnections() async throws -> [BrokerConnectionResponse] { [] }

  func getConnection(provider: String) async throws -> BrokerConnectionResponse {
    BrokerConnectionResponse(id: UUID().uuidString, provider: provider, status: "disconnected")
  }

  func syncIBKR() async throws -> BrokerSyncResponse {
    BrokerSyncResponse(runId: UUID().uuidString, status: "accepted")
  }

  func previewCsvImport(
    provider: String,
    portfolioListId: String?,
    csvData: Data
  ) async throws -> CsvImportPreviewResponse {
    CsvImportPreviewResponse(provider: provider, items: [], errors: [])
  }

  func commitCsvImport(
    provider: String,
    portfolioListId: String?,
    csvData: Data
  ) async throws -> CsvImportCommitResponse {
    CsvImportCommitResponse(provider: provider, inserted: [], updated: [], errors: [])
  }
}
