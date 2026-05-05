import Foundation

struct EarningsNotificationPreferencesResponse: Sendable, Equatable {
  let enabled: Bool
  let leadDays: [Int]
  let scope: String

  nonisolated init(enabled: Bool, leadDays: [Int] = [7, 1], scope: String = "portfolio_and_watchlist") {
    self.enabled = enabled
    self.leadDays = leadDays
    self.scope = scope
  }
}

struct UpdateEarningsNotificationPreferencesRequest: Sendable, Equatable {
  let enabled: Bool
}

nonisolated extension EarningsNotificationPreferencesResponse: Codable {}
nonisolated extension UpdateEarningsNotificationPreferencesRequest: Codable {}
