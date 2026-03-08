//
//  UserProfileEndpoints.swift
//  financeplan
//
//  Created by Fernando Correia on 07.03.26.
//

import AnyAPI
import Foundation
import StockPlanShared

private enum UserProfileDecoding {
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
    if let date = iso8601Fractional.date(from: value) { return date }
    if let date = iso8601.date(from: value) { return date }
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

struct GetUserProfileEndpoint: Endpoint {
  typealias Response = GetUserProfileResponse

  var method: HTTPMethod { .get }
  var path: String { "/v1/users" }
  var decoder: JSONDecoder { UserProfileDecoding.decoder() }

  func asParameters() throws -> Parameters { [:] }
}

struct UpdateUserProfileEndpoint: Endpoint {
  typealias Response = UpdateUserProfileResponse

  let request: UpdateUserProfileRequest

  var method: HTTPMethod { .put }
  var path: String { "/v1/users" }
  var decoder: JSONDecoder { UserProfileDecoding.decoder() }

  func asParameters() throws -> Parameters {
    let data = try JSONEncoder().encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    var params: Parameters = [:]
    for (k, v) in json { params[k] = v }
    return params
  }
}

struct DeleteUserProfileEndpoint: Endpoint {
  typealias Response = DeleteUserProfileResponse

  var method: HTTPMethod { .delete }
  var path: String { "/v1/users" }
  var decoder: JSONDecoder { UserProfileDecoding.decoder() }

  func asParameters() throws -> Parameters { [:] }
}
