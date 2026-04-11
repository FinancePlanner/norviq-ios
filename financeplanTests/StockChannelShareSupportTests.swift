import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class StockChannelShareSupportTests: XCTestCase {
  func testThesisFormatterIncludesSymbolPositionAndNormalizedText() {
    let payload = StockSharePayloadFormatter.thesis(
      symbol: "aapl",
      thesis: "  Durable margin expansion.\n\nServices mix keeps compounding. ",
      details: StockDetails(
        id: "stock-1",
        symbol: "AAPL",
        shares: 10,
        buyPrice: 125,
        buyDate: "2026-03-01",
        notes: nil
      )
    )

    XCTAssertEqual(payload.title, "AAPL thesis")
    XCTAssertTrue(payload.body.contains("Thesis update for $AAPL"))
    XCTAssertTrue(payload.body.contains("Position:"))
    XCTAssertTrue(payload.body.contains("Thesis: Durable margin expansion. Services mix keeps compounding."))
    XCTAssertTrue(payload.body.contains("Not investment advice."))
  }

  func testFundamentalsFormatterIncludesCoreMetrics() {
    let profile = StockComparisonProfile(
      symbol: "AAPL",
      companyName: "Apple Inc.",
      currentPrice: 187.42,
      marketCap: 2_950_000_000_000,
      sharesOutstanding: 15_700_000_000,
      metrics: [
        .ttmPE: 29.1,
        .grossMargin: 0.46,
        .netMargin: 0.25,
        .ttmRevenueGrowth: 0.08,
        .nextYearRevenueGrowth: 0.06
      ],
      projectionScenarios: [:],
      dcfBasePrice: nil,
      dcfBearPrice: nil,
      dcfBullPrice: nil
    )

    let payload = StockSharePayloadFormatter.fundamentals(profile: profile)

    XCTAssertEqual(payload.title, "AAPL fundamentals")
    XCTAssertTrue(payload.body.contains("Fundamentals snapshot for $AAPL"))
    XCTAssertTrue(payload.body.contains("TTM PE:"))
    XCTAssertTrue(payload.body.contains("Gross margin:"))
    XCTAssertTrue(payload.body.contains("Next-year revenue growth:"))
  }

  func testBasePriceFormatterIncludesRangeAndImpliedReturn() {
    let payload = StockSharePayloadFormatter.basePrice(
      symbol: "tsla",
      valuation: StockValuationRequest(
        symbol: "TSLA",
        bearCase: PriceRange(low: 120, high: 150),
        baseCase: PriceRange(low: 180, high: 220),
        bullCase: PriceRange(low: 260, high: 320),
        rationale: "Operating leverage improves.",
        targetDate: "2026-12-31"
      ),
      currentPrice: 200
    )

    XCTAssertEqual(payload.title, "TSLA base price")
    XCTAssertTrue(payload.body.contains("Base-price range for $TSLA"))
    XCTAssertTrue(payload.body.contains("Bear:"))
    XCTAssertTrue(payload.body.contains("Base:"))
    XCTAssertTrue(payload.body.contains("Bull:"))
    XCTAssertTrue(payload.body.contains("Base midpoint implied return:"))
  }
}
