import AnyAPI
import Foundation
import StockPlanShared

struct GetBrokersEndpoint: Endpoint {
  typealias Response = [BrokerConnectionResponse]

  var method: HTTPMethod { .get }
  var path: String { "/v1/brokers" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct GetBrokerEndpoint: Endpoint {
  typealias Response = BrokerConnectionResponse
  let provider: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/brokers/\(provider)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct SyncIBKREndpoint: Endpoint {
  typealias Response = BrokerSyncResponse

  var method: HTTPMethod { .post }
  var path: String { "/v1/brokers/ibkr/sync" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}
