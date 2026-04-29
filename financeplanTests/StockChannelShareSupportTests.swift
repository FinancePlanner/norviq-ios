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

  func testPortugueseThesisFormatterKeepsTechnicalSymbol() {
    let payload = StockSharePayloadFormatter.thesis(
      symbol: "msft",
      thesis: "Cloud margins improving.",
      details: nil,
      language: .portuguesePortugal,
      style: .discord
    )

    XCTAssertEqual(payload.title, "Tese MSFT")
    XCTAssertTrue(payload.body.contains("Tese de investimento para $MSFT"))
    XCTAssertTrue(payload.body.contains("Não é aconselhamento financeiro."))
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

    XCTAssertEqual(payload.title, "TSLA price targets")
    XCTAssertTrue(payload.body.contains("Price targets for $TSLA"))
    XCTAssertTrue(payload.body.contains("Bear:"))
    XCTAssertTrue(payload.body.contains("Base:"))
    XCTAssertTrue(payload.body.contains("Bull:"))
    XCTAssertTrue(payload.body.contains("Base midpoint implied return:"))
  }

  func testShareDestinationsOnlyIncludeXAndDiscord() {
    XCTAssertEqual(StockShareDestination.allCases, [.x, .discord])
  }

  func testDiscordPriceTargetsUseMarkdownFormatting() {
    let payload = StockSharePayloadFormatter.priceTargets(
      symbol: "tsla",
      valuation: StockValuationRequest(
        symbol: "TSLA",
        bearCase: PriceRange(low: 120, high: 150),
        baseCase: PriceRange(low: 180, high: 220),
        bullCase: PriceRange(low: 260, high: 320),
        rationale: "Operating leverage improves.",
        targetDate: "2026-12-31"
      ),
      currentPrice: 200,
      style: .discord
    )

    XCTAssertTrue(payload.body.contains("**Price targets for $TSLA**"))
    XCTAssertTrue(payload.body.contains("• Bear:"))
  }

  func testXPriceTargetsAvoidDiscordMarkdownAndStayLimited() {
    let payload = StockSharePayloadFormatter.priceTargets(
      symbol: "tsla",
      valuation: StockValuationRequest(
        symbol: "TSLA",
        bearCase: PriceRange(low: 120, high: 150),
        baseCase: PriceRange(low: 180, high: 220),
        bullCase: PriceRange(low: 260, high: 320),
        rationale: "Operating leverage improves.",
        targetDate: "2026-12-31"
      ),
      currentPrice: 200,
      style: .x
    )

    XCTAssertLessThanOrEqual(payload.body.count, 280)
    XCTAssertFalse(payload.body.contains("**"))
    XCTAssertFalse(payload.body.contains("•"))
  }

  func testXFormatterIsCharacterLimited() {
    let payload = StockSharePayloadFormatter.thesis(
      symbol: "aapl",
      thesis: String(repeating: "Long thesis sentence. ", count: 40),
      details: nil,
      language: .english,
      style: .x
    )

    XCTAssertLessThanOrEqual(payload.body.count, 280)
    XCTAssertTrue(payload.body.contains("$AAPL"))
  }

  func testPortfolioAllocationFormatterIncludesTopHoldingsAndCash() {
    let payload = PortfolioAllocationShareFormatter.payload(
      slices: [
        PortfolioAllocationSlice(id: "1", symbol: "AAPL", value: 2_000, percentage: 50),
        PortfolioAllocationSlice(id: "cash-position", symbol: "CASH", value: 1_000, percentage: 25),
        PortfolioAllocationSlice(id: "2", symbol: "MSFT", value: 1_000, percentage: 25)
      ],
      totalValue: 4_000,
      destination: .discord,
      language: .english
    )

    XCTAssertEqual(payload.title, "Portfolio allocation")
    XCTAssertTrue(payload.body.contains("Total value:"))
    XCTAssertTrue(payload.body.contains("AAPL: 50"))
    XCTAssertTrue(payload.body.contains("CASH: 25"))
    XCTAssertTrue(payload.body.contains("Not investment advice."))
  }

  func testPortfolioAllocationXFormatterLimitsOutput() {
    let slices = (0..<10).map {
      PortfolioAllocationSlice(
        id: "\($0)",
        symbol: "S\($0)",
        value: Double(1_000 - $0),
        percentage: Double(20 - $0)
      )
    }

    let payload = PortfolioAllocationShareFormatter.payload(
      slices: slices,
      totalValue: 10_000,
      destination: .x,
      language: .english
    )

    XCTAssertLessThanOrEqual(payload.body.count, 280)
    XCTAssertTrue(payload.body.contains("+6 more positions"))
  }

  func testAllocationImpactForNewPositionStartsAtZero() {
    let impact = PortfolioAllocationImpactCalculator.preview(
      holdings: [
        .init(id: "aapl", symbol: "AAPL", shares: 1, buyPrice: 100)
      ],
      cashBalance: 0,
      change: .newPosition(symbol: "MSFT", shares: 1, buyPrice: 100)
    )

    XCTAssertEqual(impact?.symbol, "MSFT")
    XCTAssertEqual(impact?.beforePercentage ?? -1, 0, accuracy: 0.001)
    XCTAssertEqual(impact?.afterPercentage ?? -1, 50, accuracy: 0.001)
  }

  func testAllocationImpactForIncreasedPositionRises() {
    let impact = PortfolioAllocationImpactCalculator.preview(
      holdings: [
        .init(id: "aapl", symbol: "AAPL", shares: 1, buyPrice: 100),
        .init(id: "msft", symbol: "MSFT", shares: 1, buyPrice: 100)
      ],
      cashBalance: 0,
      change: .replacePosition(id: "aapl", symbol: "AAPL", shares: 2, buyPrice: 100)
    )

    XCTAssertEqual(impact?.beforePercentage ?? -1, 50, accuracy: 0.001)
    XCTAssertEqual(impact?.afterPercentage ?? -1, 66.666, accuracy: 0.001)
  }

  func testAllocationImpactForPartialSellFallsAndAddsCash() {
    let impact = PortfolioAllocationImpactCalculator.preview(
      holdings: [
        .init(id: "aapl", symbol: "AAPL", shares: 2, buyPrice: 100),
        .init(id: "msft", symbol: "MSFT", shares: 1, buyPrice: 100)
      ],
      cashBalance: 0,
      change: .sellPosition(id: "aapl", symbol: "AAPL", remainingShares: 1, buyPrice: 100, cashProceeds: 100)
    )

    XCTAssertEqual(impact?.beforePercentage ?? -1, 66.666, accuracy: 0.001)
    XCTAssertEqual(impact?.afterPercentage ?? -1, 33.333, accuracy: 0.001)
  }

  func testAllocationImpactForFullSellBecomesZero() {
    let impact = PortfolioAllocationImpactCalculator.preview(
      holdings: [
        .init(id: "aapl", symbol: "AAPL", shares: 1, buyPrice: 100),
        .init(id: "msft", symbol: "MSFT", shares: 1, buyPrice: 100)
      ],
      cashBalance: 0,
      change: .sellPosition(id: "aapl", symbol: "AAPL", remainingShares: 0, buyPrice: 100, cashProceeds: 100)
    )

    XCTAssertEqual(impact?.beforePercentage ?? -1, 50, accuracy: 0.001)
    XCTAssertEqual(impact?.afterPercentage ?? -1, 0, accuracy: 0.001)
  }
}
