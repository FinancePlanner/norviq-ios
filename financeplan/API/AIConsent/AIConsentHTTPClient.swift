import AnyAPI
import Foundation
import OSLog
import StockPlanShared

/// `GET|POST|DELETE /v1/users/ai-consent` → `{"consentedAt": "<ISO8601>" | null}`.
nonisolated struct AIConsentDTO: Codable, Sendable, Equatable {
  /// Kept as the raw string: only nil vs. non-nil matters to the app.
  let consentedAt: String?
}

protocol AIConsentClientProtocol: Sendable {
  func get() async throws -> AIConsentDTO
  func grant() async throws -> AIConsentDTO
  func revoke() async throws -> AIConsentDTO
}

nonisolated struct AIConsentHTTPClient: AIConsentClientProtocol {
  enum Error: HTTPClientError {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)
    /// Any other non-2xx, keeping the status: 400/404 mean "backend predates
    /// the consent route", which the store treats differently from an outage.
    case rejected(status: Int, message: String?)

    nonisolated var errorDescription: String? {
      switch self {
      case .invalidResponse:
        return "Invalid server response."
      case let .invalidStatus(code):
        return "Request failed (\(code))."
      case let .unauthorized(message):
        return message ?? "Your session expired. Please sign in again."
      case let .api(message):
        return message
      case let .rejected(status, message):
        return message ?? "Request failed (\(status))."
      }
    }

    nonisolated var statusCode: Int? {
      switch self {
      case let .invalidStatus(code), let .rejected(code, _): return code
      default: return nil
      }
    }

    nonisolated static func == (lhs: Error, rhs: Error) -> Bool {
      switch (lhs, rhs) {
      case (.invalidResponse, .invalidResponse): return true
      case let (.invalidStatus(l), .invalidStatus(r)): return l == r
      case let (.unauthorized(l), .unauthorized(r)): return l == r
      case let (.api(l), .api(r)): return l == r
      case let (.rejected(ls, lm), .rejected(rs, rm)): return ls == rs && lm == rm
      default: return false
      }
    }

    static func makeInvalidResponse() -> Error { .invalidResponse }
    static func makeInvalidStatus(_ code: Int) -> Error { .invalidStatus(code) }
    static func makeUnauthorized(_ message: String?) -> Error { .unauthorized(message) }
    static func makeAPI(_ message: String) -> Error { .api(message) }
    static func makeStatus(_ code: Int, message: String?) -> Error { .rejected(status: code, message: message) }
  }

  private let client: BaseHTTPClient

  init(
    baseURL: URL,
    session: any HTTPClientSession = URLSession.shared,
    authTokenProvider: @escaping @Sendable () async -> String? = { nil }
  ) {
    self.client = BaseHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: authTokenProvider,
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "AIConsentHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func get() async throws -> AIConsentDTO {
    try await client.call(AIConsentEndpoint(method: .get), errorType: Error.self)
  }

  func grant() async throws -> AIConsentDTO {
    try await client.call(AIConsentEndpoint(method: .post), errorType: Error.self)
  }

  func revoke() async throws -> AIConsentDTO {
    try await client.call(AIConsentEndpoint(method: .delete), errorType: Error.self)
  }
}

nonisolated struct AIConsentEndpoint: Endpoint {
  typealias Response = AIConsentDTO

  let method: HTTPMethod
  var path: String { "/v1/users/ai-consent" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }

  func encode(to _: Encoder) throws {}
}
