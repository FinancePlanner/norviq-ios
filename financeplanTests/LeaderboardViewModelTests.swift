import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

private final class MockGamificationService: GamificationServicing, @unchecked Sendable {
  struct Failure: Error {}

  var leaderboards: [String: LeaderboardResponse] = [:]
  var leaderboardError: Error?
  var leaderboardCalls: [(metric: LeaderboardMetric, period: LeaderboardPeriod)] = []
  var xp = XPSummary(total: 0, level: 1, levelProgress: 0, weekXP: 0)
  var streakSummary = StreakSummary(checkInCurrent: 0, checkInLongest: 0, budgetMonths: 0, lastCheckInDate: nil)
  var checkInResult: Result<CheckInResponse, Error> = .success(
    CheckInResponse(streak: 1, xpAwarded: 10, alreadyCheckedIn: false)
  )
  var checkInCount = 0
  var budgetReports: [Int] = []
  var budgetReportError: Error?

  func xpSummary() async throws -> XPSummary { xp }
  func xpEvents(cursor: String?) async throws -> XPHistoryResponse { XPHistoryResponse(events: [], nextCursor: nil) }
  func streaks() async throws -> StreakSummary { streakSummary }
  func checkIn() async throws -> CheckInResponse {
    checkInCount += 1
    return try checkInResult.get()
  }
  func reportBudgetStreak(months: Int) async throws -> StreakSummary {
    budgetReports.append(months)
    if let budgetReportError { throw budgetReportError }
    return StreakSummary(
      checkInCurrent: streakSummary.checkInCurrent,
      checkInLongest: streakSummary.checkInLongest,
      budgetMonths: months,
      lastCheckInDate: streakSummary.lastCheckInDate
    )
  }
  func leaderboard(metric: LeaderboardMetric, period: LeaderboardPeriod) async throws -> LeaderboardResponse {
    leaderboardCalls.append((metric, period))
    if let leaderboardError { throw leaderboardError }
    return leaderboards["\(metric.rawValue)-\(period.rawValue)"]
      ?? LeaderboardResponse(metric: metric, period: period, entries: [], periodStart: .now, periodEnd: .now)
  }
}

private extension SocialUserSummary {
  static let me = SocialUserSummary(id: "me", username: "me")
  static let ana = SocialUserSummary(id: "ana", username: "ana", displayName: "Ana", friendshipStatus: .friends)
}

private func board(
  _ metric: LeaderboardMetric,
  _ period: LeaderboardPeriod,
  _ entries: [LeaderboardEntry]
) -> LeaderboardResponse {
  LeaderboardResponse(metric: metric, period: period, entries: entries, periodStart: .now, periodEnd: .now)
}

@MainActor
final class LeaderboardViewModelTests: XCTestCase {
  func testLoadRequestsTheSelectedMetricAndPeriod() async {
    let service = MockGamificationService()
    service.leaderboards["xp-month"] = board(.xp, .month, [
      LeaderboardEntry(rank: 1, user: .ana, value: 120, isMe: false),
      LeaderboardEntry(rank: 2, user: .me, value: 80, isMe: true)
    ])
    let viewModel = LeaderboardViewModel(service: service)
    viewModel.metric = .xp
    viewModel.period = .month

    await viewModel.load()

    XCTAssertEqual(service.leaderboardCalls.last?.metric, .xp)
    XCTAssertEqual(service.leaderboardCalls.last?.period, .month)
    XCTAssertEqual(viewModel.entries.map(\.id), ["ana", "me"])
    XCTAssertFalse(viewModel.isAlone)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testEntriesForAnOlderSelectionAreNotShown() async {
    let service = MockGamificationService()
    service.leaderboards["xp-week"] = board(.xp, .week, [LeaderboardEntry(rank: 1, user: .me, value: 5, isMe: true)])
    let viewModel = LeaderboardViewModel(service: service)
    await viewModel.load()
    XCTAssertEqual(viewModel.entries.count, 1)

    viewModel.metric = .checkInStreak

    XCTAssertTrue(viewModel.entries.isEmpty, "A week of XP must not be labelled as a streak board.")
  }

  func testOnlyMeOnTheBoardReadsAsAlone() async {
    let service = MockGamificationService()
    service.leaderboards["xp-week"] = board(.xp, .week, [LeaderboardEntry(rank: 1, user: .me, value: 5, isMe: true)])
    let viewModel = LeaderboardViewModel(service: service)
    await viewModel.load()
    XCTAssertTrue(viewModel.isAlone)
  }

  func testFailureSurfacesAnError() async {
    let service = MockGamificationService()
    service.leaderboardError = MockGamificationService.Failure()
    let viewModel = LeaderboardViewModel(service: service)
    await viewModel.load()
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.entries.isEmpty)
  }

  func testReturnPercentShowsTheOptInNoteAndSignedPercent() {
    let viewModel = LeaderboardViewModel(service: MockGamificationService())
    viewModel.metric = .returnPercent
    XCTAssertTrue(viewModel.showsReturnPercentNote)
    XCTAssertTrue(LeaderboardViewModel.formattedValue(4.25, metric: .returnPercent).hasPrefix("+"))
    XCTAssertTrue(LeaderboardViewModel.formattedValue(-3, metric: .returnPercent).contains("3"))
    viewModel.metric = .xp
    XCTAssertFalse(viewModel.showsReturnPercentNote)
  }

  func testLeaderboardDecodesFromServerJSON() throws {
    let json = Data(#"""
    {"metric":"return_percent","period":"week","periodStart":"2026-09-21T00:00:00Z","periodEnd":"2026-09-28T00:00:00Z",
     "entries":[{"rank":1,"user":{"id":"ana","username":"ana","friendshipStatus":"friends"},"value":4.2,"isMe":false}]}
    """#.utf8)
    let response = try JSONDecoder.stockPlanShared.decode(LeaderboardResponse.self, from: json)
    XCTAssertEqual(response.metric, .returnPercent)
    XCTAssertEqual(response.entries.first?.value, 4.2)
  }

  func testUnknownXPEventTypeDecodesAsOther() throws {
    let json = Data(#"{"id":"1","type":"quest_done","points":5,"createdAt":"2026-09-21T00:00:00Z"}"#.utf8)
    let event = try JSONDecoder.stockPlanShared.decode(XPEvent.self, from: json)
    XCTAssertEqual(event.type, .other)
  }
}

@MainActor
final class GamificationStoreTests: XCTestCase {
  func testCheckInRecordsTheAwardAndReloadsTotals() async {
    let service = MockGamificationService()
    service.xp = XPSummary(total: 10, level: 1, levelProgress: 0.1, weekXP: 10)
    let store = GamificationStore(service: service)

    let response = await store.checkIn()

    XCTAssertEqual(response?.xpAwarded, 10)
    XCTAssertEqual(store.xp?.total, 10)
    XCTAssertTrue(store.hasCheckedInToday)
    XCTAssertEqual(service.checkInCount, 1)
  }

  func testCheckInFailureKeepsTheButtonAvailable() async {
    let service = MockGamificationService()
    service.checkInResult = .failure(MockGamificationService.Failure())
    let store = GamificationStore(service: service)
    await store.checkIn()
    XCTAssertFalse(store.hasCheckedInToday)
    XCTAssertNotNil(store.errorMessage)
  }

  func testServerCheckInTodayCountsAsCheckedIn() async {
    let service = MockGamificationService()
    service.streakSummary = StreakSummary(
      checkInCurrent: 3,
      checkInLongest: 3,
      budgetMonths: 0,
      lastCheckInDate: GamificationStore.localDayString(for: .now)
    )
    let store = GamificationStore(service: service)
    await store.load()
    XCTAssertTrue(store.hasCheckedInToday)
  }

  func testBudgetStreakIsReportedOncePerSession() async {
    let service = MockGamificationService()
    let store = GamificationStore(service: service)

    await store.reportBudgetStreakIfNeeded()
    XCTAssertTrue(service.budgetReports.isEmpty, "Nothing to report before the dashboard computed a streak.")

    store.noteBudgetStreak(months: 4)
    await store.reportBudgetStreakIfNeeded()
    store.noteBudgetStreak(months: 5)
    await store.reportBudgetStreakIfNeeded()

    XCTAssertEqual(service.budgetReports, [4])
    XCTAssertEqual(store.streaks?.budgetMonths, 4)
  }

  func testFailedBudgetReportIsRetried() async {
    let service = MockGamificationService()
    service.budgetReportError = MockGamificationService.Failure()
    let store = GamificationStore(service: service)
    store.noteBudgetStreak(months: 2)
    await store.reportBudgetStreakIfNeeded()
    service.budgetReportError = nil
    await store.reportBudgetStreakIfNeeded()
    XCTAssertEqual(service.budgetReports, [2, 2])
  }

  func testResetForgetsTheSession() async {
    let service = MockGamificationService()
    let store = GamificationStore(service: service)
    store.noteBudgetStreak(months: 1)
    await store.reportBudgetStreakIfNeeded()
    await store.checkIn()
    store.reset()
    XCTAssertNil(store.xp)
    XCTAssertFalse(store.hasReportedBudgetStreak)
    XCTAssertFalse(store.hasCheckedInToday)
  }

  func testLocalDayUsesTheGivenTimeZone() throws {
    // 2026-09-26 23:30 UTC is already the 27th in Lisbon (UTC+1 in summer).
    let date = Date(timeIntervalSince1970: 1_790_465_400)
    let lisbon = try XCTUnwrap(TimeZone(identifier: "Europe/Lisbon"))
    let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
    XCTAssertEqual(GamificationStore.localDayString(for: date, timeZone: utc), "2026-09-26")
    XCTAssertEqual(GamificationStore.localDayString(for: date, timeZone: lisbon), "2026-09-27")
  }
}
