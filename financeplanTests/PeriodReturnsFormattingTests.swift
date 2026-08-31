import XCTest
@testable import financeplan

final class PeriodReturnsFormattingTests: XCTestCase {
  func testPercentTextUsesPointsNotFractions() {
    XCTAssertEqual(PeriodReturnFormatting.percentText(12.5), "+12.5%")
    XCTAssertEqual(PeriodReturnFormatting.percentText(-3.1), "-3.1%")
    XCTAssertEqual(PeriodReturnFormatting.percentText(nil), "—")
  }

  func testAccessibilityLabelSpeaksTheWindow() {
    XCTAssertEqual(
      PeriodReturnFormatting.accessibilityLabel(period: "3M", value: 12.5),
      "3 month +12.5%"
    )
    XCTAssertEqual(
      PeriodReturnFormatting.accessibilityLabel(period: "YTD", value: nil),
      "year to date —"
    )
  }
}
