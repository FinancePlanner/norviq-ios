import Foundation
import XCTest
@testable import financeplan

private final class UnseenService: AchievementsServicing, @unchecked Sendable {
  struct Failure: Error {}

  var unseenResult: Result<[AchievementUnlock], Error> = .success([])
  var markSeenError: Error?
  private(set) var unseenCalls = 0
  private(set) var markSeenCalls: [[String]] = []
  /// Records what had been marked seen at the moment `unseen` returned, so a
  /// test can prove ordering.
  var onUnseen: (() -> Void)?

  func list() async throws -> AchievementsResponse { throw Failure() }
  func unseen() async throws -> [AchievementUnlock] {
    unseenCalls += 1
    onUnseen?()
    return try unseenResult.get()
  }
  func markSeen(_ ids: [String]) async throws {
    markSeenCalls.append(ids)
    if let markSeenError { throw markSeenError }
  }
  func setShowcase(_ items: [AchievementShowcaseItem]) async throws -> AchievementsResponse { throw Failure() }
}

@MainActor
final class AchievementUnlockCoordinatorTests: XCTestCase {
  private func unlock(_ id: String, tier: String = "bronze") -> AchievementUnlock {
    AchievementUnlock(
      id: id, key: "craft.thesis", tier: tier, title: "Thesis Writer", description: "Write theses.",
      iconKey: "book.fill", xp: 25, unlockedAt: Date(timeIntervalSince1970: 1_790_000_000)
    )
  }

  private func makeCoordinator(
    _ service: UnseenService,
    enabled: Bool = true,
    celebrated: @escaping (AchievementUnlock) -> Void = { _ in }
  ) -> AchievementUnlockCoordinator {
    AchievementUnlockCoordinator(service: service, isEnabled: { enabled }, onCelebrated: celebrated)
  }

  func testDisabledNeverAsksTheServer() async {
    let service = UnseenService()
    let coordinator = makeCoordinator(service, enabled: false)
    await coordinator.checkForUnlocks()
    XCTAssertEqual(service.unseenCalls, 0)
    XCTAssertFalse(coordinator.isPresented)
  }

  func testNothingNewShowsNothing() async {
    let service = UnseenService()
    let coordinator = makeCoordinator(service)
    await coordinator.checkForUnlocks()
    XCTAssertEqual(service.unseenCalls, 1)
    XCTAssertTrue(service.markSeenCalls.isEmpty)
    XCTAssertFalse(coordinator.isPresented)
  }

  func testNewUnlocksAreMarkedSeenThenCelebrated() async {
    let service = UnseenService()
    service.unseenResult = .success([unlock("u1"), unlock("u2", tier: "silver")])
    let coordinator = makeCoordinator(service)
    await coordinator.checkForUnlocks()
    XCTAssertEqual(service.markSeenCalls, [["u1", "u2"]])
    XCTAssertEqual(coordinator.pending.map(\.id), ["u1", "u2"])
    XCTAssertTrue(coordinator.isPresented)
  }

  func testFailedMarkSeenShowsNothing() async {
    let service = UnseenService()
    service.unseenResult = .success([unlock("u1")])
    service.markSeenError = UnseenService.Failure()
    let coordinator = makeCoordinator(service)
    await coordinator.checkForUnlocks()
    XCTAssertTrue(coordinator.pending.isEmpty)
    XCTAssertFalse(coordinator.isPresented)
  }

  func testFailedFetchShowsNothing() async {
    let service = UnseenService()
    service.unseenResult = .failure(UnseenService.Failure())
    let coordinator = makeCoordinator(service)
    await coordinator.checkForUnlocks()
    XCTAssertFalse(coordinator.isPresented)
  }

  func testNoSecondFetchWhileACelebrationIsPending() async {
    let service = UnseenService()
    service.unseenResult = .success([unlock("u1")])
    let coordinator = makeCoordinator(service)
    await coordinator.checkForUnlocks()
    await coordinator.checkForUnlocks()
    XCTAssertEqual(service.unseenCalls, 1)
  }

  func testCoveredContextHoldsTheSheetUntilUncovered() async {
    let service = UnseenService()
    service.unseenResult = .success([unlock("u1")])
    let coordinator = makeCoordinator(service)
    coordinator.setContextEligible(false)
    await coordinator.checkForUnlocks()
    XCTAssertFalse(coordinator.isPresented)
    coordinator.setContextEligible(true)
    XCTAssertTrue(coordinator.isPresented)
  }

  func testDismissClearsAndCelebratesTheFirstUnlockOnce() async {
    let service = UnseenService()
    service.unseenResult = .success([unlock("u1"), unlock("u2")])
    var celebrated: [String] = []
    let coordinator = makeCoordinator(service) { celebrated.append($0.id) }
    await coordinator.checkForUnlocks()
    coordinator.dismiss()
    coordinator.dismiss()
    XCTAssertTrue(coordinator.pending.isEmpty)
    XCTAssertFalse(coordinator.isPresented)
    XCTAssertEqual(celebrated, ["u1"])
  }
}
