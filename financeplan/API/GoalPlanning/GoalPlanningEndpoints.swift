import AnyAPI
import Foundation
import StockPlanShared

private nonisolated protocol GoalPlanningEndpoint: Endpoint {}

extension GoalPlanningEndpoint {
  nonisolated var decoder: JSONDecoder { .stockPlanShared }
  nonisolated func asParameters() throws -> Parameters { [:] }
}

private nonisolated protocol GoalPlanningBodyEndpoint: GoalPlanningEndpoint, StockRequestBodyEndpoint {
  associatedtype Payload: Encodable
  var payload: Payload { get }
}

extension GoalPlanningBodyEndpoint {
  nonisolated func bodyData() throws -> Data? { try JSONEncoder.stockPlanShared.encode(payload) }
}

nonisolated struct GoalOverviewEndpoint: GoalPlanningEndpoint {
  typealias Response = GoalOverview
  var method: HTTPMethod { .get }
  var path: String { "/v1/financial-goals/overview" }
}

nonisolated struct GoalTemplatesEndpoint: GoalPlanningEndpoint {
  typealias Response = [GoalTemplate]
  var method: HTTPMethod { .get }
  var path: String { "/v1/financial-goals/templates" }
}

nonisolated struct GoalProgressEndpoint: GoalPlanningEndpoint {
  typealias Response = GoalProgress
  let goalId: String
  var method: HTTPMethod { .get }
  var path: String { "/v1/financial-goals/\(goalId)/progress" }
}

nonisolated struct CreateFinancialGoalEndpoint: GoalPlanningBodyEndpoint {
  typealias Response = FinancialGoal
  let payload: FinancialGoalInput
  var method: HTTPMethod { .post }
  var path: String { "/v1/financial-goals" }
}

nonisolated struct UpdateFinancialGoalEndpoint: GoalPlanningBodyEndpoint {
  typealias Response = FinancialGoal
  let goalId: String
  let payload: FinancialGoalInput
  var method: HTTPMethod { .put }
  var path: String { "/v1/financial-goals/\(goalId)" }
}

nonisolated struct GoalWhatIfEndpoint: GoalPlanningBodyEndpoint {
  typealias Response = GoalWhatIfResponse
  let goalId: String
  let payload: GoalWhatIfRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/financial-goals/\(goalId)/what-if" }
}

nonisolated struct GoalSuggestionsEndpoint: GoalPlanningEndpoint {
  typealias Response = [GoalSuggestion]
  let goalId: String
  var method: HTTPMethod { .get }
  var path: String { "/v1/financial-goals/\(goalId)/suggestions" }
}

nonisolated struct AcceptGoalSuggestionEndpoint: GoalPlanningEndpoint {
  typealias Response = GoalAdjustmentDraft
  let goalId: String
  let suggestionId: String
  var method: HTTPMethod { .post }
  var path: String { "/v1/financial-goals/\(goalId)/suggestions/\(suggestionId)/accept" }
}

nonisolated struct CreateGoalContributionEndpoint: GoalPlanningBodyEndpoint {
  typealias Response = GoalContribution
  let goalId: String
  let payload: GoalContributionInput
  var method: HTTPMethod { .post }
  var path: String { "/v1/financial-goals/\(goalId)/contributions" }
}
