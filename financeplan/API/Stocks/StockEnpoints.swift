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

private enum StockDecoding {
  static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .custom { container in
      let single = try container.singleValueContainer()

      if let stringValue = try? single.decode(String.self),
         let parsed = parseDate(from: stringValue) {
        return parsed
      }

      if let numericValue = try? single.decode(Double.self) {
        // Accept both unix epoch and Apple reference date numeric formats.
        if abs(numericValue) > 1_000_000_000 {
          return Date(timeIntervalSince1970: numericValue)
        }
        return Date(timeIntervalSinceReferenceDate: numericValue)
      }

      throw DecodingError.dataCorruptedError(
        in: single,
        debugDescription: "Unsupported date payload"
      )
    }
    return decoder
  }

  private static func parseDate(from value: String) -> Date? {
    if let date = iso8601Fractional.date(from: value) {
      return date
    }
    if let date = iso8601.date(from: value) {
      return date
    }
    return dateOnly.date(from: value)
  }

  private static let iso8601Fractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = .init(secondsFromGMT: 0)
    return formatter
  }()

  private static let iso8601: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = .init(secondsFromGMT: 0)
    return formatter
  }()

  private static let dateOnly: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .init(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}

private enum StockEncoding {
  typealias JSONObject = [String: Any]

  private struct StockValuationBody: Encodable {
    struct PriceRangeBody: Encodable {
      let low: Double
      let high: Double
    }

    let symbol: String
    let bearCase: PriceRangeBody
    let baseCase: PriceRangeBody
    let bullCase: PriceRangeBody
    let rationale: String?
    let targetDate: String?
  }

  static func parameters<T: Encodable>(for value: T) throws -> Parameters {
    let data = try JSONEncoder().encode(value)
    return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
  }

  static func priceRangeParameters(_ range: PriceRange) -> Parameters {
    [
      "low": range.low,
      "high": range.high,
    ]
  }

  static func valuationParameters(for request: StockValuationRequest) -> Parameters {
    var params: Parameters = [
      "symbol": request.symbol,
      "bearCase": priceRangeParameters(request.bearCase),
      "baseCase": priceRangeParameters(request.baseCase),
      "bullCase": priceRangeParameters(request.bullCase),
    ]

    if let rationale = request.rationale, !rationale.isEmpty {
      params["rationale"] = rationale
    }

    if let targetDate = request.targetDate, !targetDate.isEmpty {
      params["targetDate"] = targetDate
    }

    return params
  }

  static func priceRangeJSONObject(low: Double, high: Double) -> JSONObject {
    [
      "low": low,
      "high": high,
    ]
  }

  static func valuationJSONObject(
    symbol: String,
    bearLow: Double,
    bearHigh: Double,
    baseLow: Double,
    baseHigh: Double,
    bullLow: Double,
    bullHigh: Double,
    rationale: String?,
    targetDate: String?
  ) -> JSONObject {
    var json: JSONObject = [
      "symbol": symbol,
      "bearCase": priceRangeJSONObject(low: bearLow, high: bearHigh),
      "baseCase": priceRangeJSONObject(low: baseLow, high: baseHigh),
      "bullCase": priceRangeJSONObject(low: bullLow, high: bullHigh),
    ]

    if let rationale, !rationale.isEmpty {
      json["rationale"] = rationale
    }

    if let targetDate, !targetDate.isEmpty {
      json["targetDate"] = targetDate
    }

    return json
  }

  static func valuationBodyData(
    symbol: String,
    draft: StockValuationDraft
  ) throws -> Data {
    print(
      """
      StockEncoding.valuationBodyData(draft:) \
      symbol=\(symbol) \
      bearLow=\(draft.bearLow) bearHigh=\(draft.bearHigh) \
      baseLow=\(draft.baseLow) baseHigh=\(draft.baseHigh) \
      bullLow=\(draft.bullLow) bullHigh=\(draft.bullHigh) \
      rationale=\(draft.rationale ?? "<nil>") \
      targetDate=\(draft.targetDate ?? "<nil>")
      """
    )
    let payload = StockValuationBody(
      symbol: symbol,
      bearCase: .init(low: draft.bearLow, high: draft.bearHigh),
      baseCase: .init(low: draft.baseLow, high: draft.baseHigh),
      bullCase: .init(low: draft.bullLow, high: draft.bullHigh),
      rationale: draft.rationale,
      targetDate: draft.targetDate
    )
    let data = try JSONEncoder().encode(payload)
    if let json = String(data: data, encoding: .utf8) {
      print("StockEncoding.valuationBodyData(draft:) body=\(json)")
    }
    return data
  }

  static func valuationBodyData(
    symbol: String,
    bearLow: Double,
    bearHigh: Double,
    baseLow: Double,
    baseHigh: Double,
    bullLow: Double,
    bullHigh: Double,
    rationale: String?,
    targetDate: String?
  ) throws -> Data {
    let payload = StockValuationBody(
      symbol: symbol,
      bearCase: .init(low: bearLow, high: bearHigh),
      baseCase: .init(low: baseLow, high: baseHigh),
      bullCase: .init(low: bullLow, high: bullHigh),
      rationale: rationale,
      targetDate: targetDate
    )
    return try JSONEncoder().encode(payload)
  }
}

struct CreateStockEndpoint: Endpoint {
  typealias Response = StockResponse

  let symbol: String
  let shares: Double
  let buyPrice: Double
  let buyDate: String?
  let notes: String?

  var method: HTTPMethod { .post }
  var path: String { "/v1/stocks" }
  var decoder: JSONDecoder { StockDecoding.decoder() }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    params["symbol"] = symbol
    params["shares"] = shares
    params["buyPrice"] = buyPrice
    if let buyDate { params["buyDate"] = buyDate }
    if let notes, !notes.isEmpty { params["notes"] = notes }
    return params
  }
}

struct BulkCreateStocksResponse: Codable, Equatable {
  let created: Int
  let failed: Int
  let results: [BulkCreateStocksItem]
}

struct BulkCreateStocksItem: Codable, Equatable {
  let index: Int
  let stock: StockResponse?
  let error: String?
}

struct BulkCreateStocksEndpoint: Endpoint {
  typealias Response = BulkCreateStocksResponse
  let stocks: [StockRequest]

  var method: HTTPMethod { .post }
  var path: String { "/v1/stocks/bulk" }
  var decoder: JSONDecoder { StockDecoding.decoder() }

  func asParameters() throws -> Parameters {
    // Encode array of StockRequest into JSON-compatible Parameters
    let data = try JSONEncoder().encode(stocks)
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
  var decoder: JSONDecoder { StockDecoding.decoder() }

  func asParameters() throws -> Parameters { [:] }
}

struct UpdateStockEndpoint: Endpoint {
  typealias Response = StockResponse
  let stockId: String
  let payload: StockRequest

  var method: HTTPMethod { .put }
  var path: String { "/v1/stocks/\(stockId)" }
  var decoder: JSONDecoder { StockDecoding.decoder() }

  func asParameters() throws -> Parameters {
    try StockEncoding.parameters(for: payload)
  }
}

struct DeleteStockEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse

  let stockId: String

  var method: HTTPMethod { .delete }
  var path: String { "/v1/stocks/\(stockId)" }
  var decoder: JSONDecoder { StockDecoding.decoder() }

  func asParameters() throws -> Parameters { [:] }
}
struct GetStockDetailsEndpoint: Endpoint {
  typealias Response = StockDetails
  let stockId: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/stocks/\(stockId)" }
  var decoder: JSONDecoder { StockDecoding.decoder() }

  func asParameters() throws -> Parameters { [:] }
}

struct GetStockHistoryEndpoint: Endpoint {
  typealias Response = [StockHistory]
  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/history" }
  var decoder: JSONDecoder { StockDecoding.decoder() }

  func asParameters() throws -> Parameters {
    ["symbol": symbol]
  }
}

struct GetStockNewsEndpoint: Endpoint {
  typealias Response = [StockNews]
  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/news" }
  var decoder: JSONDecoder { StockDecoding.decoder() }

  func asParameters() throws -> Parameters {
    ["symbol": symbol]
  }
}

struct GetStockValuationEndpoint: Endpoint {
  typealias Response = StockValuationRequest

  let symbol: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/stocks/symbol/\(symbol)/valuation" }
  var decoder: JSONDecoder { StockDecoding.decoder() }

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
    body = try StockEncoding.valuationBodyData(
      symbol: symbol,
      draft: draft
    )
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
    body = try StockEncoding.valuationBodyData(
      symbol: symbol,
      bearLow: bearLow,
      bearHigh: bearHigh,
      baseLow: baseLow,
      baseHigh: baseHigh,
      bullLow: bullLow,
      bullHigh: bullHigh,
      rationale: rationale,
      targetDate: targetDate
    )
  }

  var method: HTTPMethod { .post }
  var decoder: JSONDecoder { StockDecoding.decoder() }

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
    body = try StockEncoding.valuationBodyData(
      symbol: symbol,
      draft: draft
    )
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
    body = try StockEncoding.valuationBodyData(
      symbol: symbol,
      bearLow: bearLow,
      bearHigh: bearHigh,
      baseLow: baseLow,
      baseHigh: baseHigh,
      bullLow: bullLow,
      bullHigh: bullHigh,
      rationale: rationale,
      targetDate: targetDate
    )
  }

  var method: HTTPMethod { .put }
  var decoder: JSONDecoder { StockDecoding.decoder() }

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
  var decoder: JSONDecoder { StockDecoding.decoder() }

  func asParameters() throws -> Parameters { [:] }
}

struct CreateWatchlistEndpoint: Endpoint {
  typealias Response = WatchlistItemResponse
  let payload: WatchlistItemRequest

  var method: HTTPMethod { .post }
  var path: String { "/v1/watchlist" }
  var decoder: JSONDecoder { StockDecoding.decoder() }

  func asParameters() throws -> Parameters {
    try StockEncoding.parameters(for: payload)
  }
}

struct UpdateWatchlistEndpoint: Endpoint {
  typealias Response = WatchlistItemResponse
  let watchlistId: String
  let payload: WatchlistItemUpdateRequest

  var method: HTTPMethod { .patch }
  var path: String { "/v1/watchlist/\(watchlistId)" }
  var decoder: JSONDecoder { StockDecoding.decoder() }

  func asParameters() throws -> Parameters {
    try StockEncoding.parameters(for: payload)
  }
}

struct DeleteWatchlistEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let watchlistId: String

  var method: HTTPMethod { .delete }
  var path: String { "/v1/watchlist/\(watchlistId)" }
  var decoder: JSONDecoder { StockDecoding.decoder() }

  func asParameters() throws -> Parameters { [:] }
}
