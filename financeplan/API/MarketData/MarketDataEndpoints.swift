import AnyAPI
import Foundation
import StockPlanShared

struct GetCompanyProfileEndpoint: Endpoint {
  typealias Response = CompanyProfileResponse

  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/profile/\(symbol.uppercased())" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct GetQuoteEndpoint: Endpoint {
  typealias Response = QuoteResponse

  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/quote/\(symbol.uppercased())" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}
