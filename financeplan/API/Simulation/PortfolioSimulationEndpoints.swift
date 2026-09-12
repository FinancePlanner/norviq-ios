import AnyAPI
import Foundation
import StockPlanShared

private nonisolated protocol PortfolioSimulationEndpoint: Endpoint {}

extension PortfolioSimulationEndpoint {
  nonisolated var decoder: JSONDecoder {
    .stockPlanShared
  }

  nonisolated func asParameters() throws -> Parameters {
    [:]
  }
}

private nonisolated protocol PortfolioSimulationBodyEndpoint: PortfolioSimulationEndpoint, StockRequestBodyEndpoint {
  associatedtype Payload: Encodable
  var payload: Payload { get }
}

extension PortfolioSimulationBodyEndpoint {
  nonisolated func bodyData() throws -> Data? {
    try JSONEncoder.stockPlanShared.encode(payload)
  }
}

nonisolated struct ListPortfolioSimulationsEndpoint: PortfolioSimulationEndpoint {
  typealias Response = PortfolioSimulationListResponse
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/portfolio/simulations"
  }
}

nonisolated struct GetPortfolioSimulationEndpoint: PortfolioSimulationEndpoint {
  typealias Response = PortfolioSimulation
  let simulationId: String
  var method: HTTPMethod {
    .get
  }

  var path: String {
    "/v1/portfolio/simulations/\(simulationId)"
  }
}

nonisolated struct CreatePortfolioSimulationEndpoint: PortfolioSimulationBodyEndpoint {
  typealias Response = PortfolioSimulation
  let payload: PortfolioSimulationUpsertRequest
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/portfolio/simulations"
  }
}

nonisolated struct UpdatePortfolioSimulationEndpoint: PortfolioSimulationBodyEndpoint {
  typealias Response = PortfolioSimulation
  let simulationId: String
  let payload: PortfolioSimulationUpsertRequest
  var method: HTTPMethod {
    .put
  }

  var path: String {
    "/v1/portfolio/simulations/\(simulationId)"
  }
}

/// Computes an unsaved payload, so the editor can recalculate as weights change
/// without writing a row per keystroke.
nonisolated struct PreviewPortfolioSimulationEndpoint: PortfolioSimulationBodyEndpoint {
  typealias Response = PortfolioSimulationResult
  let payload: PortfolioSimulationUpsertRequest
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/portfolio/simulations/preview"
  }
}

nonisolated struct ComputePortfolioSimulationEndpoint: PortfolioSimulationBodyEndpoint {
  typealias Response = PortfolioSimulationResult
  let simulationId: String
  let payload: PortfolioSimulationComputeRequest
  var method: HTTPMethod {
    .post
  }

  var path: String {
    "/v1/portfolio/simulations/\(simulationId)/compute"
  }
}

nonisolated struct DeletePortfolioSimulationEndpoint: PortfolioSimulationEndpoint {
  typealias Response = EmptyAPIResponse
  let simulationId: String
  var method: HTTPMethod {
    .delete
  }

  var path: String {
    "/v1/portfolio/simulations/\(simulationId)"
  }
}
