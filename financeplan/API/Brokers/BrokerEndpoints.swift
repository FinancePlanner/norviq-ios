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

nonisolated struct GetBrokerEndpoint: Endpoint {
  typealias Response = BrokerConnectionResponse
  let provider: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/brokers/\(provider)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct SyncIBKREndpoint: Endpoint {
  typealias Response = BrokerSyncResponse

  var method: HTTPMethod { .post }
  var path: String { "/v1/brokers/ibkr/sync" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct StartIBKRConnectEndpoint: Endpoint {
  typealias Response = BrokerConnectStartResponse

  let redirectURI: String
  let portfolioListId: String?

  var method: HTTPMethod { .post }
  var path: String { "/v1/brokers/ibkr/connect/start" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = ["redirectURI": redirectURI]
    if let portfolioListId, !portfolioListId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      params["portfolioListId"] = portfolioListId
    }
    return params
  }
}

nonisolated struct ConnectIBKRCredentialsEndpoint: Endpoint {
  typealias Response = BrokerConnectionResponse

  let token: String
  let queryId: String
  let portfolioListId: String?

  var method: HTTPMethod { .post }
  var path: String { "/v1/brokers/ibkr/connect/credentials" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [
      "token": token,
      "queryId": queryId,
    ]
    if let portfolioListId, !portfolioListId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      params["portfolioListId"] = portfolioListId
    }
    return params
  }
}

nonisolated struct DisconnectIBKREndpoint: Endpoint {
  typealias Response = BrokerConnectionResponse

  var method: HTTPMethod { .delete }
  var path: String { "/v1/brokers/ibkr/connection" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}
