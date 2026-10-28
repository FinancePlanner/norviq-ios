import AnyAPI
import Foundation
import OSLog
import StockPlanShared

nonisolated struct AchievementsHTTPClient: Sendable {
  enum Error: HTTPClientError {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)

    nonisolated var errorDescription: String? {
      switch self {
      case .invalidResponse: return "Invalid server response."
      case let .invalidStatus(code): return "Request failed (\(code))."
      case let .unauthorized(message): return message ?? "Your session expired. Please sign in again."
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
    authTokenProvider: @escaping @Sendable () async -> String? = { nil },
    languageProvider: @escaping @Sendable () -> AppLanguage = { AppLanguage.stored }
  ) {
    self.client = BaseHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: authTokenProvider,
      extraHeadersProvider: AcceptLanguageHeader.provider(languageProvider),
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "AchievementsHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func list() async throws -> AchievementsResponse {
    try await client.call(GetAchievementsEndpoint(), errorType: Error.self)
  }

  func unseen() async throws -> [AchievementUnlock] {
    try await client.call(GetUnseenAchievementsEndpoint(), errorType: Error.self)
  }

  func markSeen(ids: [String]) async throws {
    try await client.callWithoutResponse(
      MarkAchievementsSeenEndpoint(payload: AchievementSeenRequest(ids: ids)),
      errorType: Error.self
    )
  }

  func setShowcase(items: [AchievementShowcaseItem]) async throws -> AchievementsResponse {
    try await client.call(
      SetAchievementShowcaseEndpoint(payload: AchievementShowcaseRequest(items: items)),
      errorType: Error.self
    )
  }
}
