import AnyAPI
import Foundation
import StockPlanShared

nonisolated struct GetStockEarningsEndpoint: Endpoint {
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

nonisolated struct GetStockEarningsTranscriptEndpoint: Endpoint {
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

nonisolated struct GetEarningsCalendarEndpoint: Endpoint {
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

nonisolated struct GetMarketPressureEndpoint: Endpoint {
  typealias Response = MarketPressureResponse
  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/pressure/\(symbol)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetPeriodReturnsEndpoint: Endpoint {
  typealias Response = StockPeriodReturnsResponse
  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/returns/\(symbol.uppercased())" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetPeriodReturnsBatchEndpoint: Endpoint {
  typealias Response = StockPeriodReturnsBatchResponse
  let symbols: [String]

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/returns/batch" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["symbols": symbols.joined(separator: ",")]
  }
}

nonisolated struct GetMarketOverviewEndpoint: Endpoint {
  typealias Response = MarketOverviewResponse

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/overview" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetGeneralMarketNewsEndpoint: Endpoint {
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
