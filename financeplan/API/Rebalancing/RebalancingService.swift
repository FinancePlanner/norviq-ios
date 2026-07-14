import Foundation
import StockPlanShared

protocol RebalancingServicing: Sendable {
  func models(portfolioId: String) async throws -> [AllocationModel]
  func createModel(portfolioId: String, request: AllocationModelUpsertRequest) async throws -> AllocationModel
  func updateModel(portfolioId: String, modelId: String, request: AllocationModelUpsertRequest) async throws -> AllocationModel
  func overview(portfolioId: String) async throws -> RebalancingOverview
  func simulate(portfolioId: String, request: RebalancingSimulationRequest) async throws -> RebalancingSimulation
  func plans(portfolioId: String) async throws -> [RebalancePlan]
  func createPlan(portfolioId: String, request: RebalancePlanCreateRequest) async throws -> RebalancePlan
  func completePlan(portfolioId: String, planId: String, note: String?) async throws -> RebalancePlan
  func history(portfolioId: String) async throws -> RebalancingHistorySummary
  func preferences(portfolioId: String) async throws -> RebalancingNotificationPreferences
  func updatePreferences(portfolioId: String, enabled: Bool) async throws -> RebalancingNotificationPreferences
  func alerts() async throws -> [RebalancingAlert]
  func acknowledge(alertId: String) async throws -> RebalancingAlert
}

final class RebalancingService: RebalancingServicing, Sendable {
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

  func models(portfolioId: String) async throws -> [AllocationModel] {
    try await authenticated { try await $0.call(RebalancingModelsEndpoint(portfolioId: portfolioId)) }
  }

  func createModel(portfolioId: String, request: AllocationModelUpsertRequest) async throws -> AllocationModel {
    try await authenticated { try await $0.call(
      CreateRebalancingModelEndpoint(portfolioId: portfolioId, payload: request)
    ) }
  }

  func updateModel(portfolioId: String, modelId: String, request: AllocationModelUpsertRequest) async throws -> AllocationModel {
    try await authenticated { try await $0.call(
      UpdateRebalancingModelEndpoint(portfolioId: portfolioId, modelId: modelId, payload: request)
    ) }
  }

  func overview(portfolioId: String) async throws -> RebalancingOverview {
    try await authenticated { try await $0.call(RebalancingOverviewEndpoint(portfolioId: portfolioId)) }
  }

  func simulate(portfolioId: String, request: RebalancingSimulationRequest) async throws -> RebalancingSimulation {
    try await authenticated { try await $0.call(
      RebalancingSimulationEndpoint(portfolioId: portfolioId, payload: request)
    ) }
  }

  func plans(portfolioId: String) async throws -> [RebalancePlan] {
    try await authenticated { try await $0.call(RebalancingPlansEndpoint(portfolioId: portfolioId)) }
  }

  func createPlan(portfolioId: String, request: RebalancePlanCreateRequest) async throws -> RebalancePlan {
    try await authenticated { try await $0.call(
      CreateRebalancingPlanEndpoint(portfolioId: portfolioId, payload: request)
    ) }
  }

  func completePlan(portfolioId: String, planId: String, note: String?) async throws -> RebalancePlan {
    try await authenticated { try await $0.call(CompleteRebalancingPlanEndpoint(
      portfolioId: portfolioId,
      planId: planId,
      payload: RebalancePlanCompletionRequest(note: note)
    )) }
  }

  func history(portfolioId: String) async throws -> RebalancingHistorySummary {
    try await authenticated { try await $0.call(RebalancingHistoryEndpoint(portfolioId: portfolioId)) }
  }

  func preferences(portfolioId: String) async throws -> RebalancingNotificationPreferences {
    try await authenticated { try await $0.call(RebalancingPreferencesEndpoint(portfolioId: portfolioId)) }
  }

  func updatePreferences(portfolioId: String, enabled: Bool) async throws -> RebalancingNotificationPreferences {
    try await authenticated { try await $0.call(UpdateRebalancingPreferencesEndpoint(
      portfolioId: portfolioId,
      payload: .init(pushEnabled: enabled)
    )) }
  }

  func alerts() async throws -> [RebalancingAlert] {
    try await authenticated { try await $0.call(RebalancingAlertsEndpoint()) }
  }

  func acknowledge(alertId: String) async throws -> RebalancingAlert {
    try await authenticated { try await $0.call(AcknowledgeRebalancingAlertEndpoint(alertId: alertId)) }
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
