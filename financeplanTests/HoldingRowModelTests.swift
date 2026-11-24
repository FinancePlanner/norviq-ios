import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

/// A holding row prints every amount in the holding's own currency, and a
/// missing price reads as "unavailable", never as a total loss (spec § 2.0
/// A3, A6).
@MainActor
final class HoldingRowModelTests: XCTestCase {
  private let unitedStates = Locale(identifier: "en_US")
  private let portugal = Locale(identifier: "pt_PT")

  private func pnl(
    currency: String = "USD",
    currentPrice: Double?,
    marketValue: Double?,
    costBasis: Double,
    unrealizedPnl: Double,
    unrealizedPnlPercent: Double? = nil
  ) -> PnlBySymbol {
    PnlBySymbol(
      symbol: "ABCL",
      currency: currency,
      realizedPnl: 0,
      unrealizedPnl: unrealizedPnl,
      shares: 255.05,
      costBasis: costBasis,
      currentPrice: currentPrice,
      marketValue: marketValue,
      unrealizedPnlPercent: unrealizedPnlPercent
    )
  }

  func testZeroPriceIsUnavailable() {
    let model = HoldingRowModel.make(
      pnl: pnl(currentPrice: 0, marketValue: 0, costBasis: 1075.89, unrealizedPnl: -1075.89),
      quote: nil,
      shares: 100,
      costBasis: 1075.89,
      locale: unitedStates
    )
    XCTAssertTrue(model.priceUnavailable)
    XCTAssertNil(model.priceText)
    XCTAssertNil(model.marketValueText)
    XCTAssertNil(model.glText)
    XCTAssertEqual(model.costText, "$1,075.89")
  }

  func testNilPriceIsUnavailable() {
    let model = HoldingRowModel.make(
      pnl: pnl(currentPrice: nil, marketValue: nil, costBasis: 50, unrealizedPnl: 0),
      quote: nil,
      shares: 10,
      costBasis: 50,
      locale: unitedStates
    )
    XCTAssertTrue(model.priceUnavailable)
    XCTAssertNil(model.marketValueText)
    XCTAssertNil(model.glText)
  }

  func testNothingLoadedYetIsNotUnavailable() {
    let model = HoldingRowModel.make(pnl: nil, quote: nil, shares: 10, costBasis: 50, locale: unitedStates)
    XCTAssertFalse(model.isLoaded)
    XCTAssertFalse(model.priceUnavailable)
    XCTAssertNil(model.marketValueText)
    // No currency anywhere: the number is shown with " —", never "$".
    XCTAssertEqual(model.costText, "50.00\u{00A0}—")
  }

  func testDayChangeOfAnUnpricedPnlIsNotUsed() {
    // The P/L has no price, so its day change is not about this price.
    let quote = QuoteResponse(
      symbol: "ABCL", currency: "USD", currentPrice: 11, change: 0.5, percentChange: 4.76,
      high: nil, low: nil, open: nil, previousClose: nil, timestamp: 0
    )
    let unpriced = PnlBySymbol(
      symbol: "ABCL", currency: "USD", realizedPnl: 0, unrealizedPnl: -100,
      shares: 10, costBasis: 100, currentPrice: 0, marketValue: 0,
      dayChange: -999, dayChangePercent: -50
    )
    let model = HoldingRowModel.make(pnl: unpriced, quote: quote, shares: 10, costBasis: 100, locale: unitedStates)
    XCTAssertEqual(model.dayChangeText, "+$5.00 (+4.8%)")
  }

  func testZeroPnlPriceFallsBackToTheLiveQuote() {
    let quote = QuoteResponse(
      symbol: "ABCL", currency: "USD", currentPrice: 11, change: nil, percentChange: nil,
      high: nil, low: nil, open: nil, previousClose: nil, timestamp: 0
    )
    let model = HoldingRowModel.make(
      pnl: pnl(currentPrice: 0, marketValue: 0, costBasis: 100, unrealizedPnl: -100),
      quote: quote,
      shares: 10,
      costBasis: 100,
      locale: unitedStates
    )
    XCTAssertFalse(model.priceUnavailable)
    XCTAssertEqual(model.priceText, "$11.00")
    XCTAssertEqual(model.marketValueText, "$110.00")
    XCTAssertEqual(model.glText, "+$10.00 (+10.0%)")
  }

  func testUsdHoldingInPtLocale() {
    let model = HoldingRowModel.make(
      pnl: pnl(currentPrice: 10.78, marketValue: 2749.47, costBasis: 965.54, unrealizedPnl: 1783.93),
      quote: nil,
      shares: 255.05,
      costBasis: 965.54,
      locale: portugal
    )
    XCTAssertEqual(model.costText, "965,54\u{00A0}US$")
    XCTAssertFalse(model.costText.contains("€"))
    XCTAssertEqual(model.priceText, "10,78\u{00A0}US$")
  }

  func testGainUsesSameCurrencyAsValue() {
    let model = HoldingRowModel.make(
      pnl: pnl(currentPrice: 10.78, marketValue: 2749.47, costBasis: 965.54, unrealizedPnl: 1783.93, unrealizedPnlPercent: 184.76),
      quote: nil,
      shares: 255.05,
      costBasis: 965.54,
      locale: portugal
    )
    // pt-PT does not group four-digit numbers (CLDR minimum grouping digits).
    XCTAssertEqual(model.marketValueText, "2749,47\u{00A0}US$")
    XCTAssertEqual(model.glText, "+1783,93\u{00A0}US$ (+184,8%)")
  }

  /// The backend labels every P/L with the portfolio's base currency and
  /// does not convert, so its figures are in the instrument's currency: the
  /// quote names that currency (spec § 2.0 A3).
  func testInstrumentCurrencyFromTheQuoteBeatsThePnlLabel() {
    let quote = QuoteResponse(
      symbol: "SAP", currency: "EUR", currentPrice: 200, change: nil, percentChange: nil,
      high: nil, low: nil, open: nil, previousClose: nil, timestamp: 0
    )
    let model = HoldingRowModel.make(
      pnl: pnl(currency: "USD", currentPrice: 200, marketValue: 400, costBasis: 300, unrealizedPnl: 100),
      quote: quote,
      shares: 2,
      costBasis: 300,
      locale: unitedStates
    )
    XCTAssertEqual(model.currencyCode, "EUR")
    XCTAssertEqual(model.priceText, "€200.00")
    XCTAssertEqual(model.marketValueText, "€400.00")
    XCTAssertEqual(model.costText, "€300.00")
  }

  func testQuoteCurrencyWithoutPnl() {
    let quote = QuoteResponse(
      symbol: "SAP", currency: "EUR", currentPrice: 200, change: nil, percentChange: nil,
      high: nil, low: nil, open: nil, previousClose: nil, timestamp: 0
    )
    let model = HoldingRowModel.make(pnl: nil, quote: quote, shares: 2, costBasis: 300, locale: unitedStates)
    XCTAssertFalse(model.priceUnavailable)
    XCTAssertEqual(model.priceText, "€200.00")
    XCTAssertEqual(model.marketValueText, "€400.00")
    XCTAssertEqual(model.glText, "+€100.00 (+33.3%)")
  }
}
