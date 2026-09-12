import Foundation
import StockPlanShared

protocol PortfolioSimulationServicing: Sendable {
  func list() async throws -> [PortfolioSimulation]
  func detail(simulationId: String) async throws -> PortfolioSimulation
  func create(_ input: PortfolioSimulationUpsertRequest) async throws -> PortfolioSimulation
  func update(simulationId: String, input: PortfolioSimulationUpsertRequest) async throws -> PortfolioSimulation
  func delete(simulationId: String) async throws
  func preview(_ input: PortfolioSimulationUpsertRequest) async throws -> PortfolioSimulationResult
  func compute(simulationId: String, capitalOverride: Double?) async throws -> PortfolioSimulationResult
  func portfolios() async throws -> [PortfolioListDTOResponse]
}

final class PortfolioSimulationService: PortfolioSimulationServicing, Sendable {
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

  func list() async throws -> [PortfolioSimulation] {
    try await authenticated { try await $0.call(ListPortfolioSimulationsEndpoint()) }.items
  }

  func detail(simulationId: String) async throws -> PortfolioSimulation {
    try await authenticated { try await $0.call(GetPortfolioSimulationEndpoint(simulationId: simulationId)) }
  }

  func create(_ input: PortfolioSimulationUpsertRequest) async throws -> PortfolioSimulation {
    try await authenticated { try await $0.call(CreatePortfolioSimulationEndpoint(payload: input)) }
  }

  func update(simulationId: String, input: PortfolioSimulationUpsertRequest) async throws -> PortfolioSimulation {
    try await authenticated {
      try await $0.call(UpdatePortfolioSimulationEndpoint(simulationId: simulationId, payload: input))
    }
  }

  func delete(simulationId: String) async throws {
    _ = try await authenticated { try await $0.call(DeletePortfolioSimulationEndpoint(simulationId: simulationId)) }
  }

  func preview(_ input: PortfolioSimulationUpsertRequest) async throws -> PortfolioSimulationResult {
    try await authenticated { try await $0.call(PreviewPortfolioSimulationEndpoint(payload: input)) }
  }

  func compute(simulationId: String, capitalOverride: Double?) async throws -> PortfolioSimulationResult {
    try await authenticated {
      try await $0.call(ComputePortfolioSimulationEndpoint(
        simulationId: simulationId,
        payload: PortfolioSimulationComputeRequest(targetCapitalOverride: capitalOverride)
      ))
    }
  }

  func portfolios() async throws -> [PortfolioListDTOResponse] {
    try await authenticated { try await $0.call(GetPortfolioListsEndpoint()) }
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
