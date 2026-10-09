import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class TerminalCardModelsTests: XCTestCase {
  func testSummaryWithRowsShowsTheSummary() async {
    let service = MockTerminalPositionsService()
    let summary = TerminalPositionsSummaryResponse.fixture([.fixture(), .fixture(id: "p2", valueWanted: 2_000_000)], monthlyAutobuyTotal: 417)
    service.summaryResult = .success(summary)
    let model = TerminalSummaryCardModel(service: service)

    await model.load()

    XCTAssertEqual(model.state, .summary(summary))
  }

  func testSummaryWithNoRowsShowsTheCompactPrompt() async {
    let service = MockTerminalPositionsService()
    service.summaryResult = .success(.fixture([]))
    let model = TerminalSummaryCardModel(service: service)

    await model.load()

    XCTAssertEqual(model.state, .empty)
  }

  func testSummaryNotFoundHidesTheCard() async {
    let service = MockTerminalPositionsService()
    service.summaryResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 404, message: "Not Found"))
    let model = TerminalSummaryCardModel(service: service)

    await model.load()

    XCTAssertEqual(model.state, .hidden)
  }

  func testCancelledSummaryKeepsLoading() async {
    let service = MockTerminalPositionsService()
    service.summaryResult = .failure(TerminalPositionsHTTPClient.Error.cancelled)
    let model = TerminalSummaryCardModel(service: service)

    await model.load()

    XCTAssertEqual(model.state, .loading)
  }

  func testStockCardFiltersByTheSymbolAndShowsTheFirstRow() async {
    let service = MockTerminalPositionsService()
    service.listResult = .success(.fixture([.fixture(id: "first"), .fixture(id: "second")], currency: "EUR"))
    let model = StockTerminalCardModel(service: service)

    await model.load(symbol: "AMZN")

    XCTAssertEqual(service.listTickers, ["AMZN"])
    XCTAssertEqual(model.state, .position(.fixture(id: "first"), currency: "EUR"))
  }

  func testStockCardWithNoRowOffersToAddOne() async {
    let service = MockTerminalPositionsService()
    service.listResult = .success(.fixture([], currency: "USD"))
    let model = StockTerminalCardModel(service: service)

    await model.load(symbol: "NVDA")

    XCTAssertEqual(model.state, .empty(currency: "USD"))
  }

  func testStockCardNotFoundHides() async {
    let service = MockTerminalPositionsService()
    service.listResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 404, message: "Not Found"))
    let model = StockTerminalCardModel(service: service)

    await model.load(symbol: "AMZN")

    XCTAssertEqual(model.state, .hidden)
  }

  func testSavingFromTheStockCardShowsTheNewRow() async {
    let service = MockTerminalPositionsService()
    service.listResult = .success(.fixture([], currency: "GBP"))
    let model = StockTerminalCardModel(service: service)
    await model.load(symbol: "AMZN")

    model.saved(.fixture(id: "new"))

    XCTAssertEqual(model.state, .position(.fixture(id: "new"), currency: "GBP"))
  }

  func testStockCardDropsAStaleRowWhenTheSymbolChanges() async {
    let service = MockTerminalPositionsService()
    service.listResult = .success(.fixture([.fixture(id: "amzn")]))
    let model = StockTerminalCardModel(service: service)
    await model.load(symbol: "AMZN")
    XCTAssertEqual(model.state, .position(.fixture(id: "amzn"), currency: "USD"))

    service.listResult = .failure(TerminalPositionsHTTPClient.Error.cancelled)
    await model.load(symbol: "NVDA")

    XCTAssertEqual(model.state, .loading)
  }

  func testStockCardRecoversAfterBeingHidden() async {
    let service = MockTerminalPositionsService()
    service.listResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 404, message: "Not Found"))
    let model = StockTerminalCardModel(service: service)
    await model.load(symbol: "AMZN")
    XCTAssertEqual(model.state, .hidden)

    service.listResult = .success(.fixture([.fixture(id: "back")]))
    await model.load(symbol: "AMZN")

    XCTAssertEqual(model.state, .position(.fixture(id: "back"), currency: "USD"))
  }
}
