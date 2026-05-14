import AnyAPI
import Foundation
import StockPlanShared

struct GetStockEarningsEndpoint: Endpoint {
  typealias Response = [EarningsEvent]
  let symbol: String
  let limit: Int

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/earnings/\(symbol)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["limit": limit]
  }
}

struct GetStockEarningsTranscriptEndpoint: Endpoint {
  typealias Response = EarningsTranscript
  let symbol: String
  let date: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/earnings/\(symbol)/transcript" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["date": date]
  }
}

struct GetEarningsCalendarEndpoint: Endpoint {
  typealias Response = [EarningsEvent]
  let from: String
  let to: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/earnings-calendar" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["from": from, "to": to]
  }
}

struct GetGeneralMarketNewsEndpoint: Endpoint {
  typealias Response = [StockNews]
  let limit: Int?

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/news/general" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    if let limit { params["limit"] = limit }
    return params
  }
}
