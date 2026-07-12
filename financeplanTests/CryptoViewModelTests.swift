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
}

@MainActor
private final class CryptoServiceMock: CryptoServicing, @unchecked Sendable {
  var fetchCryptoListCalls = 0
  var fetchGeneralCryptoNewsCalls = 0
  var fetchPortfolioCalls = 0

  func fetchCryptoList() async throws -> [CryptoAssetResponse] {
    fetchCryptoListCalls += 1
    return []
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
    return []
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
