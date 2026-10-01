import Factory
import Foundation

protocol GamificationServicing: Sendable {
  func xpSummary() async throws -> XPSummary
  func xpEvents(cursor: String?) async throws -> XPHistoryResponse
  func streaks() async throws -> StreakSummary
  func checkIn() async throws -> CheckInResponse
  func reportBudgetStreak(months: Int) async throws -> StreakSummary
  func leaderboard(metric: LeaderboardMetric, period: LeaderboardPeriod) async throws -> LeaderboardResponse
}

struct DefaultGamificationService: GamificationServicing {
  let client: GamificationHTTPClient

  init(environmentManager: AppEnvironmentManager) {
    self.client = GamificationHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: URLSession.shared,
      authTokenProvider: { await Container.shared.authSessionStore().authToken }
    )
  }

  func xpSummary() async throws -> XPSummary { try await client.xpSummary() }
  func xpEvents(cursor: String?) async throws -> XPHistoryResponse { try await client.xpEvents(cursor: cursor) }
  func streaks() async throws -> StreakSummary { try await client.streaks() }
  func checkIn() async throws -> CheckInResponse { try await client.checkIn() }
  func reportBudgetStreak(months: Int) async throws -> StreakSummary {
    try await client.reportBudgetStreak(months: months)
  }
  func leaderboard(metric: LeaderboardMetric, period: LeaderboardPeriod) async throws -> LeaderboardResponse {
    try await client.leaderboard(metric: metric, period: period)
  }
}
