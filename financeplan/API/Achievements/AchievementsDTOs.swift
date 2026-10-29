import Foundation

// Achievements DTOs. App-local like the Social ones; the contract is the
// backend's openapi.yaml (Achievements tag). Titles and descriptions come
// localized from the server (Accept-Language), so they are not catalogued.

nonisolated enum AchievementState: String, Codable, Sendable, Hashable {
  case earned
  case inProgress
  case locked
  case hidden

  /// A newer server state must not break decoding of the whole catalogue.
  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = AchievementState(rawValue: raw) ?? .locked
  }
}

nonisolated struct AchievementProgress: Codable, Sendable, Hashable {
  let current: Int
  let target: Int
}

nonisolated struct AchievementTier: Codable, Sendable, Hashable {
  /// `bronze`, `silver`, `gold`, or empty for a single-tier achievement.
  let tier: String
  /// Nil for hidden achievements the viewer has not earned.
  let threshold: Int?
  let xp: Int
  let unlockId: String?
  let unlockedAt: Date?
  let showcaseRank: Int?
}

nonisolated struct Achievement: Codable, Sendable, Hashable, Identifiable {
  /// Opaque (`hidden.<n>`) while a hidden achievement is still locked.
  let key: String
  let category: String
  let title: String
  let description: String
  /// An SF Symbol name.
  let iconKey: String
  let state: AchievementState
  /// Highest earned tier; empty for an earned single-tier achievement.
  let currentTier: String?
  /// Toward the next tier. Never sent for performance or hidden achievements.
  let progress: AchievementProgress?
  let isPerformance: Bool
  let tiers: [AchievementTier]

  var id: String { key }
}

nonisolated struct AchievementCategory: Codable, Sendable, Hashable, Identifiable {
  let key: String
  let title: String

  var id: String { key }
}

nonisolated struct AchievementSummary: Codable, Sendable, Hashable {
  let unlocked: Int
  let total: Int
  let hiddenRemaining: Int
}

nonisolated struct AchievementsResponse: Codable, Sendable, Hashable {
  let summary: AchievementSummary
  let categories: [AchievementCategory]
  let achievements: [Achievement]
}

/// One new unlock, as `/v1/achievements/unseen` returns it.
nonisolated struct AchievementUnlock: Codable, Sendable, Hashable, Identifiable {
  let id: String
  let key: String
  let tier: String
  let title: String
  let description: String
  let iconKey: String
  let xp: Int
  let unlockedAt: Date
}

nonisolated struct AchievementSeenRequest: Codable, Sendable, Hashable {
  let ids: [String]
}

nonisolated struct AchievementShowcaseItem: Codable, Sendable, Hashable {
  let key: String
  let tier: String
}

nonisolated struct AchievementShowcaseRequest: Codable, Sendable, Hashable {
  let items: [AchievementShowcaseItem]
}

/// What a friend's profile shows of their pinned (or best) achievements.
nonisolated struct AchievementShowcaseEntry: Codable, Sendable, Hashable {
  let key: String
  let tier: String
  let title: String
  let iconKey: String
}
