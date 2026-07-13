import AnyAPI
import Foundation
import StockPlanShared

private func financingParameters<T: Encodable>(_ value: T) throws -> Parameters {
  let data = try JSONEncoder.stockPlanShared.encode(value)
  return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
}

struct SimulateFinancingEndpoint: Endpoint {
  typealias Response = FinancingSimulationResponse
  let payload: FinancingSimulationRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/financing/simulations" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try financingParameters(payload) }
}

struct GetFinancingPlansEndpoint: Endpoint {
  typealias Response = [FinancingPlanResponse]
  var method: HTTPMethod { .get }
  var path: String { "/v1/financing/plans" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

struct CreateFinancingPlanEndpoint: Endpoint {
  typealias Response = FinancingPlanResponse
  let payload: FinancingPlanRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/financing/plans" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try financingParameters(payload) }
}

struct GetFinancingProjectionsEndpoint: Endpoint {
  typealias Response = [FinancingProjectionResponse]
  let from: String?
  let to: String?
  var method: HTTPMethod { .get }
  var path: String { "/v1/financing/projections" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters {
    var result = Parameters()
    if let from { result["from"] = from }
    if let to { result["to"] = to }
    return result
  }
}
