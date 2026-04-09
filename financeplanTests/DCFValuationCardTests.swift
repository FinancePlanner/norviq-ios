import SwiftUI
import XCTest

@testable import financeplan

final class DCFValuationCardTests: XCTestCase {

    func testDCFValuationCard_canBeCompiled() {
        let card = DCFValuationCard(
            basePrice: 156.13,
            bearPrice: 138.15,
            bullPrice: 175.99,
            currentPrice: 71.84
        )

        // Render it into a UIHostingController to ensure no runtime crashes
        let hostingController = UIHostingController(rootView: card)
        XCTAssertNotNil(hostingController.view)
    }

    func testDCFValuationCard_withNegativeUpside() {
        let card = DCFValuationCard(
            basePrice: 50.0,
            bearPrice: 30.0,
            bullPrice: 80.0,
            currentPrice: 100.0
        )

        // Render it into a UIHostingController to ensure no runtime crashes
        let hostingController = UIHostingController(rootView: card)
        XCTAssertNotNil(hostingController.view)
    }
}
