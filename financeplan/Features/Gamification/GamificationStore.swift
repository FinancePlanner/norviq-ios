import Factory
import Foundation
import Observation

/// The signed-in user's XP and streaks. The server awards every point; this
/// store only reports facts (a check-in, the budget streak) and shows totals.
@MainActor
@Observable
final class GamificationStore {
  private(set) var xp: XPSummary?
  private(set) var streaks: StreakSummary?
  /// The last check-in made from this device this session, for the "+10 XP" line.
  private(set) var lastCheckIn: CheckInResponse?
  private(set) var lastCheckInDay: String?
  private(set) var isCheckingIn = false
  private(set) var hasReportedBudgetStreak = false
  var errorMessage: String?

  /// The budget streak the dashboard last computed, waiting to be reported.
  private var pendingBudgetMonths: Int?
  private let service: any GamificationServicing

  init(service: any GamificationServicing = Container.shared.gamificationService()) {
    self.service = service
  }

  /// Whether today's check-in is done, as far as this device knows.
  var hasCheckedInToday: Bool {
    let today = Self.localDayString(for: .now)
    return lastCheckInDay == today || streaks?.lastCheckInDate == today
  }

  func load() async {
    do {
      async let summary = service.xpSummary()
      async let streakSummary = service.streaks()
      let (xpValue, streakValue) = try await (summary, streakSummary)
      xp = xpValue
      streaks = streakValue
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @discardableResult
  func checkIn() async -> CheckInResponse? {
    guard !isCheckingIn else { return nil }
    isCheckingIn = true
    defer { isCheckingIn = false }
    do {
      let response = try await service.checkIn()
      lastCheckIn = response
      lastCheckInDay = Self.localDayString(for: .now)
      // Totals and the longest streak come from the server; reload them
      // rather than guessing locally.
      await load()
      return response
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  /// Remembers the dashboard's budget streak. It is sent by
  /// `reportBudgetStreakIfNeeded()` once the social layer is known to be on.
  func noteBudgetStreak(months: Int) {
    guard !hasReportedBudgetStreak else { return }
    pendingBudgetMonths = max(0, months)
  }

  /// Sends the noted budget streak at most once per app session.
  func reportBudgetStreakIfNeeded() async {
    guard !hasReportedBudgetStreak, let months = pendingBudgetMonths else { return }
    hasReportedBudgetStreak = true
    do {
      streaks = try await service.reportBudgetStreak(months: months)
      pendingBudgetMonths = nil
    } catch {
      // Not worth an alert: the next launch reports it again.
      hasReportedBudgetStreak = false
    }
  }

  /// Signing out must not leave one account's XP on screen for the next.
  func reset() {
    xp = nil
    streaks = nil
    lastCheckIn = nil
    lastCheckInDay = nil
    hasReportedBudgetStreak = false
    pendingBudgetMonths = nil
    errorMessage = nil
  }

  nonisolated static func localDayString(for date: Date, timeZone: TimeZone = .current) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }
}
