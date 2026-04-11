import XCTest
import StockPlanShared
import Factory
@testable import financeplan

@MainActor
final class DashboardLogicTests: XCTestCase {

    func testDashboardResponseMapping() {
        let response = DashboardResponse(
            totalValue: 10000.0,
            dailyChange: 500.0,
            dailyChangePercent: 5.0,
            topPerformers: [],
            bottomPerformers: [],
            sectorAllocation: []
        )

        XCTAssertEqual(response.totalValue, 10000.0)
        XCTAssertEqual(response.dailyChange, 500.0)
        XCTAssertEqual(response.dailyChangePercent, 5.0)
    }

    func testDashboardInsightsMapping() {
        let insights = DashboardInsightsResponse(
            savingsRate: 20.0,
            budgetStreak: 5,
            watchlistCount: 10,
            cashBuffer: 15000.0,
            financialHealth: DashboardFinancialHealthDTO(
                score: 88,
                maxScore: 100,
                status: .healthy
            )
        )

        XCTAssertEqual(insights.savingsRate, 20.0)
        XCTAssertEqual(insights.budgetStreak, 5)
        XCTAssertEqual(insights.watchlistCount, 10)
        XCTAssertEqual(insights.cashBuffer, 15000.0)
        XCTAssertEqual(insights.financialHealth.score, 88)
        XCTAssertEqual(insights.financialHealth.status, .healthy)
    }

    @MainActor
    func testDashboardLoading() async throws {
        let data = try await DashboardServiceStub().getDashboard()
        XCTAssertEqual(data.totalValue, 124830.42)
    }
}
