import XCTest
import StockPlanShared
@testable import financeplan

final class FinancialHealthCardTests: XCTestCase {
    func testDashboardInsightsResponseDecodingIncludesFinancialHealth() throws {
        let payload = """
        {
          "savingsRate": 22.5,
          "budgetStreak": 4,
          "watchlistCount": 7,
          "cashBuffer": 12000,
          "financialHealth": {
            "score": 82,
            "maxScore": 100,
            "status": "healthy"
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder.stockPlanShared.decode(DashboardInsightsResponse.self, from: payload)
        XCTAssertEqual(decoded.savingsRate, 22.5, accuracy: 0.0001)
        XCTAssertEqual(decoded.financialHealth.score, 82)
        XCTAssertEqual(decoded.financialHealth.maxScore, 100)
        XCTAssertEqual(decoded.financialHealth.status, .healthy)
    }

    func testFinancialHealthCardStateCoversLoadingLoadedAndUnavailable() {
        let loading = FinancialHealthCardState(
            health: nil,
            isLoading: true,
            isUnavailable: false
        )
        XCTAssertEqual(loading.scoreText, "--")
        XCTAssertEqual(loading.summaryText, "--/100")
        XCTAssertEqual(loading.tone, .neutral)

        let loaded = FinancialHealthCardState(
            health: DashboardFinancialHealthDTO(score: 91, maxScore: 100, status: .excellent),
            isLoading: false,
            isUnavailable: false
        )
        XCTAssertEqual(loaded.scoreText, "91")
        XCTAssertEqual(loaded.summaryText, "91/100 - Excellent")
        XCTAssertEqual(loaded.tone, .success)
        XCTAssertEqual(loaded.ringProgress, 0.91, accuracy: 0.0001)

        let unavailable = FinancialHealthCardState(
            health: nil,
            isLoading: false,
            isUnavailable: true
        )
        XCTAssertEqual(unavailable.scoreText, "--")
        XCTAssertEqual(unavailable.summaryText, "--/100 - Unavailable")
        XCTAssertEqual(unavailable.tone, .neutral)
        XCTAssertEqual(unavailable.ringProgress, 0)
    }
}
