@testable import financeplan
import XCTest

@MainActor
final class MarketSentimentViewModelTests: XCTestCase {
    private func entry(symbol: String, score: Double?, z: Double? = nil) -> TrendingSentimentEntry {
        TrendingSentimentEntry(
            symbol: symbol,
            score: score,
            label: (score ?? 0) > 0 ? "positive" : "negative",
            postCount: 12,
            volumeZ: z,
            delta1d: nil
        )
    }

    private func board(asOfDate: String?) -> MarketTrendingResponse {
        MarketTrendingResponse(
            asOfDate: asOfDate,
            windowDays: 7,
            mostDiscussed: [entry(symbol: "GME", score: 0.4, z: 3.1)],
            bullish: [entry(symbol: "NVDA", score: 0.6)],
            bearish: [entry(symbol: "INTC", score: -0.5)],
            biggestSwings: []
        )
    }

    /// A pipeline that has been configured but has not produced a day yet is a
    /// different situation from one that is broken, and the screen says so
    /// differently.
    func testAwaitingFirstRunIsDistinctFromFailure() {
        let viewModel = MarketSentimentViewModel()
        XCTAssertFalse(viewModel.isAwaitingFirstRun, "no payload yet is not the same as an empty run")

        viewModel.board = board(asOfDate: nil)
        XCTAssertTrue(viewModel.isAwaitingFirstRun)

        viewModel.board = board(asOfDate: "2026-08-20")
        XCTAssertFalse(viewModel.isAwaitingFirstRun)
    }
}
