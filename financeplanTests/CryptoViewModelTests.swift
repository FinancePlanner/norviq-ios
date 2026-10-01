import Foundation
import StockPlanShared
import XCTest

@testable import financeplan

@MainActor
final class CryptoViewModelTests: XCTestCase {
  func testLoadWithoutForceUsesCachedResultAfterInitialSuccess() async {
    let service = CryptoServiceMock()
    let viewModel = CryptoViewModel(
      cryptoService: service,
      marketDataService: MarketDataServiceStub()
    )

    await viewModel.load()
    await viewModel.load()

    XCTAssertEqual(service.fetchPortfolioCalls, 1)
    XCTAssertEqual(service.fetchCryptoListCalls, 1)
    XCTAssertEqual(service.fetchGeneralCryptoNewsCalls, 1)
  }

  func testLoadWithForceRefetchesAfterInitialSuccess() async {
    let service = CryptoServiceMock()
    let viewModel = CryptoViewModel(
      cryptoService: service,
      marketDataService: MarketDataServiceStub()
    )

    await viewModel.load()
    await viewModel.load(force: true)

    XCTAssertEqual(service.fetchPortfolioCalls, 2)
    XCTAssertEqual(service.fetchCryptoListCalls, 2)
    XCTAssertEqual(service.fetchGeneralCryptoNewsCalls, 2)
  }

  // The watchlist route is not served by every backend build; a 404 there
  // must not take down the rest of the crypto overview.
  func testLoadSucceedsWhenWatchlistFails() async {
    let service = CryptoServiceMock()
    service.watchlistError = CryptoMockError.notConfigured
    let viewModel = CryptoViewModel(
      cryptoService: service,
      marketDataService: MarketDataServiceStub()
    )

    await viewModel.load()

    XCTAssertNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.watchlist.isEmpty)

    await viewModel.load()
    XCTAssertEqual(service.fetchCryptoListCalls, 1, "a failed watchlist must not block caching")
  }

  func testOverviewUsesMarketWideMoversAndBreadth() async {
    let service = CryptoServiceMock()
    service.markets = Self.markets(gainers: ["SOL", "DOGE"], losers: ["PEPE"], advancers: 75, decliners: 25)
    let viewModel = CryptoViewModel(cryptoService: service, marketDataService: MarketDataServiceStub())

    await viewModel.load()

    XCTAssertEqual(viewModel.topGainers.map(\.symbol), ["SOL", "DOGE"])
    XCTAssertEqual(viewModel.topLosers.map(\.symbol), ["PEPE"])
    XCTAssertEqual(viewModel.sentimentValue, 75)
  }

  // Multi-symbol quotes 402 on FMP's basic plan; the markets feed must carry
  // the overview on its own.
  func testQuoteFailureIsSurvivableWithMarketsData() async {
    let service = CryptoServiceMock()
    service.list = [CryptoAssetResponse(symbol: "BTCUSD", name: "Bitcoin")]
    service.quoteError = CryptoMockError.notConfigured
    service.markets = Self.markets(gainers: ["SOL"], losers: [], advancers: 1, decliners: 0)
    let viewModel = CryptoViewModel(cryptoService: service, marketDataService: MarketDataServiceStub())

    await viewModel.load()

    XCTAssertNil(viewModel.errorMessage)
    XCTAssertEqual(viewModel.topGainers.map(\.symbol), ["SOL"])
  }

  func testQuoteFailureWithoutMarketsStillReportsAnError() async {
    let service = CryptoServiceMock()
    service.list = [CryptoAssetResponse(symbol: "BTCUSD", name: "Bitcoin")]
    service.quoteError = CryptoMockError.notConfigured
    let viewModel = CryptoViewModel(cryptoService: service, marketDataService: MarketDataServiceStub())

    await viewModel.load()

    XCTAssertNotNil(viewModel.errorMessage)
  }

  private static func markets(gainers: [String], losers: [String], advancers: Int, decliners: Int) -> CryptoMarketsResponse {
    func coin(_ symbol: String) -> CryptoMarketCoin {
      CryptoMarketCoin(id: symbol.lowercased(), symbol: symbol, name: symbol, sector: "Other", price: 1, changePct: 1)
    }
    return CryptoMarketsResponse(
      timeframe: .oneDay, supportedTimeframes: [.oneDay], source: "stub", asOf: "2026-10-01T00:00:00Z",
      isStale: false, colorMode: .change, colorScaleMaxPct: 5, attribution: nil,
      summary: .init(totalMarketCap: nil, btcDominancePct: nil, advancers: advancers, decliners: decliners),
      coins: [], gainers: gainers.map(coin), losers: losers.map(coin),
      athBoard: .init(recentAths: [], nearAth: [], deepestDrawdowns: [])
    )
  }
}

@MainActor
private final class CryptoServiceMock: CryptoServicing, @unchecked Sendable {
  var fetchCryptoListCalls = 0
  var fetchGeneralCryptoNewsCalls = 0
  var fetchPortfolioCalls = 0
  var watchlistError: Error?
  var markets: CryptoMarketsResponse?
  var quoteError: Error?

  var list: [CryptoAssetResponse] = []

  func fetchCryptoList() async throws -> [CryptoAssetResponse] {
    fetchCryptoListCalls += 1
    return list
  }

  func fetchGeneralCryptoNews() async throws -> [NewsItemResponse] {
    fetchGeneralCryptoNewsCalls += 1
    return []
  }

  func fetchPortfolio() async throws -> [CryptoPortfolioItemResponse] {
    fetchPortfolioCalls += 1
    return []
  }

  func fetchCryptoQuote(symbols _: String) async throws -> [CryptoQuoteResponse] {
    if let quoteError { throw quoteError }
    return []
  }

  func fetchCryptoMarkets(timeframe _: CryptoMarketsTimeframe, limit _: Int) async throws -> CryptoMarketsResponse {
    guard let markets else { throw CryptoMockError.notConfigured }
    return markets
  }

  func fetchCryptoBatchQuotes(short _: Bool) async throws -> [CryptoQuoteShortResponse] {
    return []
  }

  func fetchHistory(
    symbol _: String,
    resolution _: CryptoChartResolution,
    from _: String?,
    to _: String?
  ) async throws -> [CryptoHistoricalPoint] {
    return []
  }

  func addToPortfolio(
    payload _: CryptoPortfolioItemRequest
  ) async throws -> CryptoPortfolioItemResponse {
    throw CryptoMockError.notConfigured
  }

  func updatePortfolioItem(
    itemId _: String,
    payload _: CryptoPortfolioItemRequest
  ) async throws -> CryptoPortfolioItemResponse {
    throw CryptoMockError.notConfigured
  }

  func removeFromPortfolio(itemId _: String) async throws {
    throw CryptoMockError.notConfigured
  }

  func fetchWatchlist() async throws -> [CryptoWatchlistItemResponse] {
    if let watchlistError { throw watchlistError }
    return []
  }

  func addToWatchlist(
    payload _: CryptoWatchlistItemRequest
  ) async throws -> CryptoWatchlistItemResponse {
    throw CryptoMockError.notConfigured
  }

  func updateWatchlistItem(
    itemId _: String,
    payload _: CryptoWatchlistItemRequest
  ) async throws -> CryptoWatchlistItemResponse {
    throw CryptoMockError.notConfigured
  }

  func removeFromWatchlist(itemId _: String) async throws {
    throw CryptoMockError.notConfigured
  }
}

private enum CryptoMockError: LocalizedError {
  case notConfigured

  var errorDescription: String? {
    "Not configured."
  }
}
