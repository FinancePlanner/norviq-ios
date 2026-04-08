import AnyAPI
import Foundation
import OSLog
import StockPlanShared

protocol AuthURLSessionProtocol {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: AuthURLSessionProtocol {}

private let authHTTPLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
  category: "AuthHTTPClient"
)

struct AuthHTTPClient {
  private static let decoder: JSONDecoder = .stockPlanShared
  private static let dbStyleDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
    return formatter
  }()


  enum Error: LocalizedError, Equatable {
    case invalidResponse
    case invalidStatus(Int)
    case api(String)

    var errorDescription: String? {
      switch self {
      case .invalidResponse:
        return "Invalid server response."
      case let .invalidStatus(code):
        return "Request failed (\(code))."
      case let .api(message):
        return message
      }
    }
  }

  let baseURL: URL
  let session: AuthURLSessionProtocol

  init(baseURL: URL, session: AuthURLSessionProtocol) {
    self.baseURL = baseURL
    self.session = session
  }

  func login(_ request: AuthLoginRequest) async throws -> AuthResponse {
    let endpoint = LoginEndpoint(email: request.email, password: request.password)
    let data = try await perform(endpoint)
    return try decodeAuthResponse(from: data)
  }

  func register(_ request: AuthRegisterRequest) async throws {
    let endpoint = SignupEndpoint(
      username: request.username,
      email: request.email,
      password: request.password,
      dateOfBirth: request.dateOfBirth
    )
    try await callWithoutResponse(endpoint)
  }

  func forgotPassword(_ request: AuthForgotPasswordRequest) async throws -> AuthForgotPasswordResponse {
    let endpoint = ForgotPasswordEndpoint(email: request.email)
    return try await call(endpoint)
  }

  func refresh(_ request: AuthRefreshRequest) async throws -> AuthResponse {
    let endpoint = RefreshEndpoint(refreshToken: request.refreshToken)
    let data = try await perform(endpoint)
    return try decodeAuthResponse(from: data)
  }

  func logout(_ request: AuthRefreshRequest) async throws {
    let primary = LogoutEndpoint(refreshToken: request.refreshToken, endpointPath: "/v2/logout")
    do {
      try await callWithoutResponse(primary)
    } catch Error.invalidStatus(404) {
      // Backward-compatible fallback while servers migrate endpoint versions.
      let fallback = LogoutEndpoint(refreshToken: request.refreshToken, endpointPath: "/auth/logout")
      try await callWithoutResponse(fallback)
    }
  }

  private func call<E: Endpoint>(_ endpoint: E) async throws -> E.Response
    where E.Response: Codable & Sendable
  {
    let data = try await perform(endpoint)
    do {
      return try endpoint.decode(data)
    } catch {
      if let envelope = try? endpoint.decoder.decode(APIEnvelope<E.Response>.self, from: data) {
        if let payload = envelope.data {
          return payload
        }
        if let message = envelope.message, !message.isEmpty {
          throw Error.api(message)
        }
      }
      throw error
    }
  }

  private func callWithoutResponse<E: Endpoint>(_ endpoint: E) async throws {
    _ = try await perform(endpoint)
  }

  private func perform<E: Endpoint>(_ endpoint: E) async throws -> Data {
    let request = try makeURLRequest(for: endpoint)
    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw Error.invalidResponse
    }

    if endpoint.path == "/v1/auth/login" || endpoint.path == "/auth/register" {
      authHTTPLogger.debug(
        "Auth response [\(endpoint.path, privacy: .public)] status=\(httpResponse.statusCode, privacy: .public)"
      )
    }

    guard (200 ..< 300).contains(httpResponse.statusCode) else {
      if let message = errorMessage(from: data),
         !message.isEmpty {
        throw Error.api(message)
      }
      throw Error.invalidStatus(httpResponse.statusCode)
    }

    return data
  }

  private func makeURLRequest<E: Endpoint>(for endpoint: E) throws -> URLRequest {
    let normalizedPath = endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let base = baseURL.appendingPathComponent(normalizedPath)

    let parameters = try endpoint.asParameters()
    let url = try url(for: endpoint.method, baseURL: base, parameters: parameters)

    var request = URLRequest(url: url)
    request.httpMethod = endpoint.method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    for header in endpoint.headers {
      request.setValue(header.value, forHTTPHeaderField: header.name)
    }

    if endpoint.method != .get, !parameters.isEmpty {
      request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
    }

    logRequest(endpointPath: endpoint.path, method: endpoint.method, parameters: parameters)
    return request
  }

  private func url(for method: HTTPMethod, baseURL: URL, parameters: Parameters) throws -> URL {
    guard method == .get, !parameters.isEmpty else {
      return baseURL
    }

    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    components?.queryItems = parameters.compactMap { key, value in
      URLQueryItem(name: key, value: String(describing: value))
    }

    guard let url = components?.url else {
      throw Error.invalidResponse
    }

    return url
  }

  private func errorMessage(from data: Data) -> String? {
    if let stockError = try? Self.decoder.decode(StockPlanShared.APIErrorResponse.self, from: data),
       !stockError.error.isEmpty {
      return stockError.error
    }

    if let stockEnvelope = try? Self.decoder.decode(APIEnvelope<StockPlanShared.APIErrorResponse>.self, from: data) {
      if let nestedError = stockEnvelope.data?.error, !nestedError.isEmpty {
        return nestedError
      }
      if let message = stockEnvelope.message, !message.isEmpty {
        return message
      }
    }

    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      if let error = json["error"] as? String, !error.isEmpty {
        return error
      }
      if let reason = json["reason"] as? String, !reason.isEmpty {
        return reason
      }
      if let message = json["message"] as? String, !message.isEmpty {
        return message
      }
      if let detail = json["detail"] as? String, !detail.isEmpty {
        return detail
      }
    }

    if let body = String(data: data, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !body.isEmpty {
      return body
    }

    return nil
  }

  private func decodeAuthResponse(from data: Data) throws -> AuthResponse {
    do {
      return try Self.decoder.decode(AuthResponse.self, from: data)
    } catch {
      if let envelope = try? Self.decoder.decode(APIEnvelope<AuthResponse>.self, from: data),
         let payload = envelope.data {
        return payload
      }

      if let payload = try? decodeAuthResponseFallback(from: data) {
        return payload
      }

      throw error
    }
  }

  private func decodeAuthResponseFallback(from data: Data) throws -> AuthResponse {
    let jsonObject = try JSONSerialization.jsonObject(with: data)
    guard let root = jsonObject as? [String: Any] else {
      throw Error.invalidResponse
    }

    let payload: [String: Any]
    if let nested = root["data"] as? [String: Any] {
      payload = nested
    } else {
      payload = root
    }

    return try AuthResponse(
      token: requireString(in: payload, camel: "token"),
      userId: requireUUID(in: payload, camel: "userId", snake: "user_id"),
      expiresIn: requireInt(in: payload, camel: "expiresIn", snake: "expires_in"),
      refreshToken: requireString(in: payload, camel: "refreshToken", snake: "refresh_token"),
      refreshExpiresIn: requireInt(in: payload, camel: "refreshExpiresIn", snake: "refresh_expires_in"),
      username: requireString(in: payload, camel: "username"),
      email: requireString(in: payload, camel: "email"),
      dateOfBirth: requireDate(in: payload, camel: "dateOfBirth", snake: "date_of_birth")
    )
  }

  private func requireString(in payload: [String: Any], camel: String, snake: String? = nil) throws -> String {
    if let value = payload[camel] as? String {
      return value
    }
    if let snake, let value = payload[snake] as? String {
      return value
    }
    throw Error.invalidResponse
  }

  private func requireUUID(in payload: [String: Any], camel: String, snake: String? = nil) throws -> UUID {
    let raw = try requireString(in: payload, camel: camel, snake: snake)
    guard let uuid = UUID(uuidString: raw) else {
      throw Error.invalidResponse
    }
    return uuid
  }

  private func requireInt(in payload: [String: Any], camel: String, snake: String? = nil) throws -> Int {
    if let value = payload[camel] as? Int {
      return value
    }
    if let snake, let value = payload[snake] as? Int {
      return value
    }
    if let value = payload[camel] as? NSNumber {
      return value.intValue
    }
    if let snake, let value = payload[snake] as? NSNumber {
      return value.intValue
    }
    if let value = payload[camel] as? String, let parsed = Int(value) {
      return parsed
    }
    if let snake, let value = payload[snake] as? String, let parsed = Int(value) {
      return parsed
    }
    throw Error.invalidResponse
  }

  private func requireDate(in payload: [String: Any], camel: String, snake: String? = nil) throws -> Date {
    if let value = payload[camel], let parsed = parseDate(value) {
      return parsed
    }
    if let snake, let value = payload[snake], let parsed = parseDate(value) {
      return parsed
    }
    throw Error.invalidResponse
  }

  private func parseDate(_ rawValue: Any) -> Date? {
    switch rawValue {
    case let value as String:
      if let parsed = ISO8601DateFormatter().date(from: value) {
        return parsed
      }

      let fractionalFormatter = ISO8601DateFormatter()
      fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let parsed = fractionalFormatter.date(from: value) {
        return parsed
      }

      if let parsed = Self.dbStyleDateFormatter.date(from: value) {
        return parsed
      }

      if let parsed = DateFormatter.yyyyMMdd.date(from: value) {
        return parsed
      }

      if let seconds = Double(value) {
        return parseNumericDate(seconds)
      }

      return nil

    case let value as NSNumber:
      return parseNumericDate(value.doubleValue)

    default:
      return nil
    }
  }

  private func parseNumericDate(_ rawValue: Double) -> Date {
    if abs(rawValue) >= 1_000_000_000 {
      return Date(timeIntervalSince1970: rawValue)
    }
    return Date(timeIntervalSinceReferenceDate: rawValue)
  }

  private func logRequest(endpointPath: String, method: HTTPMethod, parameters: Parameters) {
    guard endpointPath == "/v1/auth/login" || endpointPath == "/auth/register" else {
      return
    }

    var masked = parameters
    for key in masked.keys {
      let lower = key.lowercased()
      if lower.contains("password") || lower.contains("token") {
        masked[key] = "***"
      }
    }

    let payloadDescription: String
    if let data = try? JSONSerialization.data(withJSONObject: masked, options: [.sortedKeys]),
       let json = String(data: data, encoding: .utf8) {
      payloadDescription = json
    } else {
      payloadDescription = "\(masked)"
    }

    authHTTPLogger.debug(
      "Auth request [\(method.rawValue, privacy: .public) \(endpointPath, privacy: .public)] body=\(payloadDescription, privacy: .public)"
    )
  }
}
