import Foundation
import StockPlanShared

protocol StockServicing {
  @discardableResult
  func create(stock: StockRequest) async throws -> StockResponse
  @discardableResult
  func bulkCreate(stocks: [StockRequest]) async throws -> BulkCreateStocksResponse
  func fetchPortfolio() async throws -> [StockResponse]
  func updateStock(_ stock: StockResponse) async throws -> StockResponse
  func delete(id: String) async throws
}

final class StockService: StockServicing {
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

  @discardableResult
  func create(stock: StockRequest) async throws -> StockResponse {
    try await performAuthenticated { client in
      let endpoint = CreateStockEndpoint(
        symbol: stock.symbol,
        shares: stock.shares,
        buyPrice: stock.buyPrice,
        buyDate: stock.buyDate,
        notes: stock.notes
      )
      return try await client.call(endpoint)
    }
  }

  @discardableResult
  func bulkCreate(stocks: [StockRequest]) async throws -> BulkCreateStocksResponse {
    try await performAuthenticated { client in
      let endpoint = BulkCreateStocksEndpoint(stocks: stocks)
      return try await client.call(endpoint)
    }
  }
  
  func fetchPortfolio() async throws -> [StockResponse] {
    try await performAuthenticated { client in
      let endpoint = GetStocksEndpoint()
      return try await client.call(endpoint)
    }
  }

  func updateStock(_ stock: StockResponse) async throws -> StockResponse {
    try await performAuthenticated { client in
      let request = StockRequest(
        symbol: stock.symbol,
        shares: stock.shares,
        buyPrice: stock.buyPrice,
        buyDate: stock.buyDate,
        notes: stock.notes ?? ""
      )
      let endpoint = UpdateStockEndpoint(stockId: stock.id, payload: request)
      return try await client.call(endpoint)
    }
  }

  func delete(id: String) async throws {
    try await performAuthenticated { client in
      let endpoint = DeleteStockEndpoint(stockId: id)
      try await client.callWithoutResponse(endpoint)
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
  
  private func performAuthenticated<T>(
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
