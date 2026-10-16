import AnyAPI
import Foundation
import OSLog
import StockPlanShared

/// `/v1/market/brief` and its notification preferences.
nonisolated struct MarketBriefHTTPClient: Sendable {
  enum Error: HTTPClientError {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)

    nonisolated var errorDescription: String? {
      switch self {
      case .invalidResponse: return "Invalid server response."
      case let .invalidStatus(code): return "Request failed (\(code))."
      case let .unauthorized(message): return message ?? "Your session expired."
      case let .api(message): return message
      }
    }

    nonisolated var statusCode: Int? {
      if case let .invalidStatus(code) = self { return code }
      return nil
    }

    nonisolated static func == (lhs: Error, rhs: Error) -> Bool {
      switch (lhs, rhs) {
      case (.invalidResponse, .invalidResponse): return true
      case let (.invalidStatus(l), .invalidStatus(r)): return l == r
      case let (.unauthorized(l), .unauthorized(r)): return l == r
      case let (.api(l), .api(r)): return l == r
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
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "MarketBriefHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func brief(lang: String, slot: MarketBriefSlot?, date: String?) async throws -> MarketBriefResponse {
    try await client.call(GetMarketBriefEndpoint(lang: lang, slot: slot, date: date), errorType: Error.self)
  }

  func notificationPreferences() async throws -> MarketBriefNotificationPreferences {
    try await client.call(GetMarketBriefNotificationsEndpoint(), errorType: Error.self)
  }

  func updateNotificationPreferences(enabled: Bool, language: String) async throws -> MarketBriefNotificationPreferences {
    try await client.call(
      UpdateMarketBriefNotificationsEndpoint(enabled: enabled, language: language),
      errorType: Error.self
    )
  }
}
