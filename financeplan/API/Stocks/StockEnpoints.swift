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

nonisolated protocol StockRequestBodyEndpoint {
  func bodyData() throws -> Data?
}

nonisolated struct CreateStockEndpoint: Endpoint {
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

nonisolated struct BulkCreateStocksEndpoint: Endpoint {
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

nonisolated struct GetStocksEndpoint: Endpoint {
  // Lenient list decode: tolerates a missing `createdAt` and drops individual
  // malformed rows instead of failing the entire holdings list.
  typealias Response = LenientStockList
  let portfolioListId: String?
  let cursor: String?
  let limit: Int?

  var method: HTTPMethod { .get }
  var path: String { "/v1/stocks" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    if let portfolioListId, !portfolioListId.isEmpty {
      params["portfolioListId"] = portfolioListId
    }
    if let cursor { params["cursor"] = cursor }
    if let limit { params["limit"] = String(limit) }
    return params
  }
}

nonisolated struct UpdateStockEndpoint: Endpoint {
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

nonisolated struct DeleteStockEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse

  let stockId: String

  var method: HTTPMethod { .delete }
  var path: String { "/v1/stocks/id/\(stockId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct SellStockEndpoint: Endpoint {
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
nonisolated struct GetStockDetailsEndpoint: Endpoint {
  typealias Response = StockDetails
  let stockId: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/stocks/id/\(stockId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetStockInsightsEndpoint: Endpoint {
  typealias Response = StockInsightsResponse
  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/stocks/symbol/\(symbol)/insights" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetPortfolioPerformanceEndpoint: Endpoint {
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

nonisolated struct GetPortfolioSummaryEndpoint: Endpoint {
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

nonisolated struct GetPnlEndpoint: Endpoint {
  typealias Response = PnlResponse
  let portfolioListId: String?

  var method: HTTPMethod { .get }
  var path: String { "/v1/pnl" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    if let portfolioListId, !portfolioListId.isEmpty {
      params["portfolioListId"] = portfolioListId
    }
    return params
  }
}

nonisolated struct GetPortfolioSectorExposureEndpoint: Endpoint {
  typealias Response = PortfolioSectorExposureResponse
  let portfolioListId: String?

  var method: HTTPMethod { .get }
  var path: String { "/v1/portfolio/sector-exposure" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    if let portfolioListId, !portfolioListId.isEmpty {
      params["portfolioListId"] = portfolioListId
    }
    return params
  }
}

nonisolated struct GetStockHistoryEndpoint: Endpoint {
  typealias Response = [StockHistory]
  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/history" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["symbol": symbol]
  }
}

nonisolated struct GetStockNewsEndpoint: Endpoint {
  typealias Response = [StockNews]
  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/news" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["symbol": symbol]
  }
}

nonisolated struct GetStockValuationEndpoint: Endpoint {
  typealias Response = StockValuationRequest

  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/stocks/symbol/\(symbol)/valuation" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct CreateStockValuationEndpoint: Endpoint, StockRequestBodyEndpoint {
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

nonisolated struct UpdateStockValuationEndpoint: Endpoint, StockRequestBodyEndpoint {
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

nonisolated struct GetWatchlistEndpoint: Endpoint {
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

nonisolated struct WatchlistCSVImportPreviewEndpoint: Endpoint, StockRequestBodyEndpoint {
  typealias Response = WatchlistCsvImportPreviewResponse
  let watchlistListId: String?
  let csvData: Data

  var method: HTTPMethod { .post }
  var path: String { "/v1/watchlist/import/csv/preview" }
  var decoder: JSONDecoder { .stockPlanShared }
  var headers: [(String, String)] { [("Content-Type", "text/csv")] }

  func asParameters() throws -> Parameters { watchlistCSVImportParameters(watchlistListId) }
  func bodyData() throws -> Data? { csvData }
}

nonisolated struct WatchlistCSVImportCommitEndpoint: Endpoint, StockRequestBodyEndpoint {
  typealias Response = WatchlistCsvImportCommitResponse
  let watchlistListId: String?
  let csvData: Data

  var method: HTTPMethod { .post }
  var path: String { "/v1/watchlist/import/csv/commit" }
  var decoder: JSONDecoder { .stockPlanShared }
  var headers: [(String, String)] { [("Content-Type", "text/csv")] }

  func asParameters() throws -> Parameters { watchlistCSVImportParameters(watchlistListId) }
  func bodyData() throws -> Data? { csvData }
}

nonisolated private func watchlistCSVImportParameters(_ watchlistListId: String?) -> Parameters {
  var params: Parameters = [:]
  if let watchlistListId, !watchlistListId.isEmpty {
    params["watchlistListId"] = watchlistListId
  }
  return params
}

nonisolated struct CreateWatchlistEndpoint: Endpoint {
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

nonisolated struct UpdateWatchlistEndpoint: Endpoint {
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

nonisolated private func stockParameters(_ payload: StockRequest, portfolioListId: String? = nil) -> Parameters {
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

nonisolated private func watchlistParameters(_ payload: WatchlistItemRequest, watchlistListId: String? = nil) -> Parameters {
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

nonisolated private func watchlistUpdateParameters(_ payload: WatchlistItemUpdateRequest, watchlistListId: String? = nil) -> Parameters {
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

nonisolated private func targetParameters(_ payload: TargetRequest) -> Parameters {
  var params: Parameters = [
    "symbol": payload.symbol,
    "scenario": payload.scenario,
    "targetPrice": payload.targetPrice
  ]
  if let targetDate = payload.targetDate, !targetDate.isEmpty {
    params["targetDate"] = targetDate
  }
  if let rationale = payload.rationale, !rationale.isEmpty {
    params["rationale"] = rationale
  }
  return params
}

nonisolated struct DeleteWatchlistEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let watchlistId: String

  var method: HTTPMethod { .delete }
  var path: String { "/v1/watchlist/\(watchlistId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetTargetsEndpoint: Endpoint {
  typealias Response = [TargetResponse]
  let symbol: String?

  var method: HTTPMethod { .get }
  var path: String { "/v1/targets" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    guard let symbol else { return [:] }
    let normalized = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !normalized.isEmpty else { return [:] }
    return ["symbol": normalized]
  }
}

nonisolated struct CreateTargetEndpoint: Endpoint {
  typealias Response = TargetResponse
  let payload: TargetRequest

  var method: HTTPMethod { .post }
  var path: String { "/v1/targets" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    targetParameters(payload)
  }
}

nonisolated struct DeleteTargetEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let targetId: String

  var method: HTTPMethod { .delete }
  var path: String { "/v1/targets/\(targetId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetPortfolioListsEndpoint: Endpoint {
  typealias Response = [PortfolioListDTOResponse]

  var method: HTTPMethod { .get }
  var path: String { "/v1/portfolio/lists" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct CreatePortfolioListEndpoint: Endpoint {
  typealias Response = PortfolioListDTOResponse
  let payload: PortfolioListDTORequest

  var method: HTTPMethod { .post }
  var path: String { "/v1/portfolio/lists" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["name": payload.name]
  }
}

nonisolated struct UpdatePortfolioListEndpoint: Endpoint {
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

nonisolated struct DeletePortfolioListEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let listId: String

  var method: HTTPMethod { .delete }
  var path: String { "/v1/portfolio/lists/\(listId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetWatchlistListsEndpoint: Endpoint {
  typealias Response = [WatchlistListDTOResponse]

  var method: HTTPMethod { .get }
  var path: String { "/v1/watchlist/lists" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct CreateWatchlistListEndpoint: Endpoint {
  typealias Response = WatchlistListDTOResponse
  let payload: WatchlistListDTORequest

  var method: HTTPMethod { .post }
  var path: String { "/v1/watchlist/lists" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["name": payload.name]
  }
}

nonisolated struct UpdateWatchlistListEndpoint: Endpoint {
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

nonisolated struct DeleteWatchlistListEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let listId: String

  var method: HTTPMethod { .delete }
  var path: String { "/v1/watchlist/lists/\(listId)" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}
