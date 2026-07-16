import Foundation
import StockPlanShared

protocol GoalPlanningServicing: Sendable {
  func overview() async throws -> GoalOverview
  func templates() async throws -> [GoalTemplate]
  func portfolios() async throws -> [PortfolioListDTOResponse]
  func progress(goalId: String) async throws -> GoalProgress
  func create(_ input: FinancialGoalInput) async throws -> FinancialGoal
  func update(goalId: String, input: FinancialGoalInput) async throws -> FinancialGoal
  func whatIf(goalId: String, request: GoalWhatIfRequest) async throws -> GoalWhatIfResponse
  func suggestions(goalId: String) async throws -> [GoalSuggestion]
  func accept(goalId: String, suggestionId: String) async throws -> GoalAdjustmentDraft
  func addContribution(goalId: String, input: GoalContributionInput) async throws -> GoalContribution
}

final class GoalPlanningService: GoalPlanningServicing, Sendable {
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

  func overview() async throws -> GoalOverview {
    try await authenticated { try await $0.call(GoalOverviewEndpoint()) }
  }

  func templates() async throws -> [GoalTemplate] {
    try await authenticated { try await $0.call(GoalTemplatesEndpoint()) }
  }

  func portfolios() async throws -> [PortfolioListDTOResponse] {
    try await authenticated { try await $0.call(GetPortfolioListsEndpoint()) }
  }

  func progress(goalId: String) async throws -> GoalProgress {
    try await authenticated { try await $0.call(GoalProgressEndpoint(goalId: goalId)) }
  }

  func create(_ input: FinancialGoalInput) async throws -> FinancialGoal {
    try await authenticated { try await $0.call(CreateFinancialGoalEndpoint(payload: input)) }
  }

  func update(goalId: String, input: FinancialGoalInput) async throws -> FinancialGoal {
    try await authenticated { try await $0.call(UpdateFinancialGoalEndpoint(goalId: goalId, payload: input)) }
  }

  func whatIf(goalId: String, request: GoalWhatIfRequest) async throws -> GoalWhatIfResponse {
    try await authenticated { try await $0.call(GoalWhatIfEndpoint(goalId: goalId, payload: request)) }
  }

  func suggestions(goalId: String) async throws -> [GoalSuggestion] {
    try await authenticated { try await $0.call(GoalSuggestionsEndpoint(goalId: goalId)) }
  }

  func accept(goalId: String, suggestionId: String) async throws -> GoalAdjustmentDraft {
    try await authenticated { try await $0.call(
      AcceptGoalSuggestionEndpoint(goalId: goalId, suggestionId: suggestionId)
    ) }
  }

  func addContribution(goalId: String, input: GoalContributionInput) async throws -> GoalContribution {
    try await authenticated { try await $0.call(CreateGoalContributionEndpoint(goalId: goalId, payload: input)) }
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
