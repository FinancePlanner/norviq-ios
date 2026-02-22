import Foundation
import StockPlanShared

protocol AuthURLSessionProtocol {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: AuthURLSessionProtocol {}

struct APIErrorResponse: Decodable {
  let error: String
}

struct AuthHTTPClient {
  private struct RegisterRequestBody: Encodable {
    let username: String
    let password: String
    let email: String
    let firstName: String
    let lastName: String
    let dateOfBirth: String

    init(from request: AuthRegisterRequest) {
      username = request.username
      password = request.password
      email = request.email
      firstName = request.firstName
      lastName = request.lastName
      dateOfBirth = request.dateOfBirth.formatted(.iso8601)
    }
  }

  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

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
    try await post(path: "/auth/login", body: request, as: AuthResponse.self)
  }

  func register(_ request: AuthRegisterRequest) async throws -> AuthResponse {
    let body = RegisterRequestBody(from: request)
    return try await post(path: "/auth/register", body: body, as: AuthResponse.self)
  }

  func forgotPassword(_ request: AuthForgotPasswordRequest) async throws -> AuthForgotPasswordResponse {
    try await post(path: "/auth/forgot-password", body: request, as: AuthForgotPasswordResponse.self)
  }

  private func post<Body: Encodable, Response: Decodable>(
    path: String,
    body: Body,
    as _: Response.Type
  ) async throws -> Response {
    let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let url = baseURL.appendingPathComponent(normalizedPath)

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try Self.encoder.encode(body)

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw Error.invalidResponse
    }

    guard (200 ..< 300).contains(httpResponse.statusCode) else {
      if let decodedError = try? Self.decoder.decode(APIErrorResponse.self, from: data) {
        throw Error.api(decodedError.error)
      }
      throw Error.invalidStatus(httpResponse.statusCode)
    }

    return try Self.decoder.decode(Response.self, from: data)
  }
}
