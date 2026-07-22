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
  var limit: Int?

  var method: HTTPMethod { .get }
  var path: String { "/v1/macro/inflation/series" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var p: Parameters = ["series": series]
    if let country { p["country"] = country }
    if let from { p["from"] = from }
    if let to { p["to"] = to }
    if let limit { p["limit"] = String(limit) }
    return p
  }
}

struct GetPersonalInflationEndpoint: Endpoint {
  typealias Response = PersonalInflationResponse

  let country: String?
  let months: Int

  var method: HTTPMethod { .get }
  var path: String { "/v1/macro/inflation/personal" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var parameters: Parameters = ["months": String(months)]
    if let country { parameters["country"] = country }
    return parameters
  }
}

struct GetFedWatchEndpoint: Endpoint {
  typealias Response = FedWatchResponse

  var method: HTTPMethod { .get }
  var path: String { "/v1/macro/fed-watch" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct GetMacroItemsEndpoint: Endpoint {
  typealias Response = MacroItemsResponse

  let country: String?

  var method: HTTPMethod { .get }
  var path: String { "/v1/macro/items" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    if let country { return ["country": country] }
    return [:]
  }
}

struct GetMacroItemSeriesEndpoint: Endpoint {
  typealias Response = MacroItemSeriesResponse

  let itemId: String
  let country: String?
  var limit: Int?

  var method: HTTPMethod { .get }
  var path: String { "/v1/macro/items/\(itemId)/series" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var p: Parameters = [:]
    if let country { p["country"] = country }
    if let limit { p["limit"] = String(limit) }
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

struct GetHousingHubEndpoint: Endpoint {
  typealias Response = HousingHubResponse

  let country: String?

  var method: HTTPMethod { .get }
  var path: String { "/v1/macro/housing" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    if let country { return ["country": country] }
    return [:]
  }
}

struct GetEconomyHubEndpoint: Endpoint {
  typealias Response = EconomyHubResponse

  let country: String?

  var method: HTTPMethod { .get }
  var path: String { "/v1/macro/economy" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    if let country { return ["country": country] }
    return [:]
  }
}

struct GetPolicyWatchEndpoint: Endpoint {
  typealias Response = PolicyWatchResponse

  let country: String?

  var method: HTTPMethod { .get }
  var path: String { "/v1/macro/policy-watch" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    if let country { return ["country": country] }
    return [:]
  }
}
