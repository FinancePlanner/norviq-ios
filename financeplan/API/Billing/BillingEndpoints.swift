import AnyAPI
import Foundation
import StockPlanShared

struct GetBillingContextEndpoint: Endpoint {
  typealias Response = BillingContextResponse

  var method: HTTPMethod { .get }
  var path: String { "/v1/billing/me" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct RestoreBillingEndpoint: Endpoint {
  typealias Response = BillingContextResponse

  var method: HTTPMethod { .post }
  var path: String { "/v1/billing/restore" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}
