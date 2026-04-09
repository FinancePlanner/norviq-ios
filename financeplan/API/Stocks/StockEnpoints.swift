//
//  StockEnpoints.swift
//  financeplan
//
//  Created by Fernando Correia on 28.02.26.
//

import AnyAPI
import Foundation
import OSLog
import StockPlanShared

struct CreateStockEndpoint: Endpoint {
  typealias Response = StockResponse

  let symbol: String
  let shares: Double
  let buyPrice: Double
  let buyDate: String?
  let notes: String?
  let category: AssetCategory

  var method: HTTPMethod { .post }
  var path: String { "/v1/stocks" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    params["symbol"] = symbol
    params["shares"] = shares
    params["buyPrice"] = buyPrice
    params["category"] = category.rawValue
    if let buyDate { params["buyDate"] = buyDate }
    if let notes, !notes.isEmpty { params["notes"] = notes }
    return params
  }
}

struct BulkCreateStocksEndpoint: Endpoint {
  typealias Response = BulkStockResponse
  let stocks: [StockRequest]

  var method: HTTPMethod { .post }
  var path: String { "/v1/stocks/bulk" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    // Encode array of StockRequest into JSON-compatible Parameters
    let data = try JSONEncoder.default.encode(stocks)
    let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    var params: Parameters = [:]
    params["stocks"] = json
    return params
  }
}

struct GetStocksEndpoint: Endpoint {
  typealias Response = [StockResponse]

  var method: HTTPMethod { .get }
  var path: String { "/v1/stocks" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct UpdateStockEndpoint: Endpoint {
  typealias Response = StockResponse
  let stockId: String
  let payload: StockRequest

  var method: HTTPMethod { .put }
  var path: String { "/v1/stocks/\(stockId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    let data = try JSONEncoder.default.encode(payload)
    return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
  }
}


struct DeleteStockEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse

  let stockId: String

  var method: HTTPMethod { .delete }
  var path: String { "/v1/stocks/\(stockId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}
struct GetStockDetailsEndpoint: Endpoint {
  typealias Response = StockDetails
  let stockId: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/stocks/\(stockId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct GetStockInsightsEndpoint: Endpoint {
  typealias Response = StockInsightsResponse
  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/stocks/\(symbol)/insights" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct GetPortfolioPerformanceEndpoint: Endpoint {
  typealias Response = PortfolioPerformanceResponse

  var method: HTTPMethod { .get }
  var path: String { "/v1/portfolio/performance" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct GetStockHistoryEndpoint: Endpoint {
  typealias Response = [StockHistory]
  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/history" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["symbol": symbol]
  }
}

struct GetStockNewsEndpoint: Endpoint {
  typealias Response = [StockNews]
  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/news" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["symbol": symbol]
  }
}

struct GetStockValuationEndpoint: Endpoint {
  typealias Response = StockValuationRequest

  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/stocks/symbol/\(symbol)/valuation" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}


struct CreateStockValuationEndpoint: Endpoint, StockRequestBodyEndpoint {
  typealias Response = StockValuationRequest

  let path: String
  private let body: Data

  init(
    symbol: String,
    draft: StockValuationDraft
  ) throws {
    path = "/v1/stocks/symbol/\(symbol)/valuation"
    let request = StockValuationRequest(
      symbol: symbol,
      bearCase: PriceRange(low: draft.bearLow, high: draft.bearHigh),
      baseCase: PriceRange(low: draft.baseLow, high: draft.baseHigh),
      bullCase: PriceRange(low: draft.bullLow, high: draft.bullHigh),
      rationale: draft.rationale,
      targetDate: draft.targetDate
    )
    body = try JSONEncoder.default.encode(request)
  }


  init(
    symbol: String,
    bearLow: Double,
    bearHigh: Double,
    baseLow: Double,
    baseHigh: Double,
    bullLow: Double,
    bullHigh: Double,
    rationale: String?,
    targetDate: String?
  ) throws {
    path = "/v1/stocks/symbol/\(symbol)/valuation"
    let request = StockValuationRequest(
      symbol: symbol,
      bearCase: PriceRange(low: bearLow, high: bearHigh),
      baseCase: PriceRange(low: baseLow, high: baseHigh),
      bullCase: PriceRange(low: bullLow, high: bullHigh),
      rationale: rationale,
      targetDate: targetDate
    )
    body = try JSONEncoder.default.encode(request)
  }


  var method: HTTPMethod { .post }
  var decoder: JSONDecoder { .stockPlanShared }


  func asParameters() throws -> Parameters {
    [:]
  }

  func bodyData() throws -> Data? {
    body
  }
}

struct UpdateStockValuationEndpoint: Endpoint, StockRequestBodyEndpoint {
  typealias Response = StockValuationRequest

  let path: String
  private let body: Data

  init(
    symbol: String,
    draft: StockValuationDraft
  ) throws {
    path = "/v1/stocks/symbol/\(symbol)/valuation"
    let request = StockValuationRequest(
      symbol: symbol,
      bearCase: PriceRange(low: draft.bearLow, high: draft.bearHigh),
      baseCase: PriceRange(low: draft.baseLow, high: draft.baseHigh),
      bullCase: PriceRange(low: draft.bullLow, high: draft.bullHigh),
      rationale: draft.rationale,
      targetDate: draft.targetDate
    )
    body = try JSONEncoder.default.encode(request)
  }


  init(
    symbol: String,
    bearLow: Double,
    bearHigh: Double,
    baseLow: Double,
    baseHigh: Double,
    bullLow: Double,
    bullHigh: Double,
    rationale: String?,
    targetDate: String?
  ) throws {
    path = "/v1/stocks/symbol/\(symbol)/valuation"
    let request = StockValuationRequest(
      symbol: symbol,
      bearCase: PriceRange(low: bearLow, high: bearHigh),
      baseCase: PriceRange(low: baseLow, high: baseHigh),
      bullCase: PriceRange(low: bullLow, high: bullHigh),
      rationale: rationale,
      targetDate: targetDate
    )
    body = try JSONEncoder.default.encode(request)
  }

  var method: HTTPMethod { .put }
  var decoder: JSONDecoder { .stockPlanShared }


  func asParameters() throws -> Parameters {
    [:]
  }

  func bodyData() throws -> Data? {
    body
  }
}

// watchlist

struct GetWatchlistEndpoint: Endpoint {
  typealias Response = [WatchlistItemResponse]

  var method: HTTPMethod { .get }
  var path: String { "/v1/watchlist" }
  var decoder: JSONDecoder { .stockPlanShared }


  func asParameters() throws -> Parameters { [:] }
}

struct CreateWatchlistEndpoint: Endpoint {
  typealias Response = WatchlistItemResponse
  let payload: WatchlistItemRequest

  var method: HTTPMethod { .post }
  var path: String { "/v1/watchlist" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    let data = try JSONEncoder.default.encode(payload)
    return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
  }
}


struct UpdateWatchlistEndpoint: Endpoint {
  typealias Response = WatchlistItemResponse
  let watchlistId: String
  let payload: WatchlistItemUpdateRequest

  var method: HTTPMethod { .patch }
  var path: String { "/v1/watchlist/\(watchlistId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    let data = try JSONEncoder.default.encode(payload)
    return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
  }
}


struct DeleteWatchlistEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let watchlistId: String

  var method: HTTPMethod { .delete }
  var path: String { "/v1/watchlist/\(watchlistId)" }
  var decoder: JSONDecoder { .stockPlanShared }


  func asParameters() throws -> Parameters { [:] }
}
