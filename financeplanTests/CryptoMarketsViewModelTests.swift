import Foundation
import StockPlanShared
import XCTest

@testable import financeplan

@MainActor
final class CryptoMarketsViewModelTests: XCTestCase {
  private var defaults: UserDefaults!
  private let suiteName = "CryptoMarketsViewModelTests"

  override func setUp() async throws {
    defaults = UserDefaults(suiteName: suiteName)
    defaults.removePersistentDomain(forName: suiteName)
  }

  func testLoadFetchesTheSelectedTimeframe() async {
    let fetcher = MarketsFetcherStub()
    let viewModel = CryptoMarketsViewModel(fetcher: fetcher, defaults: defaults)

    await viewModel.load()

    XCTAssertEqual(fetcher.requests, [.oneDay])
    XCTAssertEqual(viewModel.response?.timeframe, .oneDay)
  }

  func testSwitchingBackWithinFreshnessUsesTheCache() async {
    let fetcher = MarketsFetcherStub()
    let viewModel = CryptoMarketsViewModel(fetcher: fetcher, defaults: defaults)

    await viewModel.select(.oneWeek)
    await viewModel.select(.yearToDate)
    await viewModel.select(.oneWeek)

    XCTAssertEqual(fetcher.requests, [.oneWeek, .yearToDate])
    XCTAssertEqual(viewModel.response?.timeframe, .oneWeek)
  }

  func testForcedLoadBypassesTheCache() async {
    let fetcher = MarketsFetcherStub()
    let viewModel = CryptoMarketsViewModel(fetcher: fetcher, defaults: defaults)

    await viewModel.load()
    await viewModel.load(force: true)

    XCTAssertEqual(fetcher.requests, [.oneDay, .oneDay])
  }

  func testFailureKeepsTheLastGoodData() async {
    let fetcher = MarketsFetcherStub()
    let viewModel = CryptoMarketsViewModel(fetcher: fetcher, defaults: defaults)
    await viewModel.load()

    fetcher.error = URLError(.notConnectedToInternet)
    await viewModel.select(.oneMonth)

    XCTAssertEqual(viewModel.response?.timeframe, .oneDay)
    XCTAssertNotNil(viewModel.errorMessage)
  }

  func testTimeframeIsRemembered() async {
    let first = CryptoMarketsViewModel(fetcher: MarketsFetcherStub(), defaults: defaults)
    await first.select(.oneYear)

    let second = CryptoMarketsViewModel(fetcher: MarketsFetcherStub(), defaults: defaults)
    XCTAssertEqual(second.timeframe, .oneYear)
  }

  func testUnsupportedTimeframesAreDisabled() async {
    let fetcher = MarketsFetcherStub()
    fetcher.supported = [.oneDay, .oneWeek, .allTime]
    let viewModel = CryptoMarketsViewModel(fetcher: fetcher, defaults: defaults)

    XCTAssertTrue(viewModel.isEnabled(.yearToDate), "everything is enabled before the first response")
    await viewModel.load()

    XCTAssertFalse(viewModel.isEnabled(.yearToDate))
    XCTAssertTrue(viewModel.isEnabled(.oneWeek))
  }

  func testHeatFractionFollowsTheServerScale() {
    XCTAssertEqual(CryptoHeatColor.fraction(15, scaleMax: 15, mode: .change), 1)
    XCTAssertEqual(CryptoHeatColor.fraction(-40, scaleMax: 15, mode: .change), -1)
    XCTAssertEqual(CryptoHeatColor.fraction(0, scaleMax: 90, mode: .athDistance), 1)
    XCTAssertEqual(CryptoHeatColor.fraction(-45, scaleMax: 90, mode: .athDistance), 0)
    XCTAssertEqual(CryptoHeatColor.fraction(-90, scaleMax: 90, mode: .athDistance), -1)
  }

  func testBubbleInputsSkipCoinsWithoutAMove() {
    let coins = [
      CryptoMarketCoin(id: "bitcoin", symbol: "BTC", fmpSymbol: "BTCUSD", name: "Bitcoin", sector: "Layer 1", price: 1, marketCap: 10, changePct: 2),
      CryptoMarketCoin(id: "new", symbol: "NEW", name: "New", sector: "Other", price: 1, marketCap: 5, changePct: nil),
    ]
    let inputs = CryptoBubbleInput.from(coins)
    XCTAssertEqual(inputs.map(\.symbol), ["BTC"])
    XCTAssertEqual(inputs.first?.detailSymbol, "BTCUSD")
  }

  func testChartRangesReachBackToYearStartAndListing() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!

    XCTAssertEqual(CryptoChartRange.ytd.fromDateString(now: now), "2026-01-01")
    XCTAssertEqual(CryptoChartRange.allTime.fromDateString(now: now), "2010-01-01")
  }
}

@MainActor
private final class MarketsFetcherStub: CryptoMarketsFetching {
  var requests: [CryptoMarketsTimeframe] = []
  var error: Error?
  var supported = CryptoMarketsTimeframe.allCases

  func fetchCryptoMarkets(timeframe: CryptoMarketsTimeframe, limit _: Int) async throws -> CryptoMarketsResponse {
    requests.append(timeframe)
    if let error { throw error }
    return CryptoMarketsResponse(
      timeframe: timeframe,
      supportedTimeframes: supported,
      source: "stub",
      asOf: "2026-10-01T12:00:00Z",
      isStale: false,
      colorMode: timeframe == .allTime ? .athDistance : .change,
      colorScaleMaxPct: 5,
      attribution: nil,
      summary: .init(totalMarketCap: 1, btcDominancePct: 50, advancers: 1, decliners: 0),
      coins: [],
      gainers: [],
      losers: [],
      athBoard: .init(recentAths: [], nearAth: [], deepestDrawdowns: [])
    )
  }
}
