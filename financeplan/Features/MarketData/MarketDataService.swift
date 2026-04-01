import Foundation
import StockPlanShared

protocol MarketDataServicing {
  func fetchCompanyProfile(symbol: String) async throws -> CompanyProfileResponse
  func fetchQuote(symbol: String) async throws -> QuoteResponse
}

final class MarketDataHTTPService: MarketDataServicing {
  private let environmentManager: AppEnvironmentManager
  private let session: MarketDataURLSessionProtocol
  private let authSessionManager: AuthSessionManaging

  init(
    environmentManager: AppEnvironmentManager,
    session: MarketDataURLSessionProtocol = URLSession.shared,
    authSessionManager: AuthSessionManaging
  ) {
    self.environmentManager = environmentManager
    self.session = session
    self.authSessionManager = authSessionManager
  }

  func fetchCompanyProfile(symbol: String) async throws -> CompanyProfileResponse {
    try await performAuthenticated { client in
      try await client.fetchCompanyProfile(symbol: symbol)
    }
  }

  func fetchQuote(symbol: String) async throws -> QuoteResponse {
    try await performAuthenticated { client in
      try await client.fetchQuote(symbol: symbol)
    }
  }

  private func makeClient(forceRefresh: Bool = false) async throws -> MarketDataHTTPClient {
    let token = try await resolvedAccessToken(forceRefresh: forceRefresh)
    return MarketDataHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: session,
      authTokenProvider: { token }
    )
  }

  private func performAuthenticated<T>(
    _ operation: (MarketDataHTTPClient) async throws -> T
  ) async throws -> T {
    do {
      let client = try await makeClient()
      return try await operation(client)
    } catch let error as MarketDataHTTPClient.Error where error.isUnauthorized {
      do {
        let client = try await makeClient(forceRefresh: true)
        return try await operation(client)
      } catch let retryError as MarketDataHTTPClient.Error where retryError.isUnauthorized {
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

struct MarketDataServiceStub: MarketDataServicing {
  func fetchCompanyProfile(symbol _: String) async throws -> CompanyProfileResponse {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchQuote(symbol _: String) async throws -> QuoteResponse {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }
}
