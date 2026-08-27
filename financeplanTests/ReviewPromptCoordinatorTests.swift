import XCTest
@testable import financeplan

/// The system review prompt cannot be asserted from a test — StoreKit decides whether to
/// show anything, and in DEBUG on simulator it shows almost every time. So these tests
/// are the only real proof that the gating works.
@MainActor
final class ReviewPromptCoordinatorTests: XCTestCase {
  // MARK: - Test doubles

  private final class InMemoryStore: ReviewPromptStoring, @unchecked Sendable {
    var activeDaysByUser: [String: Set<String>] = [:]
    var firstSeenByUser: [String: Date] = [:]
    var firedByUser: [String: Set<String>] = [:]
    var lastPromptByUser: [String: Date] = [:]
    var lastFrictionByUser: [String: Date] = [:]

    func activeDays(for userID: String) -> Set<String> { activeDaysByUser[userID] ?? [] }

    func recordActiveDay(_ day: String, for userID: String) {
      activeDaysByUser[userID, default: []].insert(day)
    }

    func firstSeen(for userID: String) -> Date? { firstSeenByUser[userID] }

    func setFirstSeenIfNeeded(_ date: Date, for userID: String) {
      if firstSeenByUser[userID] == nil { firstSeenByUser[userID] = date }
    }

    func firedTriggers(for userID: String) -> Set<String> { firedByUser[userID] ?? [] }

    func markTriggerFired(_ identifier: String, for userID: String) {
      firedByUser[userID, default: []].insert(identifier)
    }

    func lastPromptDate(for userID: String) -> Date? { lastPromptByUser[userID] }

    func setLastPromptDate(_ date: Date, for userID: String) { lastPromptByUser[userID] = date }

    func lastFrictionDate(for userID: String) -> Date? { lastFrictionByUser[userID] }

    func setLastFrictionDate(_ date: Date, for userID: String) {
      lastFrictionByUser[userID] = date
    }
  }

  /// A clock the test moves by hand.
  private final class TestClock: @unchecked Sendable {
    var now: Date
    init(_ start: Date) { now = start }
    func advance(days: Int) { now = now.addingTimeInterval(TimeInterval(days) * 86_400) }
  }

  private let userID = "user-1"
  private var store: InMemoryStore!
  private var clock: TestClock!

  override func setUp() {
    super.setUp()
    store = InMemoryStore()
    // A fixed, mid-month, mid-day instant so no assertion depends on "today".
    clock = TestClock(Date(timeIntervalSince1970: 1_766_000_000))
  }

  private func makeCoordinator() -> ReviewPromptCoordinator {
    let clock = clock!
    return ReviewPromptCoordinator(
      store: store,
      analytics: nil,
      now: { clock.now }
    )
  }

  /// Puts the user past the engagement floor: 6 distinct active days, 6 days of history.
  private func makeEligibleUser(_ coordinator: ReviewPromptCoordinator) {
    for _ in 0 ..< 6 {
      coordinator.recordAppOpen(userID: userID)
      clock.advance(days: 1)
    }
  }

  // MARK: - Active-day counting

  func testSevenDistinctDaysFiresPrompt() {
    let coordinator = makeCoordinator()

    for _ in 0 ..< 6 {
      coordinator.recordAppOpen(userID: userID)
      clock.advance(days: 1)
    }
    XCTAssertFalse(coordinator.pendingPrompt, "six days should not be enough")

    coordinator.recordAppOpen(userID: userID)
    XCTAssertTrue(coordinator.pendingPrompt, "the seventh distinct day should fire")
  }

  func testManyOpensInOneDayDoNotFire() {
    let coordinator = makeCoordinator()

    for _ in 0 ..< 20 {
      coordinator.recordAppOpen(userID: userID)
    }

    XCTAssertFalse(coordinator.pendingPrompt, "20 opens in one day is still one day")
    XCTAssertEqual(store.activeDays(for: userID).count, 1)
  }

  // MARK: - Engagement floor

  func testGoalCompletionBelowEngagementFloorIsSuppressed() {
    let coordinator = makeCoordinator()
    coordinator.recordAppOpen(userID: userID)

    coordinator.consider(.goalCompleted(goalID: "g1"), userID: userID)

    XCTAssertFalse(coordinator.pendingPrompt, "a day-one user has not earned an ask")
  }

  func testGoalCompletionFiresOnceEligible() {
    let coordinator = makeCoordinator()
    makeEligibleUser(coordinator)

    coordinator.consider(.goalCompleted(goalID: "g1"), userID: userID)

    XCTAssertTrue(coordinator.pendingPrompt)
  }

  // MARK: - One-shot

  func testSameGoalDoesNotFireTwice() {
    let coordinator = makeCoordinator()
    makeEligibleUser(coordinator)

    coordinator.consider(.goalCompleted(goalID: "g1"), userID: userID)
    coordinator.markPromptShown(userID: userID)
    XCTAssertFalse(coordinator.pendingPrompt)

    // Reopening the goal screen must not re-ask.
    coordinator.consider(.goalCompleted(goalID: "g1"), userID: userID)
    XCTAssertFalse(coordinator.pendingPrompt)
  }

  // MARK: - Cooldown

  func testSecondTriggerWithinCooldownIsSuppressed() {
    let coordinator = makeCoordinator()
    makeEligibleUser(coordinator)

    coordinator.consider(.goalCompleted(goalID: "g1"), userID: userID)
    coordinator.markPromptShown(userID: userID)

    clock.advance(days: ReviewPromptCoordinator.Policy.promptCooldownDays - 1)
    coordinator.consider(.goalCompleted(goalID: "g2"), userID: userID)

    XCTAssertFalse(coordinator.pendingPrompt, "a different goal still waits out the cooldown")
  }

  func testSecondTriggerAfterCooldownFires() {
    let coordinator = makeCoordinator()
    makeEligibleUser(coordinator)

    coordinator.consider(.goalCompleted(goalID: "g1"), userID: userID)
    coordinator.markPromptShown(userID: userID)

    clock.advance(days: ReviewPromptCoordinator.Policy.promptCooldownDays + 1)
    coordinator.consider(.goalCompleted(goalID: "g2"), userID: userID)

    XCTAssertTrue(coordinator.pendingPrompt)
  }

  // MARK: - Friction

  func testTriggerWithinFrictionWindowIsSuppressed() {
    let coordinator = makeCoordinator()
    makeEligibleUser(coordinator)

    coordinator.noteFriction(.importFailed, userID: userID)
    clock.advance(days: ReviewPromptCoordinator.Policy.frictionQuietDays - 1)
    coordinator.consider(.goalCompleted(goalID: "g1"), userID: userID)

    XCTAssertFalse(coordinator.pendingPrompt)
  }

  func testTriggerAfterFrictionWindowFires() {
    let coordinator = makeCoordinator()
    makeEligibleUser(coordinator)

    coordinator.noteFriction(.feedbackSubmitted, userID: userID)
    clock.advance(days: ReviewPromptCoordinator.Policy.frictionQuietDays + 1)
    coordinator.consider(.goalCompleted(goalID: "g1"), userID: userID)

    XCTAssertTrue(coordinator.pendingPrompt)
  }

  func testFrictionWithdrawsAQueuedPrompt() {
    let coordinator = makeCoordinator()
    makeEligibleUser(coordinator)

    coordinator.consider(.goalCompleted(goalID: "g1"), userID: userID)
    XCTAssertTrue(coordinator.pendingPrompt)

    // The import blew up before the prompt was presented — the friction is more recent
    // than the milestone that earned it.
    coordinator.noteFriction(.importFailed, userID: userID)
    XCTAssertFalse(coordinator.pendingPrompt)
  }

  // MARK: - Context

  func testTriggerWhileASheetIsPresentedIsSuppressed() {
    let coordinator = makeCoordinator()
    makeEligibleUser(coordinator)

    coordinator.setContextEligible(false)
    coordinator.consider(.goalCompleted(goalID: "g1"), userID: userID)

    XCTAssertFalse(coordinator.pendingPrompt)
  }

  // MARK: - Multi-user isolation

  func testPromptStateDoesNotLeakBetweenUsers() {
    let coordinator = makeCoordinator()
    let other = "user-2"

    makeEligibleUser(coordinator)
    coordinator.consider(.goalCompleted(goalID: "g1"), userID: userID)
    coordinator.markPromptShown(userID: userID)

    // A second account on the same device starts from zero, so it must not inherit the
    // first account's spent trigger — nor its eligibility.
    XCTAssertTrue(store.firedTriggers(for: other).isEmpty)
    coordinator.consider(.goalCompleted(goalID: "g1"), userID: other)
    XCTAssertFalse(coordinator.pendingPrompt, "user-2 has no history and is not yet eligible")
  }

  func testEmptyUserIDIsIgnored() {
    let coordinator = makeCoordinator()

    coordinator.recordAppOpen(userID: "")
    coordinator.consider(.goalCompleted(goalID: "g1"), userID: "")

    XCTAssertFalse(coordinator.pendingPrompt)
    XCTAssertTrue(store.activeDaysByUser.isEmpty)
  }

  // MARK: - Trigger identity

  func testTriggerIdentifiersAreDistinctPerGoalAndShared() {
    XCTAssertNotEqual(
      ReviewTrigger.goalCompleted(goalID: "a").persistenceIdentifier,
      ReviewTrigger.goalCompleted(goalID: "b").persistenceIdentifier
    )
    XCTAssertEqual(
      ReviewTrigger.sevenActiveDays.persistenceIdentifier,
      ReviewTrigger.sevenActiveDays.persistenceIdentifier
    )
    XCTAssertNotEqual(
      ReviewTrigger.budgetStreakReached(months: 1).persistenceIdentifier,
      ReviewTrigger.budgetStreakReached(months: 3).persistenceIdentifier
    )
  }
}
