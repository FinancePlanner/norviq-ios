import AnyAPI
import Foundation
import StockPlanShared

private nonisolated protocol RebalancingEndpoint: Endpoint {}

extension RebalancingEndpoint {
  nonisolated var decoder: JSONDecoder {
    .stockPlanShared
  }

  nonisolated func asParameters() throws -> Parameters {
    [:]
  }
}

private nonisolated protocol RebalancingBodyEndpoint: RebalancingEndpoint, StockRequestBodyEndpoint {
  associatedtype Payload: Encodable
  var payload: Payload { get }
}

extension RebalancingBodyEndpoint {
  nonisolated func bodyData() throws -> Data? {
    try JSONEncoder.stockPlanShared.encode(payload)
  }
}

nonisolated struct RebalancingModelsEndpoint: RebalancingEndpoint {
  typealias Response = [AllocationModel]
  let portfolioId: String
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/rebalancing/models"
  }
}

nonisolated struct CreateRebalancingModelEndpoint: RebalancingBodyEndpoint {
  typealias Response = AllocationModel
  let portfolioId: String
  let payload: AllocationModelUpsertRequest
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/rebalancing/models"
  }
}

nonisolated struct UpdateRebalancingModelEndpoint: RebalancingBodyEndpoint {
  typealias Response = AllocationModel
  let portfolioId: String
  let modelId: String
  let payload: AllocationModelUpsertRequest
  var method: HTTPMethod {
    .put
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/rebalancing/models/\(modelId)"
  }
}

nonisolated struct RebalancingOverviewEndpoint: RebalancingEndpoint {
  typealias Response = RebalancingOverview
  let portfolioId: String
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/rebalancing/overview"
  }
}

nonisolated struct RebalancingSimulationEndpoint: RebalancingBodyEndpoint {
  typealias Response = RebalancingSimulation
  let portfolioId: String
  let payload: RebalancingSimulationRequest
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/rebalancing/simulate"
  }
}

nonisolated struct RebalancingPlansEndpoint: RebalancingEndpoint {
  typealias Response = [RebalancePlan]
  let portfolioId: String
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/rebalancing/plans"
  }
}

nonisolated struct CreateRebalancingPlanEndpoint: RebalancingBodyEndpoint {
  typealias Response = RebalancePlan
  let portfolioId: String
  let payload: RebalancePlanCreateRequest
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/rebalancing/plans"
  }
}

nonisolated struct CompleteRebalancingPlanEndpoint: RebalancingBodyEndpoint {
  typealias Response = RebalancePlan
  let portfolioId: String
  let planId: String
  let payload: RebalancePlanCompletionRequest
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/rebalancing/plans/\(planId)/complete"
  }
}

nonisolated struct RebalancingHistoryEndpoint: RebalancingEndpoint {
  typealias Response = RebalancingHistorySummary
  let portfolioId: String
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/rebalancing/history"
  }
}

nonisolated struct RebalancingPreferencesEndpoint: RebalancingEndpoint {
  typealias Response = RebalancingNotificationPreferences
  let portfolioId: String
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/rebalancing/preferences"
  }
}

nonisolated struct UpdateRebalancingPreferencesEndpoint: RebalancingBodyEndpoint {
  typealias Response = RebalancingNotificationPreferences
  let portfolioId: String
  let payload: UpdateRebalancingNotificationPreferencesRequest
  var method: HTTPMethod {
    .put
  }

  var path: String {
    "/v1/portfolios/\(portfolioId)/rebalancing/preferences"
  }
}

nonisolated struct RebalancingAlertsEndpoint: RebalancingEndpoint {
  typealias Response = [RebalancingAlert]
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/rebalancing/alerts"
  }
}

nonisolated struct AcknowledgeRebalancingAlertEndpoint: RebalancingEndpoint {
  typealias Response = RebalancingAlert
  let alertId: String
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/rebalancing/alerts/\(alertId)/acknowledge"
  }
}
