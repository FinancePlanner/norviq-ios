import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class PilotFollowDetailModelTests: XCTestCase {
  private func makeModel(_ follow: PilotFollowResponse = .fixture(), service: MockPilotsService) -> (PilotFollowDetailModel, PilotsStore) {
    let store = PilotsStore(service: service)
    store.insert(follow)
    return (PilotFollowDetailModel(follow: follow, service: service, store: store), store)
  }

  func testPortfolioFollowLoadsEventsAndSortedValue() async throws {
    let service = MockPilotsService()
    service.eventsResult = .success([.fixture(id: "e2", kind: "sell"), .fixture(id: "e1")])
    service.snapshotsResult = .success([
      PilotFollowSnapshotResponse(date: "2026-10-02", value: 10_420, cash: 5),
      PilotFollowSnapshotResponse(date: "2026-10-01", value: 10_000, cash: 5)
    ])
    let (model, _) = makeModel(service: service)

    await model.load()

    XCTAssertEqual(model.events.map(\.id), ["e2", "e1"])
    XCTAssertEqual(model.valuePoints.map(\.value), [10_000, 10_420])
    XCTAssertEqual(model.latestValue, 10_420)
    XCTAssertEqual(try XCTUnwrap(model.performance), 0.042, accuracy: 1e-9)
    XCTAssertNil(model.errorMessage)
  }

  func testWatchlistFollowShowsTheFeedAndNeverAsksForSnapshots() async {
    let service = MockPilotsService()
    service.eventsResult = .success([.fixture(kind: "watch_added", quantity: nil, price: nil)])
    let (model, _) = makeModel(.fixture(targetKind: .watchlist), service: service)

    await model.load()

    XCTAssertFalse(model.isPortfolio)
    XCTAssertEqual(model.events.count, 1)
    XCTAssertTrue(model.valuePoints.isEmpty)
    XCTAssertNil(model.performance)
    XCTAssertEqual(service.snapshotCalls, 0)
  }

  func testPauseUpdatesTheFollowAndTheSharedStore() async {
    let service = MockPilotsService()
    let (model, store) = makeModel(service: service)

    await model.setPaused(true)

    XCTAssertEqual(service.statusRequests, [.paused])
    XCTAssertTrue(model.isPaused)
    XCTAssertEqual(store.follows.first?.status, .paused)

    await model.setPaused(false)
    XCTAssertEqual(service.statusRequests, [.paused, .active])
    XCTAssertFalse(model.isPaused)
  }

  func testStopRemovesTheFollowFromTheStore() async {
    let service = MockPilotsService()
    let (model, store) = makeModel(service: service)

    let stopped = await model.stop()

    XCTAssertTrue(stopped)
    XCTAssertEqual(service.stoppedFollowIds, ["11111111-1111-1111-1111-111111111111"])
    XCTAssertTrue(store.follows.isEmpty)
  }

  func testStoppingAFollowThatIsAlreadyGoneCountsAsStopped() async {
    let service = MockPilotsService()
    service.stopError = PilotsHTTPClient.Error.rejected(status: 404, message: "Follow not found.")
    let (model, store) = makeModel(service: service)

    let stopped = await model.stop()

    XCTAssertTrue(stopped)
    XCTAssertTrue(store.follows.isEmpty)
    XCTAssertNil(model.errorMessage)
  }

  func testStopFailureKeepsTheFollowAndSaysWhy() async {
    let service = MockPilotsService()
    service.stopError = PilotsHTTPClient.Error.invalidStatus(500)
    let (model, store) = makeModel(service: service)

    let stopped = await model.stop()

    XCTAssertFalse(stopped)
    XCTAssertEqual(store.follows.count, 1)
    XCTAssertEqual(model.errorMessage, "Request failed (500).")
  }

  func testACancelledLoadIsNotAnError() async {
    let service = MockPilotsService()
    service.eventsResult = .failure(URLError(.cancelled))
    let (model, _) = makeModel(service: service)

    await model.load()

    XCTAssertNil(model.errorMessage)
  }

  func testAFailureAfterTheScreenWentAwayIsNotShown() async {
    let service = MockPilotsService()
    service.delay = .seconds(5)
    service.eventsResult = .failure(PilotsHTTPClient.Error.invalidStatus(500))
    let (model, _) = makeModel(.fixture(targetKind: .watchlist), service: service)

    let load = Task { await model.load() }
    load.cancel()
    await load.value

    XCTAssertNil(model.errorMessage)
  }

  func testLoadingAFollowThatIsGoneSaysSoThenRemovesItOnDismiss() async {
    let service = MockPilotsService()
    service.eventsResult = .failure(PilotsHTTPClient.Error.rejected(status: 404, message: "Not Found"))
    let (model, store) = makeModel(service: service)

    await model.load()

    XCTAssertEqual(model.errorMessage, "This follow isn't available any more.")
    XCTAssertTrue(model.isGone)
    // Kept until the alert is dismissed, so the link that opened this screen
    // doesn't vanish (and pop the screen) before the message is read.
    XCTAssertEqual(store.follows.count, 1)

    model.acknowledgeGone()

    XCTAssertTrue(store.follows.isEmpty)
  }

  func testPausingAFollowThatIsGoneSaysSoThenRemovesItOnDismiss() async {
    let service = MockPilotsService()
    service.statusError = PilotsHTTPClient.Error.rejected(status: 404, message: "Follow not found.")
    let (model, store) = makeModel(service: service)

    await model.setPaused(true)

    XCTAssertEqual(model.errorMessage, "This follow isn't available any more.")
    XCTAssertTrue(model.isGone)
    // Kept until the alert is dismissed, so the link that opened this screen
    // doesn't vanish (and pop the screen) before the message is read.
    XCTAssertEqual(store.follows.count, 1)

    model.acknowledgeGone()

    XCTAssertTrue(store.follows.isEmpty)
  }

  func testOtherFailuresKeepTheFollow() async {
    let service = MockPilotsService()
    service.statusError = PilotsHTTPClient.Error.invalidStatus(500)
    let (model, store) = makeModel(service: service)

    await model.setPaused(true)

    XCTAssertFalse(model.isGone)
    XCTAssertEqual(store.follows.count, 1)
    XCTAssertEqual(model.errorMessage, "Request failed (500).")
  }
}
