//
//  financeplanUITestsLaunchTests.swift
//  financeplanUITests
//
//  Created by Fernando Correia on 12.02.26.
//

import XCTest

final class FinanceplanUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Each UI configuration can leave the simulator in landscape, and the
    /// classes that run after this one expect portrait.
    override func tearDownWithError() throws {
        // XCTest calls tearDown on the main thread.
        MainActor.assumeIsolated {
            XCUIDevice.shared.orientation = .portrait
        }
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
