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
  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
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
    return try await call(endpoint)
  }

  func register(_ request: AuthRegisterRequest) async throws {
    let endpoint = SignupEndpoint(
      username: request.username,
      email: request.email,
      password: request.password,
      firstName: request.firstName,
      lastName: request.lastName,
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
    return try await call(endpoint)
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
