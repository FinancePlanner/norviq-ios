import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

/// The portfolio hero shows real data or says why it can't (spec § 2.0 A1, A2,
/// A5; § 5.5). Dates are UTC days, as the API sends them.
@MainActor
final class PortfolioHeroModelTests: XCTestCase {
  private let unitedStates = Locale(identifier: "en_US")
  private let portugal = Locale(identifier: "pt_PT")

  /// 24 Nov 2026, midday UTC.
  private let now = Date(timeIntervalSince1970: 1_795_521_600)

  private func performance(
    base: String = "USD",
    _ points: [(String, Double)]
  ) -> PortfolioPerformanceResponse {
    PortfolioPerformanceResponse(
      baseCurrency: base,
      points: points.map { PerformancePoint(date: $0.0, value: $0.1) }
    )
  }

  private var freshMonth: PortfolioPerformanceResponse {
    performance([("2026-10-26", 45000), ("2026-11-10", 46500), ("2026-11-23", 48432.05)])
  }

  func testNowFixtureIsTwentyFourthOfNovember() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: now), DateComponents(year: 2026, month: 11, day: 24))
  }

  func testSingleCurrencyUsesPerformanceBaseCurrency() {
    let model = PortfolioHeroModel.make(
      performance: freshMonth,
      holdingsByCurrency: ["USD": 48432.05],
      range: .month,
      now: now,
      locale: portugal
    )
    XCTAssertEqual(model.valueText, "48\u{00A0}432,05\u{00A0}US$")
    XCTAssertTrue(model.subtotalTexts.isEmpty)
  }

  func testMixedCurrencyShowsSubtotals() {
    let model = PortfolioHeroModel.make(
      performance: freshMonth,
      holdingsByCurrency: ["USD": 37630.22, "EUR": 61210.40],
      range: .month,
      now: now,
      locale: unitedStates
    )
    XCTAssertNil(model.valueText)
    XCTAssertEqual(model.subtotalTexts, ["€61,210.40", "$37,630.22"])
    // The series is in one base currency; a money change or an axis in it
    // under per-currency subtotals would imply a summed total.
    XCTAssertNil(model.deltaText)
    XCTAssertNil(model.basisText)
    XCTAssertTrue(model.points.isEmpty)
    XCTAssertNotNil(model.historyCaption)
  }

  func testPortfolioHeadlinePrefersTheLiveTotal() {
    let model = PortfolioHeroModel.make(
      performance: freshMonth,
      holdingsByCurrency: ["USD": 48000],
      range: .month,
      now: now,
      locale: unitedStates,
      liveTotal: 50000,
      preferLiveTotal: true
    )
    // The headline matches the rows (live prices); the change is the series'.
    XCTAssertEqual(model.valueText, "$50,000.00")
    XCTAssertEqual(model.deltaText, "+$3,432.05 (+7.6%)")
  }

  func testStaleSeriesHidesDelta() {
    let model = PortfolioHeroModel.make(
      performance: performance([("2026-11-05", 810.19), ("2026-11-07", 850), ("2026-11-11", 919.06)]),
      holdingsByCurrency: ["USD": 46874.85],
      range: .month,
      now: now,
      locale: unitedStates
    )
    XCTAssertNil(model.deltaText)
    XCTAssertNil(model.basisText)
    XCTAssertNotNil(model.asOfText)
    XCTAssertTrue(model.points.isEmpty)
  }

  func testFourDayOldSeriesIsStillFresh() {
    let model = PortfolioHeroModel.make(
      performance: performance([("2026-11-01", 100), ("2026-11-10", 105), ("2026-11-20", 110)]),
      holdingsByCurrency: [:],
      range: .month,
      now: now,
      locale: unitedStates
    )
    XCTAssertNotNil(model.deltaText)
    XCTAssertNil(model.asOfText)
  }

  func testTwoPointsShowNoTrend() {
    let model = PortfolioHeroModel.make(
      performance: performance([("2026-11-22", 100), ("2026-11-23", 110)]),
      holdingsByCurrency: ["USD": 110],
      range: .month,
      now: now,
      locale: unitedStates
    )
    XCTAssertTrue(model.points.isEmpty)
    XCTAssertNil(model.deltaText)
    XCTAssertNil(model.basisText)
    XCTAssertNotNil(model.historyCaption)
  }

  func testRangeBasisNeverSaysPreviousClose() {
    let model = PortfolioHeroModel.make(
      performance: freshMonth,
      holdingsByCurrency: ["USD": 48432.05],
      range: .month,
      now: now,
      locale: unitedStates
    )
    XCTAssertEqual(model.basisText, "1 month")
    XCTAssertEqual(model.deltaText, "+$3,432.05 (+7.6%)")
    XCTAssertEqual(model.direction, .up)
    XCTAssertEqual(model.points.count, 3)
  }

  func testAllRangeBasisNamesTheFirstPoint() {
    let model = PortfolioHeroModel.make(
      performance: freshMonth,
      holdingsByCurrency: [:],
      range: .all,
      now: now,
      locale: unitedStates
    )
    XCTAssertEqual(model.basisText, "since 26 Oct 2026")
  }

  func testFallingSeriesPointsDown() {
    let model = PortfolioHeroModel.make(
      performance: performance([("2026-11-17", 200), ("2026-11-20", 190), ("2026-11-23", 180)]),
      holdingsByCurrency: [:],
      range: .week,
      now: now,
      locale: unitedStates
    )
    XCTAssertEqual(model.direction, .down)
    XCTAssertEqual(model.deltaText, "\u{2212}$20.00 (\u{2212}10.0%)")
    XCTAssertEqual(model.basisText, "1 week")
  }

  private func quote(_ symbol: String, _ currency: String, _ price: Double) -> QuoteResponse {
    QuoteResponse(
      symbol: symbol, currency: currency, currentPrice: price, change: nil, percentChange: nil,
      high: nil, low: nil, open: nil, previousClose: nil, timestamp: 0
    )
  }

  /// The hero values holdings exactly as the rows do (`HoldingRowModel`):
  /// the P/L when priced, else the live quote, in the instrument currency.
  /// The series is in the portfolio base currency. A headline in another
  /// currency cannot carry a change computed in the base: hide it, keep
  /// the line with its own axis currency.
  func testHeadlineInAnotherCurrencyHidesTheSeriesChange() {
    let model = PortfolioHeroModel.make(
      performance: freshMonth,
      holdingsByCurrency: ["EUR": 1000],
      range: .month,
      now: now,
      locale: unitedStates,
      liveTotal: 1000,
      preferLiveTotal: true
    )
    XCTAssertEqual(model.valueText, "€1,000.00")
    XCTAssertEqual(model.currencyCode, "EUR")
    XCTAssertEqual(model.seriesCurrencyCode, "USD")
    XCTAssertNil(model.deltaText)
    XCTAssertNil(model.basisText)
    XCTAssertEqual(model.points.count, 3)
  }

  func testHeadlineInTheBaseCurrencyKeepsTheChange() {
    let model = PortfolioHeroModel.make(
      performance: freshMonth,
      holdingsByCurrency: ["USD": 48432.05],
      range: .month,
      now: now,
      locale: unitedStates,
      liveTotal: 48432.05,
      preferLiveTotal: true
    )
    XCTAssertEqual(model.seriesCurrencyCode, "USD")
    XCTAssertNotNil(model.deltaText)
  }

  func testValuationMatchesTheRows() {
    let holdings = [
      PortfolioHeroModel.Holding(symbol: "ABCL", shares: 255.05, costBasis: 965.54),
      PortfolioHeroModel.Holding(symbol: "A6I", shares: 100, costBasis: 1075.89),
      PortfolioHeroModel.Holding(symbol: "SAP", shares: 2, costBasis: 300),
      PortfolioHeroModel.Holding(symbol: "VST", shares: 10, costBasis: 1000),
    ]
    let pnl = [
      "ABCL": PnlBySymbol(symbol: "ABCL", currency: "USD", realizedPnl: 0, unrealizedPnl: 0, currentPrice: 10.78, marketValue: 2749.47),
      "A6I": PnlBySymbol(symbol: "A6I", currency: "USD", realizedPnl: 0, unrealizedPnl: -1075.89, currentPrice: 0, marketValue: 0),
      // P/L price 0, live quote present: the quote prices it, as on the row.
      "VST": PnlBySymbol(symbol: "VST", currency: "USD", realizedPnl: 0, unrealizedPnl: 0, currentPrice: 0, marketValue: 0),
    ]
    let quotes = ["SAP": quote("SAP", "EUR", 200), "VST": quote("VST", "USD", 150)]

    let valuation = PortfolioHeroModel.valuation(holdings, pnlBySymbol: pnl, quotes: quotes)
    XCTAssertEqual(valuation.byCurrency["USD"] ?? 0, 2749.47 + 1500, accuracy: 0.001)
    XCTAssertEqual(valuation.byCurrency["EUR"] ?? 0, 400, accuracy: 0.001)
    XCTAssertEqual(valuation.pricedCount, 3)
    XCTAssertEqual(valuation.unpricedCount, 1)
    XCTAssertTrue(valuation.isLoaded)

    // A USD + EUR mix: per-currency subtotals, never one summed figure.
    let model = PortfolioHeroModel.make(
      performance: freshMonth,
      holdingsByCurrency: valuation.byCurrency,
      range: .month,
      now: now,
      locale: unitedStates
    )
    XCTAssertNil(model.valueText)
    XCTAssertEqual(model.subtotalTexts, ["€400.00", "$4,249.47"])
  }

  func testValuationCountsASymbolOnce() {
    // The same symbol in two lists: the P/L is per symbol, so not doubled.
    let holdings = [
      PortfolioHeroModel.Holding(symbol: "abcl", shares: 100, costBasis: 400),
      PortfolioHeroModel.Holding(symbol: "ABCL", shares: 155.05, costBasis: 565.54),
    ]
    let pnl = ["ABCL": PnlBySymbol(symbol: "ABCL", currency: "USD", realizedPnl: 0, unrealizedPnl: 0, currentPrice: 10.78, marketValue: 2749.47)]
    let valuation = PortfolioHeroModel.valuation(holdings, pnlBySymbol: pnl, quotes: [:])
    XCTAssertEqual(valuation.byCurrency, ["USD": 2749.47])
    XCTAssertEqual(valuation.pricedCount, 1)
  }

  func testValuationBeforeAnythingLoaded() {
    let holdings = [PortfolioHeroModel.Holding(symbol: "ABCL", shares: 1, costBasis: 1)]
    let valuation = PortfolioHeroModel.valuation(holdings, pnlBySymbol: [:], quotes: [:])
    XCTAssertFalse(valuation.isLoaded)
    XCTAssertEqual(valuation.unpricedCount, 0)
  }

  func testUnpricedHoldingsKeepTheTotalAndSaySo() {
    let one = PortfolioHeroModel.make(
      performance: freshMonth, holdingsByCurrency: ["USD": 2749.47], range: .month,
      now: now, locale: unitedStates, liveTotal: 2749.47, preferLiveTotal: true, unpricedCount: 1
    )
    XCTAssertEqual(one.valueText, "$2,749.47")
    XCTAssertEqual(one.unpricedCaption, "Excludes 1 unpriced holding")
    let two = PortfolioHeroModel.make(
      performance: freshMonth, holdingsByCurrency: ["USD": 2749.47], range: .month,
      now: now, locale: unitedStates, liveTotal: 2749.47, preferLiveTotal: true, unpricedCount: 2
    )
    XCTAssertEqual(two.unpricedCaption, "Excludes 2 unpriced holdings")
    let none = PortfolioHeroModel.make(
      performance: freshMonth, holdingsByCurrency: ["USD": 2749.47], range: .month,
      now: now, locale: unitedStates, liveTotal: 2749.47, preferLiveTotal: true
    )
    XCTAssertNil(none.unpricedCaption)
  }

  func testHomeStaleSeriesFallsBackToLiveTotalWithoutDelta() {
    let model = PortfolioHeroModel.forHome(
      performance: performance([("2026-11-05", 810.19), ("2026-11-07", 850), ("2026-11-11", 919.06)]),
      reportTotal: 46874.85,
      now: now,
      locale: unitedStates
    )
    XCTAssertEqual(model.valueText, "$46,874.85")
    XCTAssertNil(model.deltaText)
    XCTAssertTrue(model.points.isEmpty)
    XCTAssertTrue(model.asOfText?.contains("11 Nov") ?? false, model.asOfText ?? "nil")
  }

  func testHomeFreshSeriesShowsItsRangeChange() {
    let model = PortfolioHeroModel.forHome(
      performance: freshMonth,
      reportTotal: 48000,
      now: now,
      locale: portugal
    )
    XCTAssertEqual(model.valueText, "48\u{00A0}432,05\u{00A0}US$")
    XCTAssertEqual(model.basisText, PortfolioHeroModel.basis(for: PortfolioHeroModel.homeRange, firstDate: now, locale: portugal))
    XCTAssertNotNil(model.deltaText)
  }

  func testHomeWithoutReportTotalOrSeriesShowsNoValue() {
    let model = PortfolioHeroModel.forHome(performance: nil, reportTotal: nil, now: now, locale: unitedStates)
    XCTAssertNil(model.valueText)
    XCTAssertNil(model.deltaText)
  }
}
