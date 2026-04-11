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
  let portfolioListId: String?

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
    if let portfolioListId, !portfolioListId.isEmpty {
      params["portfolioListId"] = portfolioListId
    }
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
    var params: Parameters = [:]
    params["stocks"] = stocks.map { stockParameters($0) }
    return params
  }
}

struct GetStocksEndpoint: Endpoint {
  typealias Response = [StockResponse]
  let portfolioListId: String?

  var method: HTTPMethod { .get }
  var path: String { "/v1/stocks" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    if let portfolioListId, !portfolioListId.isEmpty {
      params["portfolioListId"] = portfolioListId
    }
    return params
  }
}

struct UpdateStockEndpoint: Endpoint {
  typealias Response = StockResponse
  let stockId: String
  let payload: StockRequest
  let portfolioListId: String?

  var method: HTTPMethod { .put }
  var path: String { "/v1/stocks/id/\(stockId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    stockParameters(payload, portfolioListId: portfolioListId)
  }
}

struct DeleteStockEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse

  let stockId: String

  var method: HTTPMethod { .delete }
  var path: String { "/v1/stocks/id/\(stockId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct SellStockEndpoint: Endpoint {
  typealias Response = StockResponse
  let stockId: String
  let payload: SellStockRequest

  var method: HTTPMethod { .post }
  var path: String { "/v1/stocks/id/\(stockId)/sell" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    [
      "sharesToSell": payload.sharesToSell,
      "sellPrice": payload.sellPrice,
      "sellDate": payload.sellDate
    ]
  }
}
struct GetStockDetailsEndpoint: Endpoint {
  typealias Response = StockDetails
  let stockId: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/stocks/id/\(stockId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct GetStockInsightsEndpoint: Endpoint {
  typealias Response = StockInsightsResponse
  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/stocks/symbol/\(symbol)/insights" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct GetPortfolioPerformanceEndpoint: Endpoint {
  typealias Response = PortfolioPerformanceResponse
  let portfolioListId: String?

  var method: HTTPMethod { .get }
  var path: String { "/v1/portfolio/performance" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    if let portfolioListId, !portfolioListId.isEmpty {
      params["portfolioListId"] = portfolioListId
    }
    return params
  }
}

struct GetPortfolioSummaryEndpoint: Endpoint {
  typealias Response = PortfolioSummaryResponse
  let portfolioListId: String?

  var method: HTTPMethod { .get }
  var path: String { "/v1/portfolio/summary" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    if let portfolioListId, !portfolioListId.isEmpty {
      params["portfolioListId"] = portfolioListId
    }
    return params
  }
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
  let watchlistListId: String?

  var method: HTTPMethod { .get }
  var path: String { "/v1/watchlist" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    if let watchlistListId, !watchlistListId.isEmpty {
      params["watchlistListId"] = watchlistListId
    }
    return params
  }
}

struct CreateWatchlistEndpoint: Endpoint {
  typealias Response = WatchlistItemResponse
  let payload: WatchlistItemRequest
  let watchlistListId: String?

  var method: HTTPMethod { .post }
  var path: String { "/v1/watchlist" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    watchlistParameters(payload, watchlistListId: watchlistListId)
  }
}

struct UpdateWatchlistEndpoint: Endpoint {
  typealias Response = WatchlistItemResponse
  let watchlistId: String
  let payload: WatchlistItemUpdateRequest
  let watchlistListId: String?

  var method: HTTPMethod { .patch }
  var path: String { "/v1/watchlist/\(watchlistId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    watchlistUpdateParameters(payload, watchlistListId: watchlistListId)
  }
}

private func stockParameters(_ payload: StockRequest, portfolioListId: String? = nil) -> Parameters {
  var params: Parameters = [
    "symbol": payload.symbol,
    "shares": payload.shares,
    "buyPrice": payload.buyPrice,
    "buyDate": payload.buyDate,
    "category": payload.category.rawValue
  ]
  if let notes = payload.notes, !notes.isEmpty {
    params["notes"] = notes
  }
  if let portfolioListId, !portfolioListId.isEmpty {
    params["portfolioListId"] = portfolioListId
  }
  return params
}

private func watchlistParameters(_ payload: WatchlistItemRequest, watchlistListId: String? = nil) -> Parameters {
  var params: Parameters = ["symbol": payload.symbol]
  if let note = payload.note {
    params["note"] = note
  }
  if let status = payload.status {
    params["status"] = status.rawValue
  }
  if let nextReviewAt = payload.nextReviewAt {
    params["nextReviewAt"] = nextReviewAt
  }
  if let watchlistListId, !watchlistListId.isEmpty {
    params["watchlistListId"] = watchlistListId
  }
  return params
}

private func watchlistUpdateParameters(_ payload: WatchlistItemUpdateRequest, watchlistListId: String? = nil) -> Parameters {
  var params: Parameters = [:]
  if let note = payload.note {
    params["note"] = note
  }
  if let status = payload.status {
    params["status"] = status.rawValue
  }
  if let lastReviewedAt = payload.lastReviewedAt {
    params["lastReviewedAt"] = lastReviewedAt
  }
  if let nextReviewAt = payload.nextReviewAt {
    params["nextReviewAt"] = nextReviewAt
  }
  if let watchlistListId, !watchlistListId.isEmpty {
    params["watchlistListId"] = watchlistListId
  }
  return params
}

struct DeleteWatchlistEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let watchlistId: String

  var method: HTTPMethod { .delete }
  var path: String { "/v1/watchlist/\(watchlistId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct GetPortfolioListsEndpoint: Endpoint {
  typealias Response = [PortfolioListDTOResponse]

  var method: HTTPMethod { .get }
  var path: String { "/v1/portfolio/lists" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct CreatePortfolioListEndpoint: Endpoint {
  typealias Response = PortfolioListDTOResponse
  let payload: PortfolioListDTORequest

  var method: HTTPMethod { .post }
  var path: String { "/v1/portfolio/lists" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["name": payload.name]
  }
}

struct UpdatePortfolioListEndpoint: Endpoint {
  typealias Response = PortfolioListDTOResponse
  let listId: String
  let payload: PortfolioListDTORequest

  var method: HTTPMethod { .patch }
  var path: String { "/v1/portfolio/lists/\(listId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["name": payload.name]
  }
}

struct DeletePortfolioListEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let listId: String

  var method: HTTPMethod { .delete }
  var path: String { "/v1/portfolio/lists/\(listId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct GetWatchlistListsEndpoint: Endpoint {
  typealias Response = [WatchlistListDTOResponse]

  var method: HTTPMethod { .get }
  var path: String { "/v1/watchlist/lists" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct CreateWatchlistListEndpoint: Endpoint {
  typealias Response = WatchlistListDTOResponse
  let payload: WatchlistListDTORequest

  var method: HTTPMethod { .post }
  var path: String { "/v1/watchlist/lists" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["name": payload.name]
  }
}

struct UpdateWatchlistListEndpoint: Endpoint {
  typealias Response = WatchlistListDTOResponse
  let listId: String
  let payload: WatchlistListDTORequest

  var method: HTTPMethod { .patch }
  var path: String { "/v1/watchlist/lists/\(listId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["name": payload.name]
  }
}

struct DeleteWatchlistListEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let listId: String

  var method: HTTPMethod { .delete }
  var path: String { "/v1/watchlist/lists/\(listId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}
