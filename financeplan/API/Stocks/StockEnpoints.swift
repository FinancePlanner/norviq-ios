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
    let data = try JSONEncoder().encode(payload)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    return json
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
