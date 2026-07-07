import SwiftUI
import XCTest

@testable import financeplan

@MainActor
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

    func testGoogleSocialAuthButtonUsesBlackTextOnWhiteSurface() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("financeplan/Features/Auth/SocialAuthButton.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(
            source.contains("case .google: .black"),
            "Google OAuth text must stay black because the button background is white in every appearance."
        )
        XCTAssertFalse(
            source.contains("case .google: .primary"),
            "Google OAuth text must not use .primary because it resolves to white in dark mode."
        )
        XCTAssertTrue(
            source.contains("case .google: Color.black.opacity(0.12)"),
            "Google OAuth needs a visible light-surface border in both light and dark appearances."
        )
    }
}
