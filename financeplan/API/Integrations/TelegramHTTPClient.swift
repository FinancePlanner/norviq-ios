import AnyAPI
import Foundation
import OSLog
import StockPlanShared

nonisolated struct TelegramHTTPClient: Sendable {
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
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "TelegramHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func status() async throws -> TelegramStatus {
    try await client.call(TelegramStatusEndpoint(), errorType: Error.self)
  }

  func createCode() async throws -> TelegramPairingCode {
    try await client.call(TelegramCreateCodeEndpoint(), errorType: Error.self)
  }

  func disconnect() async throws {
    _ = try await client.call(TelegramDisconnectEndpoint(), errorType: Error.self)
  }

  func preferences() async throws -> [TelegramAlertPreference] {
    try await client.call(TelegramPreferencesEndpoint(), errorType: Error.self).preferences
  }

  func updatePreference(_ update: TelegramPreferenceUpdate) async throws -> [TelegramAlertPreference] {
    try await client.call(
      TelegramUpdatePreferenceEndpoint(update: update),
      errorType: Error.self
    ).preferences
  }
}
