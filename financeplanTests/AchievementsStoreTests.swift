import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

private final class MockAchievementsService: AchievementsServicing, @unchecked Sendable {
  struct Failure: Error {}

  var listResult: Result<AchievementsResponse, Error>
  var showcaseResult: Result<AchievementsResponse, Error>?
  private(set) var showcaseCalls: [[AchievementShowcaseItem]] = []

  init(listResult: Result<AchievementsResponse, Error>) {
    self.listResult = listResult
  }

  func list() async throws -> AchievementsResponse { try listResult.get() }
  func unseen() async throws -> [AchievementUnlock] { [] }
  func markSeen(_ ids: [String]) async throws {}
  func setShowcase(_ items: [AchievementShowcaseItem]) async throws -> AchievementsResponse {
    showcaseCalls.append(items)
    return try (showcaseResult ?? listResult).get()
  }
}

@MainActor
final class AchievementsStoreTests: XCTestCase {
  private func fixture() throws -> AchievementsResponse {
    try JSONDecoder.stockPlanShared.decode(
      AchievementsResponse.self, from: Data(AchievementsAPITests.achievementsFixture.utf8)
    )
  }

  private func achievement(_ key: String, in response: AchievementsResponse) throws -> Achievement {
    try XCTUnwrap(response.achievements.first { $0.key == key })
  }

  func testLoadSuccessShowsTheCatalogue() async throws {
    let response = try fixture()
    let store = AchievementsStore(service: MockAchievementsService(listResult: .success(response)))
    await store.load()
    XCTAssertEqual(store.response, response)
    XCTAssertNil(store.loadError)
  }

  func testLoadFailureIsReported() async {
    let store = AchievementsStore(service: MockAchievementsService(listResult: .failure(MockAchievementsService.Failure())))
    await store.load()
    XCTAssertNil(store.response)
    XCTAssertNotNil(store.loadError)
  }

  func testPinnedItemsFollowShowcaseRank() throws {
    let items = AchievementsStore.pinnedItems(in: try fixture())
    XCTAssertEqual(items, [AchievementShowcaseItem(key: "start.first_holding", tier: "")])
  }

  func testOnlyEarnedVisibleNonPerformanceAchievementsCanBePinned() throws {
    let response = try fixture()
    XCTAssertTrue(AchievementsStore.canPin(try achievement("start.first_holding", in: response)))
    XCTAssertTrue(AchievementsStore.canPin(try achievement("discipline.check_in", in: response)))
    XCTAssertFalse(AchievementsStore.canPin(try achievement("hidden.1", in: response)))
    XCTAssertFalse(AchievementsStore.canPin(try achievement("perf.comeback", in: response)))
  }

  func testPinSendsTheFullListWithTheNewItemLast() async throws {
    let response = try fixture()
    let service = MockAchievementsService(listResult: .success(response))
    let store = AchievementsStore(service: service)
    await store.load()

    await store.pin(try achievement("discipline.check_in", in: response))

    XCTAssertEqual(service.showcaseCalls, [[
      AchievementShowcaseItem(key: "start.first_holding", tier: ""),
      AchievementShowcaseItem(key: "discipline.check_in", tier: "bronze")
    ]])
  }

  func testUnpinDropsThatAchievement() async throws {
    let response = try fixture()
    let service = MockAchievementsService(listResult: .success(response))
    let store = AchievementsStore(service: service)
    await store.load()

    await store.unpin(try achievement("start.first_holding", in: response))

    XCTAssertEqual(service.showcaseCalls, [[]])
  }

  func testPinIsRefusedOnceThreeArePinned() async throws {
    // Three ranks taken (first_holding 1, hidden.1 2, perf.comeback 3).
    var json = AchievementsAPITests.achievementsFixture
    json = json.replacingOccurrences(
      of: #""tier": "", "threshold": null, "xp": 0, "unlockId": null, "unlockedAt": null, "showcaseRank": null"#,
      with: #""tier": "", "threshold": null, "xp": 0, "unlockId": null, "unlockedAt": null, "showcaseRank": 2"#
    )
    json = json.replacingOccurrences(
      of: #""tier": "", "threshold": 1, "xp": 100, "unlockId": null, "unlockedAt": null, "showcaseRank": null"#,
      with: #""tier": "", "threshold": 1, "xp": 100, "unlockId": null, "unlockedAt": null, "showcaseRank": 3"#
    )
    let response = try JSONDecoder.stockPlanShared.decode(AchievementsResponse.self, from: Data(json.utf8))
    XCTAssertEqual(AchievementsStore.pinnedItems(in: response).count, 3)
    let service = MockAchievementsService(listResult: .success(response))
    let store = AchievementsStore(service: service)
    await store.load()

    await store.pin(try achievement("discipline.check_in", in: response))

    XCTAssertTrue(service.showcaseCalls.isEmpty)
    XCTAssertNotNil(store.actionError)
  }

  func testFailedPinKeepsTheCurrentCatalogue() async throws {
    let response = try fixture()
    let service = MockAchievementsService(listResult: .success(response))
    service.showcaseResult = .failure(MockAchievementsService.Failure())
    let store = AchievementsStore(service: service)
    await store.load()

    await store.pin(try achievement("discipline.check_in", in: response))

    XCTAssertEqual(store.response, response)
    XCTAssertNotNil(store.actionError)
  }

  func testShowcaseListsPinnedAchievementsInRankOrder() throws {
    let response = try fixture()
    XCTAssertEqual(AchievementsStore.showcase(in: response).map(\.key), ["start.first_holding"])
  }

  func testUnknownSymbolsFallBackToARosette() {
    XCTAssertEqual(AchievementSymbol.name(for: "flame.fill"), "flame.fill")
    XCTAssertEqual(AchievementSymbol.name(for: "not.a.real.symbol"), "rosette")
  }

  func testTierLabelsAndOrder() {
    XCTAssertEqual(AchievementTierStyle.rank("gold"), 3)
    XCTAssertEqual(AchievementTierStyle.rank(""), 0)
    XCTAssertNil(AchievementTierStyle.label(""))
    XCTAssertNotNil(AchievementTierStyle.label("silver"))
  }
}
