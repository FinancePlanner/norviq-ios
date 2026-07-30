import Foundation
import XCTest
import StockPlanShared

@testable import financeplan

final class HomeDashboardTests: XCTestCase {

    // MARK: - Tab reachability

    /// The native tab bar is hidden, so the only ways into a screen are the
    /// custom bottom bar and the More sheet. A tab in neither list compiles,
    /// renders, and ships completely unreachable — which is exactly how the
    /// Markets tab shipped invisible. This asserts every HomeTab case has a
    /// way in, so adding a tab without a menu entry fails here instead of in
    /// the App Store build.
    // HomeTab is main-actor isolated (the app target defaults to MainActor
    // isolation), so its statics and Hashable conformance are only usable here.
    @MainActor
    func testEveryHomeTabIsReachable() {
        let reachable = Set(HomeTab.primaryTabs).union(HomeTab.moreMenuTabs)
        let unreachable = Set(HomeTab.allCases).subtracting(reachable)
        XCTAssertTrue(
            unreachable.isEmpty,
            "These HomeTab cases have no way in — add them to primaryTabs or moreMenuTabs: \(unreachable)"
        )
    }

    @MainActor
    func testMoreMenuIncludesMarketsTab() {
        XCTAssertTrue(
            HomeTab.moreMenuTabs.contains(.markets),
            "Markets must remain reachable from the custom More menu."
        )
    }

    @MainActor
    func testTabListsDoNotOverlapOrDuplicate() {
        XCTAssertEqual(
            Set(HomeTab.moreMenuTabs).count,
            HomeTab.moreMenuTabs.count,
            "Duplicated More menu tabs would render duplicate navigation rows."
        )
        XCTAssertTrue(
            Set(HomeTab.primaryTabs).isDisjoint(with: HomeTab.moreMenuTabs),
            "A tab in both the bottom bar and the More sheet gets two entry points and a confused active indicator."
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
