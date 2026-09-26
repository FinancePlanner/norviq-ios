import Foundation

// Gamification DTOs (Phase 3). Like the social DTOs they live in the app until
// the backend ships them, then move to norviq-shared unchanged. The contract
// is financeplan/Documentation/social_api.md. None of them carries money.

nonisolated enum XPEventType: String, Codable, Sendable, Hashable {
  case checkIn = "check_in"
  case streakMilestone = "streak_milestone"
  case badgeEarned = "badge_earned"
  case expenseLogged = "expense_logged"
  case budgetStreakMonth = "budget_streak_month"
  case other

  /// A newer server value must not break decoding of the whole history.
  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = XPEventType(rawValue: raw) ?? .other
  }

  var title: String {
    switch self {
    case .checkIn: String(localized: "Daily check-in")
    case .streakMilestone: String(localized: "Streak milestone")
    case .badgeEarned: String(localized: "Badge earned")
    case .expenseLogged: String(localized: "Expense logged")
    case .budgetStreakMonth: String(localized: "Month on budget")
    case .other: String(localized: "XP")
    }
  }

  var symbol: String {
    switch self {
    case .checkIn: "checkmark.circle"
    case .streakMilestone: "flame"
    case .badgeEarned: "rosette"
    case .expenseLogged: "cart"
    case .budgetStreakMonth: "calendar"
    case .other: "sparkles"
    }
  }
}

nonisolated struct XPSummary: Codable, Sendable, Hashable {
  let total: Int
  let level: Int
  /// Share of the way from this level to the next, 0–1.
  let levelProgress: Double
  let weekXP: Int
}

nonisolated struct XPEvent: Codable, Sendable, Hashable, Identifiable {
  let id: String
  let type: XPEventType
  let points: Int
  let createdAt: Date
}

nonisolated struct XPHistoryResponse: Codable, Sendable, Hashable {
  let events: [XPEvent]
  let nextCursor: String?
}

nonisolated struct StreakSummary: Codable, Sendable, Hashable {
  let checkInCurrent: Int
  let checkInLongest: Int
  let budgetMonths: Int
  /// The last check-in as a local calendar day, `YYYY-MM-DD`.
  let lastCheckInDate: String?
}

nonisolated struct CheckInResponse: Codable, Sendable, Hashable {
  let streak: Int
  let xpAwarded: Int
  let alreadyCheckedIn: Bool
}

nonisolated struct BudgetStreakReport: Codable, Sendable, Hashable {
  let months: Int
}

nonisolated enum LeaderboardMetric: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
  case returnPercent = "return_percent"
  case xp
  case checkInStreak = "check_in_streak"
  case budgetStreak = "budget_streak"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .returnPercent: String(localized: "Return %")
    case .xp: String(localized: "XP")
    case .checkInStreak: String(localized: "Streak")
    case .budgetStreak: String(localized: "Budget")
    }
  }
}

nonisolated enum LeaderboardPeriod: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
  case week
  case month

  var id: String { rawValue }

  var title: String {
    switch self {
    case .week: String(localized: "This week")
    case .month: String(localized: "This month")
    }
  }
}

nonisolated struct LeaderboardEntry: Codable, Sendable, Hashable, Identifiable {
  let rank: Int
  let user: SocialUserSummary
  /// A percent for `return_percent`, otherwise a count. Never money.
  let value: Double
  let isMe: Bool

  var id: String { user.id }
}

nonisolated struct LeaderboardResponse: Codable, Sendable, Hashable {
  let metric: LeaderboardMetric
  let period: LeaderboardPeriod
  let entries: [LeaderboardEntry]
  let periodStart: Date
  let periodEnd: Date
}
