import Foundation
import StockPlanShared
import Factory

protocol BrokerServicing: Sendable {
  func listConnections() async throws -> [BrokerConnectionResponse]
  func getConnection(provider: String) async throws -> BrokerConnectionResponse
  func disconnectIBKR() async throws -> BrokerConnectionResponse
  func previewCsvImport(provider: String, portfolioListId: String?, csvData: Data) async throws -> CsvImportPreviewResponse
  func commitCsvImport(provider: String, portfolioListId: String?, csvData: Data) async throws -> CsvImportCommitResponse
  func previewScreenshotImport(
    provider: String,
    portfolioListId: String?,
    images: [ScreenshotUploadImage]
  ) async throws -> ScreenshotImportPreviewResponse
  func commitScreenshotImport(_ payload: ScreenshotImportCommitRequest) async throws -> CsvImportCommitResponse
}

struct BrokerService: BrokerServicing {
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

  func previewScreenshotImport(
    provider: String,
    portfolioListId: String?,
    images: [ScreenshotUploadImage]
  ) async throws -> ScreenshotImportPreviewResponse {
    try await performAuthenticated { client in
      try await client.previewScreenshotImport(
        provider: provider,
        portfolioListId: portfolioListId,
        images: images
      )
    }
  }

  func commitScreenshotImport(_ payload: ScreenshotImportCommitRequest) async throws -> CsvImportCommitResponse {
    try await performAuthenticated { client in
      try await client.commitScreenshotImport(payload)
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
    _ operation: @Sendable (BrokerHTTPClient) async throws -> T
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
