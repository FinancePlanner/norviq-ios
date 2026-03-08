import SwiftUI
import XCTest

@testable import financeplan

final class UIComponentsTests: XCTestCase {

    func testGlowingButton_canBeCompiled() {
        let button = GlowingButton(title: "Test", action: {})

        // Render it into a UIHostingController to ensure no runtime crashes
        let hostingController = UIHostingController(rootView: button)
        XCTAssertNotNil(hostingController.view)
    }

    func testGlassCard_canBeCompiled() {
        let card = GlassCard(cornerRadius: 16) {
            Text("Glass Content")
        }

        let hostingController = UIHostingController(rootView: card)
        XCTAssertNotNil(hostingController.view)
    }

    func testMeshGradientBackground_canBeCompiled() {
        let background = MeshGradientBackground()

        let hostingController = UIHostingController(rootView: background)
        XCTAssertNotNil(hostingController.view)
    }

    func testAppTopBar_canBeCompiled() {
        let topBar = AppTopBar(
            username: "testuser",
            isUserMenuPresented: false,
            onUserTap: {}
        )

        let hostingController = UIHostingController(rootView: topBar)
        XCTAssertNotNil(hostingController.view)
    }
}
