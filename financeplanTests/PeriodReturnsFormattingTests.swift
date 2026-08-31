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

  func testHasUsableWindows() {
    XCTAssertFalse(
      StockPeriodReturnsResponse(
        symbol: "AMD",
        threeMonth: nil,
        sixMonth: nil,
        yearToDate: nil,
        asOf: nil
      ).hasUsableWindows
    )
    XCTAssertTrue(
      StockPeriodReturnsResponse(
        symbol: "AMD",
        threeMonth: -8.9,
        sixMonth: nil,
        yearToDate: nil,
        asOf: nil
      ).hasUsableWindows
    )
  }

  func testDerivesThreeSixAndYTDFromDailyCloses() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 20))
    )

    let points = [
      PriceChartPoint(date: "2026-01-02", close: 100, open: nil, high: nil, low: nil, volume: nil),
      PriceChartPoint(date: "2026-03-02", close: 110, open: nil, high: nil, low: nil, volume: nil),
      PriceChartPoint(date: "2026-06-01", close: 90, open: nil, high: nil, low: nil, volume: nil),
      PriceChartPoint(date: "2026-08-31", close: 120, open: nil, high: nil, low: nil, volume: nil),
    ]

    let returns = PeriodReturnsFromChart.derive(
      symbol: "AMD",
      points: points,
      now: now,
      calendar: calendar
    )

    XCTAssertEqual(returns.symbol, "AMD")
    XCTAssertEqual(try XCTUnwrap(returns.threeMonth), 33.333, accuracy: 0.01)
    XCTAssertEqual(try XCTUnwrap(returns.sixMonth), 9.091, accuracy: 0.01)
    XCTAssertEqual(try XCTUnwrap(returns.yearToDate), 20.0, accuracy: 0.01)
    XCTAssertTrue(returns.hasUsableWindows)
  }

  func testDeriveLeavesMissingWindowsNilWhenHistoryIsTooShort() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31))!

    let returns = PeriodReturnsFromChart.derive(
      symbol: "IPO",
      points: [
        PriceChartPoint(date: "2026-08-30", close: 10, open: nil, high: nil, low: nil, volume: nil),
        PriceChartPoint(date: "2026-08-31", close: 11, open: nil, high: nil, low: nil, volume: nil),
      ],
      now: now,
      calendar: calendar
    )

    XCTAssertNil(returns.threeMonth)
    XCTAssertNil(returns.sixMonth)
    XCTAssertNil(returns.yearToDate)
    XCTAssertFalse(returns.hasUsableWindows)
  }
}
