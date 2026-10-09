import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

// Every test is `async`, even those that await nothing: see PilotsStoreTests
// for the synchronous-deinit crash this avoids.
@MainActor
final class TerminalPositionsViewModelTests: XCTestCase {
  private func makeModel(
    _ service: MockTerminalPositionsService = MockTerminalPositionsService(),
    defaults: UserDefaults? = nil
  ) -> (TerminalPositionsViewModel, MockTerminalPositionsService, UserDefaults) {
    let defaults = defaults ?? UserDefaults(suiteName: "TerminalPositionsViewModelTests-\(UUID().uuidString)")!
    return (TerminalPositionsViewModel(service: service, defaults: defaults), service, defaults)
  }

  func testLoadShowsPositionsCurrencyAndAutobuyTotal() async {
    let service = MockTerminalPositionsService()
    service.listResult = .success(.fixture([.fixture()], currency: "EUR"))
    service.autobuysResult = .success(.fixture([.fixture(amount: 50, cadence: .weekly, percent: nil)], currency: "EUR"))
    let (model, _, _) = makeModel(service)

    await model.load()

    XCTAssertEqual(model.positions.map(\.id), ["p1"])
    XCTAssertEqual(model.currency, "EUR")
    XCTAssertEqual(model.autobuys.count, 1)
    XCTAssertEqual(model.monthlyAutobuyTotal, 50 * 52 / 12, accuracy: 0.000001)
    XCTAssertTrue(model.hasLoaded)
    XCTAssertNil(model.errorMessage)
  }

  func testTotalsSkipInvalidRowsAndCountOnlyPricedCapital() async {
    let service = MockTerminalPositionsService()
    service.listResult = .success(.fixture([
      .fixture(id: "a", sharesOwned: 750, currentSharePrice: 200),
      .fixture(id: "b", ticker: "BAD", terminalShareCount: 0),
      .fixture(id: "c", ticker: "VG", terminalShareCount: 16_000_000, terminalMarketCap: 1_000_000_000, valueWanted: 500_000),
    ]))
    let (model, _, _) = makeModel(service)

    await model.load()

    let totals = model.totals
    XCTAssertEqual(totals.valueWanted, 1_500_000, accuracy: 0.001)
    XCTAssertEqual(totals.gapValueAtTerminal, 350 * (10_000_000_000_000 / 11_000_000_000) + 500_000, accuracy: 0.001)
    XCTAssertEqual(totals.capitalAtTodayPrice ?? 0, 1_100 * 200, accuracy: 0.001)
  }

  func testLoadFailureShowsAMessageAndNoSample() async {
    let service = MockTerminalPositionsService()
    service.listResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 404, message: "Not Found"))
    let (model, _, _) = makeModel(service)

    await model.load()

    XCTAssertEqual(model.errorMessage, "Terminal positions are unavailable right now.")
    XCTAssertFalse(model.hasLoaded)
    XCTAssertFalse(model.showsSample)
  }

  func testCancelledLoadShowsNoError() async {
    let service = MockTerminalPositionsService()
    service.listResult = .failure(TerminalPositionsHTTPClient.Error.cancelled)
    service.autobuysResult = .failure(CancellationError())
    let (model, _, _) = makeModel(service)

    await model.load()

    XCTAssertNil(model.errorMessage)
  }

  func testBackendDownShowsOnlyThePositionsMessage() async {
    let service = MockTerminalPositionsService()
    service.listResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 404, message: "Not Found"))
    service.autobuysResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 404, message: "Not Found"))
    let (model, _, _) = makeModel(service)

    await model.load()

    XCTAssertEqual(model.errorMessage, "Terminal positions are unavailable right now.")
  }

  func testAutobuysFailureStillShowsPositions() async {
    let service = MockTerminalPositionsService()
    service.autobuysResult = .failure(TerminalPositionsHTTPClient.Error.invalidStatus(500))
    let (model, _, _) = makeModel(service)

    await model.load()

    XCTAssertEqual(model.positions.count, 1)
    XCTAssertEqual(model.errorMessage, "Autobuys are unavailable right now.")
  }

  func testEmptyListShowsTheSampleUntilDismissedAndRemembersIt() async {
    let service = MockTerminalPositionsService()
    service.listResult = .success(.fixture([]))
    let (model, _, defaults) = makeModel(service)

    await model.load()
    XCTAssertTrue(model.showsSample)

    model.dismissSample()
    XCTAssertFalse(model.showsSample)

    let (reopened, _, _) = makeModel(service, defaults: defaults)
    await reopened.load()
    XCTAssertFalse(reopened.showsSample)
  }

  func testUsingTheSampleCreatesTheAMZNRow() async {
    let service = MockTerminalPositionsService()
    service.listResult = .success(.fixture([]))
    service.createResult = .success(.fixture(id: "sample"))
    let (model, _, _) = makeModel(service)
    await model.load()

    await model.useSample()

    XCTAssertEqual(service.createRequests, [TerminalPositionsViewModel.sampleRequest])
    XCTAssertEqual(TerminalPositionsViewModel.sampleRequest.ticker, "AMZN")
    XCTAssertEqual(model.positions.map(\.id), ["sample"])
    XCTAssertFalse(model.showsSample)
  }

  func testSamplePreviewMatchesTheWorkedExample() async {
    let preview = TerminalPositionsViewModel.samplePreview
    XCTAssertEqual(preview?.terminalSharePrice ?? 0, 909.0909, accuracy: 0.0001)
    XCTAssertEqual(preview?.sharesNeeded ?? 0, 1_100, accuracy: 0.000001)
  }

  private func loadedModel(ids: [String]) async -> (TerminalPositionsViewModel, MockTerminalPositionsService) {
    let service = MockTerminalPositionsService()
    service.listResult = .success(.fixture(ids.enumerated().map { .fixture(id: $1, sortOrder: $0) }))
    let (model, _, _) = makeModel(service)
    await model.load()
    return (model, service)
  }

  func testDeleteRemovesTheRowAndCallsTheService() async {
    let (model, service) = await loadedModel(ids: ["a", "b"])

    await model.delete(model.positions[0])

    XCTAssertEqual(model.positions.map(\.id), ["b"])
    XCTAssertEqual(service.deletedIds, ["a"])
  }

  func testFailedDeletePutsTheRowBackInPlace() async {
    let (model, service) = await loadedModel(ids: ["a", "b", "c"])
    service.deleteError = TerminalPositionsHTTPClient.Error.invalidStatus(500)

    await model.delete(model.positions[1])

    XCTAssertEqual(model.positions.map(\.id), ["a", "b", "c"])
    XCTAssertEqual(model.errorMessage, "The row could not be deleted.")
  }

  func testDeletingARowAlreadyGoneElsewhereStaysDeleted() async {
    let (model, service) = await loadedModel(ids: ["a", "b"])
    service.deleteError = TerminalPositionsHTTPClient.Error.rejected(status: 404, message: nil)

    await model.delete(model.positions[0])

    XCTAssertEqual(model.positions.map(\.id), ["b"])
    XCTAssertNil(model.errorMessage)
  }

  func testDuplicateInsertsTheCopyRightAfterTheSource() async {
    let (model, service) = await loadedModel(ids: ["a", "b"])
    service.duplicateResult = .success(.fixture(id: "a-copy"))

    await model.duplicate(model.positions[0])

    XCTAssertEqual(service.duplicatedIds, ["a"])
    XCTAssertEqual(model.positions.map(\.id), ["a", "a-copy", "b"])
  }

  func testMoveReordersLocallyAtOnceAndSendsTheFullIdList() async {
    let (model, service) = await loadedModel(ids: ["a", "b", "c"])

    let task = model.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
    XCTAssertEqual(model.positions.map(\.id), ["c", "a", "b"], "the list must move before the request returns")
    await task?.value

    XCTAssertEqual(service.reorderedIds, [["c", "a", "b"]])
    XCTAssertEqual(model.positions.map(\.id), ["c", "a", "b"])
  }

  func testNoOpMoveSendsNothing() async {
    let (model, service) = await loadedModel(ids: ["a", "b"])

    let task = model.move(fromOffsets: IndexSet(integer: 0), toOffset: 1)

    XCTAssertNil(task)
    XCTAssertTrue(service.reorderedIds.isEmpty)
  }

  func testFailedMoveReloadsTheServerOrder() async {
    let (model, service) = await loadedModel(ids: ["a", "b", "c"])
    service.reorderError = TerminalPositionsHTTPClient.Error.rejected(status: 422, message: "ids must match")

    await model.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)?.value

    XCTAssertEqual(model.positions.map(\.id), ["a", "b", "c"])
    XCTAssertEqual(service.listTickers.count, 2, "initial load plus the reload")
    XCTAssertEqual(model.errorMessage, "The new order could not be saved.")
  }

  func testRapidMovesKeepTheLastOrder() async {
    let (model, service) = await loadedModel(ids: ["a", "b", "c"])

    let first = model.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
    let second = model.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
    await first?.value
    await second?.value

    XCTAssertEqual(service.reorderedIds, [["c", "a", "b"], ["b", "c", "a"]])
    XCTAssertEqual(model.positions.map(\.id), ["b", "c", "a"])
  }

  func testSavedReplacesAnEditedRowAndAppendsANewOne() async {
    let (model, _) = await loadedModel(ids: ["a", "b"])

    model.saved(.fixture(id: "a", valueWanted: 2_000_000))
    model.saved(.fixture(id: "z"))

    XCTAssertEqual(model.positions.map(\.id), ["a", "b", "z"])
    XCTAssertEqual(model.positions[0].valueWanted, 2_000_000)
  }
}
