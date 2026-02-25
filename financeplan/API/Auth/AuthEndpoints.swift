import AnyAPI
import Foundation
import StockPlanShared

private enum AuthDecoding {
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

struct LoginEndpoint: Endpoint {
  typealias Response = AuthResponse

  let email: String
  let password: String

  var method: HTTPMethod { .post }
  var path: String { "/auth/login" }
  var decoder: JSONDecoder { AuthDecoding.decoder() }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    params["email"] = email
    params["password"] = password
    return params
  }
}

struct SignupEndpoint: Endpoint {
  typealias Response = AuthResponse

  let username: String
  let email: String
  let password: String
  let firstName: String
  let lastName: String
  let dateOfBirth: Date

  var method: HTTPMethod { .post }
  var path: String { "/auth/register" }
  var decoder: JSONDecoder { AuthDecoding.decoder() }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    params["username"] = username
    params["email"] = email
    params["password"] = password
    params["firstName"] = firstName
    params["lastName"] = lastName
    params["dateOfBirth"] = Self.formatter.string(from: dateOfBirth)
    return params
  }

  private static let formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = .init(secondsFromGMT: 0)
    return formatter
  }()
}

struct ForgotPasswordEndpoint: Endpoint {
  typealias Response = AuthForgotPasswordResponse

  let email: String

  var method: HTTPMethod { .post }
  var path: String { "/auth/forgot-password" }
  var decoder: JSONDecoder { AuthDecoding.decoder() }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    params["email"] = email
    return params
  }
}

struct LogoutEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse

  let refreshToken: String
  let endpointPath: String

  var method: HTTPMethod { .post }
  var path: String { endpointPath }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    params["refreshToken"] = refreshToken
    return params
  }
}

struct EmptyAPIResponse: Decodable {}
