import Foundation
import StockPlanShared

protocol PlanningServicing: Sendable {
  func prefill() async throws -> PlanningPrefill
  func project(_ request: GrowthProjectionRequest) async throws -> GrowthProjectionResponse
  func retirement(_ request: RetirementPlanningRequest) async throws -> RetirementPlanningResponse
  func scenarios() async throws -> [PlanningScenario]
  func save(_ request: PlanningScenarioUpsertRequest) async throws -> PlanningScenario
}

final class PlanningService: PlanningServicing, Sendable {
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

  func prefill() async throws -> PlanningPrefill {
    try await authenticated { try await $0.call(PlanningPrefillEndpoint()) }
  }

  func project(_ request: GrowthProjectionRequest) async throws -> GrowthProjectionResponse {
    try await authenticated { try await $0.call(GrowthProjectionEndpoint(payload: request)) }
  }

  func retirement(_ request: RetirementPlanningRequest) async throws -> RetirementPlanningResponse {
    try await authenticated { try await $0.call(RetirementPlanningEndpoint(payload: request)) }
  }

  func scenarios() async throws -> [PlanningScenario] {
    try await authenticated { try await $0.call(ListPlanningScenariosEndpoint()) }
  }

  func save(_ request: PlanningScenarioUpsertRequest) async throws -> PlanningScenario {
    try await authenticated { try await $0.call(CreatePlanningScenarioEndpoint(payload: request)) }
  }

  private func authenticated<T: Sendable>(_ operation: (StockHTTPClient) async throws -> T) async throws -> T {
    do {
      return try await operation(client())
    } catch let error as StockHTTPClient.Error where error.isUnauthorized {
      do {
        return try await operation(client(forceRefresh: true))
      } catch let retry as StockHTTPClient.Error where retry.isUnauthorized {
        await authSessionManager.invalidateSession()
        throw retry
      }
    }
  }

  private func client(forceRefresh: Bool = false) async throws -> StockHTTPClient {
    let token = forceRefresh
      ? try await authSessionManager.refreshAccessToken()
      : try await authSessionManager.validAccessToken()
    guard let token, !token.isEmpty else { throw AuthSessionError.notAuthenticated }
    return StockHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: session,
      authTokenProvider: { token }
    )
  }
}
