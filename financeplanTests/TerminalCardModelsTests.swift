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
}
