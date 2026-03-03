#if canImport(XCTest)
import Foundation
import XCTest
@testable import financeplan

@MainActor
final class ManualImportViewModelTests: XCTestCase {
    func testAddAndRemoveRows() {
        let vm = ManualImportViewModel()
        XCTAssertEqual(vm.entries.count, 1)
        vm.addRow()
        vm.addRow()
        XCTAssertEqual(vm.entries.count, 3)
        vm.removeRows(at: IndexSet([1]))
        XCTAssertEqual(vm.entries.count, 2)
    }

    func testBuildPositions_TrimsUppercasesAndParsesNumbers() {
        let vm = ManualImportViewModel()
        vm.entries = [
            ManualEntry(symbol: "  aapl  ", quantity: "10", price: "150.5"),
            ManualEntry(symbol: "", quantity: "5", price: "100"), // ignored (empty symbol)
            ManualEntry(symbol: "TSLA", quantity: "0", price: "200"), // ignored (qty 0)
            ManualEntry(symbol: "msft", quantity: "1,234.56", price: "2,345.67")
        ]

        let positions = vm.buildPositions()
        XCTAssertEqual(positions.count, 2)
        XCTAssertEqual(positions[0].symbol, "AAPL")
        XCTAssertEqual(positions[0].quantity, 10)
        XCTAssertEqual(positions[0].price, 150.5, accuracy: 0.0001)
        XCTAssertEqual(positions[1].symbol, "MSFT")
        XCTAssertEqual(positions[1].quantity, 1234.56, accuracy: 0.0001)
        XCTAssertEqual(positions[1].price, 2345.67, accuracy: 0.0001)
    }
}
#endif
