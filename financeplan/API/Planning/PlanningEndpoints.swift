import AnyAPI
import Foundation
import StockPlanShared

private nonisolated protocol PlanningEndpoint: Endpoint {}

extension PlanningEndpoint {
  nonisolated var decoder: JSONDecoder { .stockPlanShared }
  nonisolated func asParameters() throws -> Parameters { [:] }
}

private nonisolated protocol PlanningBodyEndpoint: PlanningEndpoint, StockRequestBodyEndpoint {
  associatedtype Payload: Encodable
  var payload: Payload { get }
}

extension PlanningBodyEndpoint {
  nonisolated func bodyData() throws -> Data? { try JSONEncoder.stockPlanShared.encode(payload) }
}

nonisolated struct PlanningPrefillEndpoint: PlanningEndpoint {
  typealias Response = PlanningPrefill
  var method: HTTPMethod { .get }
  var path: String { "/v1/planning/prefill" }
}

nonisolated struct GrowthProjectionEndpoint: PlanningBodyEndpoint {
  typealias Response = GrowthProjectionResponse
  let payload: GrowthProjectionRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/planning/projection" }
}

nonisolated struct RetirementPlanningEndpoint: PlanningBodyEndpoint {
  typealias Response = RetirementPlanningResponse
  let payload: RetirementPlanningRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/planning/retirement" }
}

nonisolated struct ListPlanningScenariosEndpoint: PlanningEndpoint {
  typealias Response = [PlanningScenario]
  var method: HTTPMethod { .get }
  var path: String { "/v1/planning/scenarios" }
}

nonisolated struct CreatePlanningScenarioEndpoint: PlanningBodyEndpoint {
  typealias Response = PlanningScenario
  let payload: PlanningScenarioUpsertRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/planning/scenarios" }
}
