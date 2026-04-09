import XCTest
@testable import financeplan

final class MarketDataModelsTests: XCTestCase {
  func testStockBasicFinancials_OverviewItemsKeepExpectedOrder() throws {
    let financials = StockBasicFinancials(
      symbol: "AAPL",
      metricType: "all",
      currencyCode: "USD",
      peRatio: 29.4,
      netMargin: 0.2124,
      currentRatio: 1.5401,
      beta: 1.2989,
      fiftyTwoWeekHigh: 310.43,
      fiftyTwoWeekLow: 149.22,
      fiftyTwoWeekLowDate: "2019-01-14",
      fiftyTwoWeekPriceReturnDaily: 101.96334,
      tenDayAverageTradingVolume: 32.50147,
      salesPerShareAnnual: [],
      currentRatioAnnual: [],
      netMarginAnnual: []
    )

    XCTAssertEqual(
      financials.overviewItems.map(\.id),
      [
        "peRatio",
        "netMargin",
        "currentRatio",
        "beta",
        "52WeekHigh",
        "52WeekLow",
        "52WeekReturn",
        "10DayAverageTradingVolume"
      ]
    )
    let firstOverviewValue = try XCTUnwrap(financials.overviewItems.first?.value)
    XCTAssertEqual(firstOverviewValue, 29.4, accuracy: 0.0001)
    XCTAssertFalse(financials.overviewItems[5].detail?.isEmpty ?? true)
  }

  func testStockBasicFinancials_AnnualSeriesItemsUseLatestPointPerMetric() throws {
    let financials = StockBasicFinancials(
      symbol: "AAPL",
      metricType: "all",
      currencyCode: "USD",
      peRatio: nil,
      netMargin: nil,
      currentRatio: nil,
      beta: nil,
      fiftyTwoWeekHigh: nil,
      fiftyTwoWeekLow: nil,
      fiftyTwoWeekLowDate: nil,
      fiftyTwoWeekPriceReturnDaily: nil,
      tenDayAverageTradingVolume: nil,
      salesPerShareAnnual: [
        StockBasicFinancialSeriesPoint(period: "2018-09-29", value: 53.1178),
        StockBasicFinancialSeriesPoint(period: "2019-09-28", value: 55.9645)
      ],
      currentRatioAnnual: [
        StockBasicFinancialSeriesPoint(period: "2019-09-28", value: 1.5401),
        StockBasicFinancialSeriesPoint(period: "2018-09-29", value: 1.1329)
      ],
      netMarginAnnual: [
        StockBasicFinancialSeriesPoint(period: "2018-09-29", value: 0.2241),
        StockBasicFinancialSeriesPoint(period: "2019-09-28", value: 0.2124)
      ]
    )

    XCTAssertEqual(
      financials.annualSeriesItems.map(\.id),
      ["salesPerShare", "currentRatioAnnual", "netMarginAnnual"]
    )
    let salesPerShareValue = try XCTUnwrap(financials.annualSeriesItems.first?.value)
    let currentRatioValue = try XCTUnwrap(financials.annualSeriesItems.dropFirst().first?.value)
    let netMarginValue = try XCTUnwrap(financials.annualSeriesItems.dropFirst(2).first?.value)

    XCTAssertEqual(salesPerShareValue, 55.9645, accuracy: 0.0001)
    XCTAssertEqual(currentRatioValue, 1.5401, accuracy: 0.0001)
    XCTAssertEqual(netMarginValue, 0.2124, accuracy: 0.0001)
  }

  func testStockFinancialStatements_PeriodSelectionFiltersExpectedRecords() {
    let statements = StockFinancialStatements.mock(symbol: "aapl")

    XCTAssertEqual(statements.symbol, "AAPL")
    XCTAssertEqual(statements.balanceSheets(for: .fy).map(\.period), ["FY"])
    XCTAssertEqual(statements.balanceSheets(for: .fy).first?.fiscalYear, "2024")
    XCTAssertEqual(statements.balanceSheets(for: .annual).map(\.period), ["FY", "FY"])
    XCTAssertEqual(statements.balanceSheets(for: .quarter).map(\.period), ["Q4", "Q3", "Q2", "Q1"])
    XCTAssertEqual(statements.cashFlows(for: .q2).map(\.period), ["Q2"])
    XCTAssertEqual(statements.cashFlows(for: .q2).first?.fiscalYear, "2024")
    XCTAssertEqual(statements.ratios(for: .fy).map(\.period), ["FY"])
    XCTAssertEqual(statements.ratios(for: .fy).first?.fiscalYear, "2024")
    XCTAssertEqual(statements.growth(for: .quarter).map(\.period), ["Q4", "Q3", "Q2", "Q1"])
    XCTAssertEqual(statements.estimates.count, 3)
    XCTAssertNil(
      statements.growth(for: .fy)
        .first?
        .entries
        .first(where: { $0.id == "ebitdaGrowth" })?
        .value
    )
  }

  func testStockAnalystConsensus_SupportedTickerListAndWarningMessage() {
    XCTAssertTrue(StockAnalystConsensus.isSupportedTicker("UBER"))
    XCTAssertFalse(StockAnalystConsensus.isSupportedTicker("ZETA"))
    XCTAssertEqual(
      StockAnalystConsensus.unsupportedPlanMessage(for: "zeta"),
      "ZETA is outside the consensus coverage available in the current data plan. Analyst consensus is only implemented for the provider's supported ticker list right now."
    )
  }

  func testFMPFreeTierCoverage_AnalysisUsesSameSupportedTickerList() {
    XCTAssertTrue(FMPFreeTierCoverage.isSupportedTicker("UBER"))
    XCTAssertFalse(FMPFreeTierCoverage.isSupportedTicker("ZETA"))
    XCTAssertEqual(
      FMPFreeTierCoverage.unsupportedAnalysisMessage(for: "zeta"),
      "ZETA is outside the analysis coverage available in the current data plan. Current metrics only work for the provider's supported ticker list right now."
    )
  }
}
