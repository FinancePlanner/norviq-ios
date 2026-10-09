import StockPlanShared
import XCTest

/// Does not compile below StockPlanShared 5.21.0: the terminal maths ships
/// there, and the app must run the same code as the backend.
@MainActor
final class StockPlanSharedPinTests: XCTestCase {
  func testTerminalMathIsTheSharedImplementation() async {
    let input = TerminalScenarioInput(
      terminalShareCount: 11_000_000_000,
      terminalMarketCap: 10_000_000_000_000,
      valueWanted: 1_000_000,
      sharesOwned: 750
    )
    guard case let .success(result) = TerminalMath.evaluate(input) else {
      return XCTFail("The AMZN worked example must be valid")
    }
    XCTAssertEqual(result.terminalSharePrice, 909.0909, accuracy: 0.0001)
    XCTAssertEqual(result.sharesNeeded, 1_100, accuracy: 0.000001)
    XCTAssertEqual(result.progress, 0.681818, accuracy: 0.000001)
    XCTAssertEqual(
      AutobuyMath.monthlyEquivalent(amount: 50, cadence: .weekly, percent: nil) ?? 0,
      50 * 52 / 12,
      accuracy: 0.000001
    )
  }
}
