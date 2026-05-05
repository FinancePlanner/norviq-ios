//
//  StockDetailTabTests.swift
//  financeplanUITests
//
//  Created by Gemini on 23.04.26.
//

import XCTest

final class StockDetailTabTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testStockDetailTabSwitchingSmokeTest() throws {
        let app = makeAuthenticatedImportedUserApp(userID: "ui-test-\(UUID().uuidString)")
        app.launch()

        // 1. Navigate to Portfolio
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        XCTAssertTrue(portfolioTab.waitForExistence(timeout: 25))
        portfolioTab.tap()

        // 2. Ensure we have a stock. If not, add one.
        let aaplRow = app.buttons["portfolio.stockRow.AAPL"]
        if !aaplRow.exists {
            let addPositionButton = app.buttons["portfolio.addPositionButton"]
            if !addPositionButton.exists {
                // Try the toolbar menu
                app.buttons["portfolio.actionsMenu"].tap()
                app.buttons["Add position"].tap()
            } else {
                addPositionButton.tap()
            }
            
            let symbolField = app.textFields["Symbol (e.g. AAPL)"]
            XCTAssertTrue(symbolField.waitForExistence(timeout: 8))
            symbolField.tap()
            symbolField.typeText("AAPL")
            
            let sharesField = app.textFields["Shares"]
            sharesField.tap()
            sharesField.typeText("10")
            
            let priceField = app.textFields["Buy price"]
            priceField.tap()
            priceField.typeText("150")
            
            app.buttons["Save"].tap()
            
            XCTAssertTrue(aaplRow.waitForExistence(timeout: 10))
        }

        // 3. Open Stock Details
        aaplRow.tap()
        
        let detailScreen = app.otherElements["stockDetailsScreen"]
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 10))

        // 4. Test Tabs
        let tabs = [
            ("overview", "Overview"),
            ("forecast", "Forecast"), // Projections
            ("compare", "Compare"),
            ("news", "News"),
            ("earnings", "Earnings")
        ]

        for (tabID, tabTitle) in tabs {
            let tabButton = app.buttons["stockDetail.tab.\(tabID)"]
            XCTAssertTrue(tabButton.exists, "Tab button for \(tabTitle) should exist")
            tabButton.tap()
            
            // Allow some time for content to load or at least not crash
            // We can check for some generic static text or just ensure the screen is still there.
            XCTAssertTrue(detailScreen.exists, "Screen should still exist after tapping \(tabTitle) tab")
            
            // Optional: check for specific content markers
            // e.g. for News, we might expect a list or "No News" text.
        }
    }

    @MainActor
    private func makeAuthenticatedImportedUserApp(userID: String, resetSession: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        var launchArguments = [
            "-ui_test_skip_splash",
            "-ui_test_auth_token",
            "ui-test-token",
            "-ui_test_user_id",
            userID,
            "-ui_test_imported_user_id",
            userID,
            "-ui_test_pro_user"
        ]
        if resetSession {
            launchArguments.append("-ui_test_reset_session")
        }
        app.launchArguments += launchArguments
        return app
    }
}
