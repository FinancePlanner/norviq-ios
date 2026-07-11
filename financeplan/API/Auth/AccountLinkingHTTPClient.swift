import AnyAPI
import Foundation
import OSLog
import StockPlanShared

struct AccountLinkingHTTPClient: Sendable {
  enum Error: HTTPClientError {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)

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
      }
    }

    var isUnauthorized: Bool {
      if case .unauthorized = self {
        return true
      }
      return false
    }

    nonisolated var statusCode: Int? {
      if case let .invalidStatus(code) = self {
        return code
      }
      return nil
    }

    nonisolated static func == (lhs: Error, rhs: Error) -> Bool {
      switch (lhs, rhs) {
      case (.invalidResponse, .invalidResponse): return true
      case let (.invalidStatus(lhsCode), .invalidStatus(rhsCode)): return lhsCode == rhsCode
      case let (.unauthorized(lhsMessage), .unauthorized(rhsMessage)): return lhsMessage == rhsMessage
      case let (.api(lhsMessage), .api(rhsMessage)): return lhsMessage == rhsMessage
      default: return false
      }
    }

    static func makeInvalidResponse() -> Error { .invalidResponse }
    static func makeInvalidStatus(_ code: Int) -> Error { .invalidStatus(code) }
    static func makeUnauthorized(_ message: String?) -> Error { .unauthorized(message) }
    static func makeAPI(_ message: String) -> Error { .api(message) }
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
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "AccountLinkingHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func listLinkedAccounts() async throws -> OAuthLinkedAccountsResponse {
    try await client.call(OAuthLinkedAccountsEndpoint(), errorType: Error.self)
  }

  func linkStart(provider: OAuthProviderKind, redirectURI: String) async throws -> OAuthStartResponsePayload {
    try await client.call(
      OAuthLinkStartEndpoint(provider: provider, redirectURI: redirectURI),
      errorType: Error.self
    )
  }

  func linkExchange(
    provider: OAuthProviderKind,
    request: OAuthExchangeRequestPayload
  ) async throws -> OAuthLinkResponse {
    try await client.call(
      OAuthLinkExchangeEndpoint(provider: provider, payload: request),
      errorType: Error.self
    )
  }
}
