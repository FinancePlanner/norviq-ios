import AnyAPI
import Foundation
import OSLog
import StockPlanShared

nonisolated struct GamificationHTTPClient: Sendable {
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

  static let timezoneHeader = "X-Timezone"

  private let client: BaseHTTPClient

  init(
    baseURL: URL,
    session: any HTTPClientSession = URLSession.shared,
    authTokenProvider: @escaping @Sendable () async -> String? = { nil },
    timeZoneProvider: @escaping @Sendable () -> TimeZone = { TimeZone.current }
  ) {
    self.client = BaseHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: authTokenProvider,
      // The server keys check-ins and "this week" by the user's local day.
      extraHeadersProvider: { _ in [(name: Self.timezoneHeader, value: timeZoneProvider().identifier)] },
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "GamificationHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func xpSummary() async throws -> XPSummary {
    try await client.call(GetXPSummaryEndpoint(), errorType: Error.self)
  }

  func xpEvents(cursor: String?) async throws -> XPHistoryResponse {
    try await client.call(GetXPEventsEndpoint(cursor: cursor), errorType: Error.self)
  }

  func streaks() async throws -> StreakSummary {
    try await client.call(GetStreaksEndpoint(), errorType: Error.self)
  }

  func checkIn() async throws -> CheckInResponse {
    try await client.call(CheckInEndpoint(), errorType: Error.self)
  }

  func reportBudgetStreak(months: Int) async throws -> StreakSummary {
    try await client.call(
      ReportBudgetStreakEndpoint(payload: BudgetStreakReport(months: months)),
      errorType: Error.self
    )
  }

  func leaderboard(metric: LeaderboardMetric, period: LeaderboardPeriod) async throws -> LeaderboardResponse {
    try await client.call(GetLeaderboardEndpoint(metric: metric, period: period), errorType: Error.self)
  }
}
