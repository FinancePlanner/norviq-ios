import Foundation
import StockPlanShared
import XCTest

@testable import financeplan

@MainActor
final class WhyMovedViewModelTests: XCTestCase {
  private func makeResponse(movers: [WhyMovedMover], summaryText: String? = nil) -> WhyMovedResponse {
    WhyMovedResponse(
      asOf: "2026-07-25T12:00:00Z",
      portfolioChangePercent: 1.2,
      portfolioChangeValue: 840,
      movers: movers,
      context: WhyMovedContext(
        indices: [WhyMovedIndex(symbol: "SPY", label: "S&P 500", changePercent: 0.4)],
        topics: [WhyMovedTopic(topic: "Stocks", count: 7)]
      ),
      aiSummary: summaryText.map { WhyMovedAISummary(text: $0, generatedAt: "2026-07-25T12:00:00Z") },
      sentimentSource: WhyMovedSentimentSource(
        postsAnalyzed: 12, symbolsCovered: 1, windowDays: 7, lastPostAt: "2026-07-25T10:00:00Z"
      )
    )
  }

  func testLoadPopulatesResponseOnce() async {
    let mock = WhyMovedServiceMock()
    mock.result = .success(makeResponse(
      movers: [WhyMovedMover(symbol: "AAPL", changePercent: 3.1, contribution: 900, weightPercent: 40, sentiment: WhyMovedSentiment(label: "bullish", score: 0.6, postCount: 12))],
      summaryText: "AAPL drove the gain on bullish chatter."
    ))
    let viewModel = WhyMovedViewModel(dashboardService: mock)

    await viewModel.loadIfNeeded()
    await viewModel.loadIfNeeded()

    XCTAssertEqual(viewModel.response?.movers.first?.symbol, "AAPL")
    XCTAssertEqual(viewModel.response?.movers.first?.sentiment?.label, "bullish")
    XCTAssertEqual(viewModel.response?.aiSummary?.text.isEmpty, false)
    XCTAssertEqual(mock.calls, 1, "loadIfNeeded should fetch once")
  }

  func testFailureLeavesResponseNil() async {
    let mock = WhyMovedServiceMock()
    let viewModel = WhyMovedViewModel(dashboardService: mock)

    await viewModel.loadIfNeeded()

    XCTAssertNil(viewModel.response)
  }

  func testDecodeMatchesBackendPayload() throws {
    let json = """
    {"asOf":"2026-07-25T12:00:00Z","portfolioChangePercent":1.2,"portfolioChangeValue":840,
     "movers":[{"symbol":"AAPL","changePercent":3.1,"contribution":900,"weightPercent":40,
       "sentiment":{"label":"bullish","score":0.6,"postCount":12}},
      {"symbol":"XOM","changePercent":-2.0}],
     "context":{"indices":[{"symbol":"SPY","label":"S&P 500","changePercent":0.4}],
       "topics":[{"topic":"Stocks","count":7}]},
     "aiSummary":{"text":"AAPL drove the gain.","generatedAt":"2026-07-25T12:00:00Z"}}
    """
    let decoded = try JSONDecoder().decode(WhyMovedResponse.self, from: Data(json.utf8))
    XCTAssertNil(decoded.sentimentSource, "absent provenance must decode as nil, not a zeroed struct")
    XCTAssertEqual(decoded.movers.count, 2)
    XCTAssertNil(decoded.movers.last?.sentiment)
    XCTAssertEqual(decoded.aiSummary?.text, "AAPL drove the gain.")

    let minimal = """
    {"asOf":"2026-07-25T12:00:00Z","movers":[],"context":{"indices":[],"topics":[]}}
    """
    let empty = try JSONDecoder().decode(WhyMovedResponse.self, from: Data(minimal.utf8))
    XCTAssertNil(empty.aiSummary)
    XCTAssertTrue(empty.movers.isEmpty)
  }
}

private enum WhyMovedMockError: Error {
  case down
}

private final class WhyMovedServiceMock: DashboardServicing, @unchecked Sendable {
  var result: Result<WhyMovedResponse, Error> = .failure(WhyMovedMockError.down)
  var calls = 0

  func getDashboard() async throws -> DashboardResponse {
    throw WhyMovedMockError.down
  }

  func getInsights() async throws -> DashboardInsightsResponse {
    throw WhyMovedMockError.down
  }

  func getWhyMoved() async throws -> WhyMovedResponse {
    calls += 1
    return try result.get()
  }
}
