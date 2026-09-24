import StockPlanShared
import XCTest
@testable import financeplan

final class PortfolioOnePageModelTests: XCTestCase {
  private func pnl(_ symbol: String, weight: Double?, value: Double? = nil) -> PnlBySymbol {
    PnlBySymbol(
      symbol: symbol, currency: "USD", realizedPnl: 0, unrealizedPnl: 0, shares: 1, buyPrice: 1,
      costBasis: 1, currentPrice: 1, marketValue: value, unrealizedPnlPercent: 5,
      dayChange: 0, dayChangePercent: 1, weightPercent: weight
    )
  }

  func testSortsByWeightAndCapsAtTwelve() {
    let input = (0..<15).map { pnl("S\($0)", weight: Double($0 + 1)) }
    let model = PortfolioOnePageModel(pnl: input)
    XCTAssertEqual(model.rows.count, 12)
    XCTAssertEqual(model.rows.first?.symbol, "S14")
    XCTAssertEqual(model.otherWeightPercent ?? 0, 6, accuracy: 0.001)
  }

  func testFallsBackToMarketValueWhenWeightMissing() {
    let model = PortfolioOnePageModel(pnl: [pnl("A", weight: nil, value: 300), pnl("B", weight: nil, value: 100)])
    XCTAssertEqual(model.rows.map(\.weightPercent), [75, 25])
    XCTAssertNil(model.otherWeightPercent)
  }

  func testEmpty() {
    let model = PortfolioOnePageModel(pnl: [])
    XCTAssertTrue(model.rows.isEmpty)
    XCTAssertNil(model.otherWeightPercent)
  }
}
