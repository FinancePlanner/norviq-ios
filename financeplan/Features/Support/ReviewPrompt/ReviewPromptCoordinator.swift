import Foundation
import Observation

/// A moment worth asking for a review at. Each case fires at most once, ever.
enum ReviewTrigger: Equatable, Sendable {
  /// The user has opened the app on seven distinct days.
  case sevenActiveDays
  /// A financial goal reached its target.
  case goalCompleted(goalID: String)
  /// The user closed out a compliant budget month.
  case budgetStreakReached(months: Int)
  /// A badge tier was earned.
  case badgeTierEarned(badgeID: String, tier: String)

  /// Stable identity for one-shot bookkeeping. Goals and badges are keyed individually so
  /// a second goal can still earn its own prompt; the streak is keyed by month count so
  /// only the *first* compliant month qualifies.
  var persistenceIdentifier: String {
    switch self {
    case .sevenActiveDays:
      "seven_active_days"
    case let .goalCompleted(goalID):
      "goal_completed.\(goalID)"
    case let .budgetStreakReached(months):
      "budget_streak.\(months)"
    case let .badgeTierEarned(badgeID, tier):
      "badge_earned.\(badgeID).\(tier)"
    }
  }

  var analyticsName: String {
    switch self {
    case .sevenActiveDays: "seven_active_days"
    case .goalCompleted: "goal_completed"
    case .budgetStreakReached: "budget_streak_reached"
    case .badgeTierEarned: "badge_tier_earned"
    }
  }
}

/// Something that suggests the user is *not* currently delighted. Asking for a review in
/// the days after one of these converts a neutral user into a one-star review.
enum FrictionKind: String, Sendable {
  case feedbackSubmitted = "feedback_submitted"
  case importFailed = "import_failed"
  case authFailure = "auth_failure"
}

/// Why a considered trigger did not produce a prompt. Reported to analytics so the funnel
/// is diagnosable — without this there is no way to tell "never triggered" from
/// "triggered and suppressed".
enum ReviewPromptSuppression: String, Sendable {
  case noUser = "no_user"
  case alreadyFired = "already_fired"
  case withinCooldown = "within_cooldown"
  case belowEngagementFloor = "below_engagement_floor"
  case recentFriction = "recent_friction"
  case notEligibleContext = "not_eligible_context"
}

@MainActor
protocol ReviewPromptCoordinating {
  /// True when a prompt has been earned and is waiting for the view layer to present it.
  var pendingPrompt: Bool { get }

  func recordAppOpen(userID: String)
  func noteFriction(_ kind: FrictionKind, userID: String)
  func consider(_ trigger: ReviewTrigger, userID: String)

  /// Called by the presenter once `requestReview()` has actually been invoked.
  func markPromptShown(userID: String)

  /// Suppresses prompts while onboarding, a paywall, or any sheet is on screen.
  func setContextEligible(_ isEligible: Bool)
}

@MainActor
@Observable
final class ReviewPromptCoordinator: ReviewPromptCoordinating {
  /// Tuning. Deliberately conservative: iOS allows roughly three prompts per user per
  /// year, so the cooldown is sized to spend them across the year rather than in a week.
  enum Policy {
    static let requiredActiveDays = 7
    static let minimumActiveDaysBeforeAnyPrompt = 5
    static let minimumDaysSinceFirstSeen = 3
    static let promptCooldownDays = 120
    static let frictionQuietDays = 7
    /// Budget-streak lengths worth asking at. Every month would offer a new candidate and
    /// rely on the cooldown alone to stay quiet.
    static let budgetStreakMilestones: Set<Int> = [1, 3, 6, 12]
  }

  /// UTC so that a day boundary means the same thing regardless of travel.
  nonisolated static let defaultCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
  }()

  private(set) var pendingPrompt = false

  private let store: ReviewPromptStoring
  private let analytics: AnalyticsService?
  private let now: @Sendable () -> Date
  private let calendar: Calendar
  private var isContextEligible = true

  init(
    store: ReviewPromptStoring = UserDefaultsReviewPromptStore(),
    analytics: AnalyticsService? = nil,
    calendar: Calendar = ReviewPromptCoordinator.defaultCalendar,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.store = store
    self.analytics = analytics
    self.calendar = calendar
    self.now = now
  }

  // MARK: - Signals in

  func recordAppOpen(userID: String) {
    guard !userID.isEmpty else { return }
    let today = now()
    store.setFirstSeenIfNeeded(today, for: userID)
    store.recordActiveDay(dayKey(for: today), for: userID)

    if store.activeDays(for: userID).count >= Policy.requiredActiveDays {
      consider(.sevenActiveDays, userID: userID)
    }
  }

  func noteFriction(_ kind: FrictionKind, userID: String) {
    guard !userID.isEmpty else { return }
    store.setLastFrictionDate(now(), for: userID)
    // A prompt already queued but not yet shown is withdrawn — the friction is more
    // recent than the milestone that earned it.
    pendingPrompt = false
    analytics?.track("review_prompt_friction_noted", properties: ["kind": kind.rawValue])
  }

  func setContextEligible(_ isEligible: Bool) {
    isContextEligible = isEligible
  }

  // MARK: - The decision

  func consider(_ trigger: ReviewTrigger, userID: String) {
    guard !userID.isEmpty else {
      report(trigger, suppressedBy: .noUser)
      return
    }

    if let reason = suppressionReason(for: trigger, userID: userID) {
      report(trigger, suppressedBy: reason)
      return
    }

    // Spend the trigger at decision time, not at presentation time. The system may show
    // nothing at all, and re-asking on the next launch would burn the yearly allowance
    // against a moment that has already passed.
    store.markTriggerFired(trigger.persistenceIdentifier, for: userID)
    pendingPrompt = true
    analytics?.track(
      "review_prompt_considered",
      properties: ["trigger": trigger.analyticsName, "outcome": "queued"]
    )
  }

  func markPromptShown(userID: String) {
    guard !userID.isEmpty else { return }
    pendingPrompt = false
    store.setLastPromptDate(now(), for: userID)
    analytics?.track("review_prompt_shown", properties: [:])
  }

  // MARK: - Gating

  /// Returns the first rule that blocks this trigger, or `nil` when every rule passes.
  private func suppressionReason(
    for trigger: ReviewTrigger,
    userID: String
  ) -> ReviewPromptSuppression? {
    guard isContextEligible else { return .notEligibleContext }

    guard !store.firedTriggers(for: userID).contains(trigger.persistenceIdentifier) else {
      return .alreadyFired
    }

    let today = now()

    if let lastPrompt = store.lastPromptDate(for: userID),
       days(from: lastPrompt, to: today) < Policy.promptCooldownDays {
      return .withinCooldown
    }

    if let lastFriction = store.lastFrictionDate(for: userID),
       days(from: lastFriction, to: today) < Policy.frictionQuietDays {
      return .recentFriction
    }

    guard store.activeDays(for: userID).count >= Policy.minimumActiveDaysBeforeAnyPrompt else {
      return .belowEngagementFloor
    }

    guard let firstSeen = store.firstSeen(for: userID),
          days(from: firstSeen, to: today) >= Policy.minimumDaysSinceFirstSeen else {
      return .belowEngagementFloor
    }

    return nil
  }

  private func report(_ trigger: ReviewTrigger, suppressedBy reason: ReviewPromptSuppression) {
    analytics?.track(
      "review_prompt_suppressed",
      properties: ["trigger": trigger.analyticsName, "reason": reason.rawValue]
    )
  }

  // MARK: - Dates

  private func dayKey(for date: Date) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(
      format: "%04d-%02d-%02d",
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0
    )
  }

  /// Whole calendar days between two instants, floored at zero so a clock that moves
  /// backwards cannot unlock a gate.
  private func days(from start: Date, to end: Date) -> Int {
    let startDay = calendar.startOfDay(for: start)
    let endDay = calendar.startOfDay(for: end)
    return max(0, calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0)
  }
}
