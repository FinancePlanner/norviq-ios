import AnyAPI
import Foundation
import StockPlanShared

// MARK: - Endpoints for Macro / Inflation (Nowflation parity)

struct GetInflationCurrentEndpoint: Endpoint {
  typealias Response = InflationSnapshotResponse

  let country: String?

  var method: HTTPMethod { .get }
  var path: String { "/v1/macro/inflation/current" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    if let country { return ["country": country] }
    return [:]
  }
}

struct GetTopMoversEndpoint: Endpoint {
  typealias Response = [TopMoverDTO]

  let country: String?
  var focus: String? // comma separated e.g. "utilities,food,shelter"

  var method: HTTPMethod { .get }
  var path: String { "/v1/macro/top-movers" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    if let country { params["country"] = country }
    if let focus { params["focus"] = focus }
    return params
  }
}

struct GetInflationSeriesEndpoint: Endpoint {
  typealias Response = MacroSeriesResponse

  let country: String?
  let series: String
  let from: String?
  let to: String?

  var method: HTTPMethod { .get }
  var path: String { "/v1/macro/inflation/series" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var p: Parameters = ["series": series]
    if let country { p["country"] = country }
    if let from { p["from"] = from }
    if let to { p["to"] = to }
    return p
  }
}

struct GetSupportedCountriesEndpoint: Endpoint {
  typealias Response = [SupportedCountry]

  var method: HTTPMethod { .get }
  var path: String { "/v1/macro/supported-countries" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}
