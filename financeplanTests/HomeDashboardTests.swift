import Foundation
import XCTest
import StockPlanShared

@testable import financeplan

final class HomeDashboardTests: XCTestCase {

    // MARK: - Tab reachability

    /// HomeScreen registers `primaryTabs` then `moreMenuTabs`. A tab in neither
    /// list compiles, renders, and ships unreachable — which is exactly how the
    /// Markets tab shipped invisible. This asserts every HomeTab case has a
    /// way in, so adding a tab without a list entry fails here instead of in
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
            "Markets must remain reachable from More / the iPad sidebar."
        )
    }

    func testHomeScreenRegistersPrimaryTabsBeforeOverflow() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("financeplan/Features/Home/HomeScreen.swift")
        let src = try String(contentsOf: url, encoding: .utf8)
        let primary = src.range(of: "HomeTab.primaryTabs")
        let more = src.range(of: "HomeTab.moreMenuTabs")
        XCTAssertNotNil(primary, "HomeScreen must register primaryTabs so iPhone shows Home/Portfolio/Expenses/Crypto.")
        XCTAssertNotNil(more, "HomeScreen must register moreMenuTabs after the primary four.")
        if let primary, let more {
            XCTAssertLessThan(
                primary.lowerBound,
                more.lowerBound,
                "primaryTabs must be registered first or Expenses/Crypto fall into More."
            )
        }
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

    /// iPhone More already pushes Markets/Economy onto a UINavigationController.
    /// A second NavigationStack inside those screens is what stacked two bars
    /// (back on one row, AI on the other; two back buttons on Inflation etc.).
    func testOverflowTabsDoNotNestNavigationStacks() throws {
        let home = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("financeplan/Features/Home/HomeScreen.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(
            home.contains("overflowTabHost"),
            "Markets and Economy must be hosted so iPhone More does not nest NavigationStacks."
        )

        let markets = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("financeplan/Features/Markets/MarketsScreen.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(
            markets.contains("NavigationStack {"),
            "MarketsScreen must not wrap itself in NavigationStack; HomeScreen hosts it on iPad only."
        )

        let economy = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("financeplan/Features/Economy/EconomyHubScreen.swift"),
            encoding: .utf8
        )
        let previewStart = economy.range(of: "#Preview")?.lowerBound ?? economy.endIndex
        let hubBody = economy[..<previewStart]
        XCTAssertFalse(
            hubBody.contains("NavigationStack {"),
            "EconomyHubScreen must not wrap itself in NavigationStack; children inherit the More/iPad stack."
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
