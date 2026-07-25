import Foundation
import XCTest

@testable import financeplan

@MainActor
final class StockPressureViewModelTests: XCTestCase {
  private func makePressure(symbol: String, temperature: Double = 72) -> MarketPressureResponse {
    MarketPressureResponse(
      symbol: symbol,
      asOf: "2026-07-25T12:00:00Z",
      temperature: temperature,
      label: "buying",
      volume: MarketPressureVolume(today: 3_000_000, average30d: 1_000_000, relative: 3, changePct: 2.4),
      insider: MarketPressureInsider(
        windowDays: 90,
        buyCount: 1,
        sellCount: 2,
        netShares: -40_000,
        lastActivityAt: "2026-07-21",
        notable: [
          MarketPressureInsiderTrade(name: "Jane Exec", role: "officer", side: "sell", shares: 50_000, date: "2026-07-20"),
        ]
      ),
      history: [MarketPressureHistoryPoint(date: "2026-07-24", relativeVolume: 1.4)]
    )
  }

  func testLoadPopulatesPressure() async {
    let mock = PressureServiceMock()
    mock.results["AAPL"] = makePressure(symbol: "AAPL")
    let viewModel = StockPressureViewModel(marketDataService: mock)

    await viewModel.load(symbol: "AAPL")

    XCTAssertEqual(viewModel.pressure?.symbol, "AAPL")
    XCTAssertEqual(viewModel.pressure?.temperature, 72)
    XCTAssertEqual(viewModel.pressure?.insider?.netShares, -40_000)
    XCTAssertEqual(mock.calls, ["AAPL"])
  }

  func testLoadSkipsWhenSymbolUnchanged() async {
    let mock = PressureServiceMock()
    mock.results["AAPL"] = makePressure(symbol: "AAPL")
    let viewModel = StockPressureViewModel(marketDataService: mock)

    await viewModel.load(symbol: "AAPL")
    await viewModel.load(symbol: "AAPL")

    XCTAssertEqual(mock.calls, ["AAPL"], "unchanged symbol should not refetch")
  }

  func testLoadFailureLeavesCardHidden() async {
    let mock = PressureServiceMock()
    let viewModel = StockPressureViewModel(marketDataService: mock)

    await viewModel.load(symbol: "NOPE")

    XCTAssertNil(viewModel.pressure)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testDecodeMatchesBackendPayload() throws {
    let json = """
    {"symbol":"AAPL","asOf":"2026-07-25T12:00:00Z","temperature":63.4,"label":"buying",
     "volume":{"today":3000000,"average30d":1000000,"relative":3.0,"changePct":2.4},
     "insider":{"windowDays":90,"buyCount":1,"sellCount":1,"netShares":-40000,
       "lastActivityAt":"2026-07-21",
       "notable":[{"name":"Jane Exec","role":"officer","side":"sell","shares":50000,"date":"2026-07-20"}]},
     "history":[{"date":"2026-07-24","relativeVolume":1.42}]}
    """
    let decoded = try JSONDecoder().decode(MarketPressureResponse.self, from: Data(json.utf8))
    XCTAssertEqual(decoded.temperature, 63.4, accuracy: 0.001)
    XCTAssertEqual(decoded.insider?.notable.first?.side, "sell")
    XCTAssertEqual(decoded.history.first?.relativeVolume ?? 0, 1.42, accuracy: 0.001)
  }
}

private enum PressureMockError: Error {
  case missing
}

private final class PressureServiceMock: MarketDataServicing, @unchecked Sendable {
  var results: [String: MarketPressureResponse] = [:]
  var calls: [String] = []

  func fetchMarketPressure(symbol: String) async throws -> MarketPressureResponse {
    calls.append(symbol)
    guard let result = results[symbol] else { throw PressureMockError.missing }
    return result
  }
}
