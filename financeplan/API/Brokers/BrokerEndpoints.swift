import AnyAPI
import Foundation
import StockPlanShared

nonisolated struct GetBrokersEndpoint: Endpoint {
  typealias Response = [BrokerConnectionResponse]

  var method: HTTPMethod { .get }
  var path: String { "/v1/brokers" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct DisconnectIBKREndpoint: Endpoint {
  typealias Response = BrokerConnectionResponse

  var method: HTTPMethod { .delete }
  var path: String { "/v1/brokers/ibkr/connection" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}
