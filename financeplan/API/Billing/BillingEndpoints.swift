import AnyAPI
import Foundation
import StockPlanShared

nonisolated struct BillingManagementURLResponse: Codable, Sendable, Equatable {
  let managementURL: URL
  let provider: String
  let source: String

  enum CodingKeys: String, CodingKey {
    case managementURL = "managementUrl"
    case provider
    case source
  }
}

struct GetBillingContextEndpoint: Endpoint {
  typealias Response = BillingContextResponse

  var method: HTTPMethod { .get }
  var path: String { "/v1/billing/me" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct CreateBillingManagementURLEndpoint: Endpoint {
  typealias Response = BillingManagementURLResponse

  var method: HTTPMethod { .post }
  var path: String { "/v1/billing/management-url" }
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
