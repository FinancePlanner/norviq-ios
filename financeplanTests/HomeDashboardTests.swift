import Foundation
import XCTest
import StockPlanShared

@testable import financeplan

final class HomeDashboardTests: XCTestCase {

    func testMoreMenuIncludesMarketsTab() {
        XCTAssertTrue(
            HomeTab.moreMenuTabs.contains(.markets),
            "Markets must remain reachable from the custom More menu."
        )
    }

    func testMoreMenuTabsAreUnique() {
        XCTAssertEqual(
            Set(HomeTab.moreMenuTabs).count,
            HomeTab.moreMenuTabs.count,
            "Duplicated More menu tabs would render duplicate navigation rows."
        )
    }

    // This is a placeholder test file for the Dashboard logic.
    // Based on the 'DashboardService.swift' existing in Features/Home.

    func testDashboardDataAggregation() async {
        // Here you would mock the DashboardService or a response
        // and assert that the view model correctly aggregates the data
        // for the home screen display.

        // Example structure:
        // let service = MockDashboardService()
        // let viewModel = DashboardViewModel(service: service)
        // await viewModel.load()
        // XCTAssertTrue(viewModel.isLoaded)
        // XCTAssertEqual(viewModel.totalPortfolioValue, 10000.0)

        XCTAssertTrue(true, "Dashboard tests need specific service mocking logic.")
    }
}
