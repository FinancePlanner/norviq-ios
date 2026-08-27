import Foundation

/// Persistence for review-prompt bookkeeping.
///
/// Everything here is scoped per user ID, following the convention in
/// `UserDefaultsAuthSessionStore`: a shared device must not leak one account's prompt
/// history into another's.
protocol ReviewPromptStoring: Sendable {
  /// Distinct calendar days (`yyyy-MM-dd`, UTC) on which the user opened the app.
  func activeDays(for userID: String) -> Set<String>
  func recordActiveDay(_ day: String, for userID: String)

  /// First time we ever saw this user open the app.
  func firstSeen(for userID: String) -> Date?
  func setFirstSeenIfNeeded(_ date: Date, for userID: String)

  /// Identifiers of triggers that have already been spent. One-shot forever.
  func firedTriggers(for userID: String) -> Set<String>
  func markTriggerFired(_ identifier: String, for userID: String)

  func lastPromptDate(for userID: String) -> Date?
  func setLastPromptDate(_ date: Date, for userID: String)

  func lastFrictionDate(for userID: String) -> Date?
  func setLastFrictionDate(_ date: Date, for userID: String)
}

final class UserDefaultsReviewPromptStore: ReviewPromptStoring, @unchecked Sendable {
  private enum Keys {
    static let activeDays = "review_prompt_active_days"
    static let firstSeen = "review_prompt_first_seen"
    static let firedTriggers = "review_prompt_fired_triggers"
    static let lastPrompt = "review_prompt_last_prompt"
    static let lastFriction = "review_prompt_last_friction"
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  // MARK: - Active days

  func activeDays(for userID: String) -> Set<String> {
    Set(defaults.stringArray(forKey: key(Keys.activeDays, userID)) ?? [])
  }

  func recordActiveDay(_ day: String, for userID: String) {
    guard !normalized(userID).isEmpty else { return }
    var days = activeDays(for: userID)
    guard days.insert(day).inserted else { return }
    defaults.set(Array(days), forKey: key(Keys.activeDays, userID))
  }

  // MARK: - First seen

  func firstSeen(for userID: String) -> Date? {
    defaults.object(forKey: key(Keys.firstSeen, userID)) as? Date
  }

  func setFirstSeenIfNeeded(_ date: Date, for userID: String) {
    guard !normalized(userID).isEmpty, firstSeen(for: userID) == nil else { return }
    defaults.set(date, forKey: key(Keys.firstSeen, userID))
  }

  // MARK: - Triggers

  func firedTriggers(for userID: String) -> Set<String> {
    Set(defaults.stringArray(forKey: key(Keys.firedTriggers, userID)) ?? [])
  }

  func markTriggerFired(_ identifier: String, for userID: String) {
    guard !normalized(userID).isEmpty else { return }
    var fired = firedTriggers(for: userID)
    guard fired.insert(identifier).inserted else { return }
    defaults.set(Array(fired), forKey: key(Keys.firedTriggers, userID))
  }

  // MARK: - Dates

  func lastPromptDate(for userID: String) -> Date? {
    defaults.object(forKey: key(Keys.lastPrompt, userID)) as? Date
  }

  func setLastPromptDate(_ date: Date, for userID: String) {
    guard !normalized(userID).isEmpty else { return }
    defaults.set(date, forKey: key(Keys.lastPrompt, userID))
  }

  func lastFrictionDate(for userID: String) -> Date? {
    defaults.object(forKey: key(Keys.lastFriction, userID)) as? Date
  }

  func setLastFrictionDate(_ date: Date, for userID: String) {
    guard !normalized(userID).isEmpty else { return }
    defaults.set(date, forKey: key(Keys.lastFriction, userID))
  }

  // MARK: - Helpers

  private func key(_ base: String, _ userID: String) -> String {
    "\(base).\(normalized(userID))"
  }

  private func normalized(_ userID: String) -> String {
    userID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}
