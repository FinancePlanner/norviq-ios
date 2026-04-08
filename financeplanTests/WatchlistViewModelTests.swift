import Foundation
import StockPlanShared
import XCTest

@testable import financeplan

@MainActor
final class WatchlistViewModelTests: XCTestCase {
  func testLoadWithoutForceUsesCachedResultAfterInitialSuccess() async {
    let service = MockStockService()
    service.fetchWatchlistResult = .success([makeWatchlistItem(symbol: "AAPL")])
    let viewModel = WatchlistViewModel(service: service)

    await viewModel.load()
    await viewModel.load()

    XCTAssertEqual(service.fetchWatchlistCalls, 1)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoadWithForceRefetchesAfterInitialSuccess() async {
    let service = MockStockService()
    service.fetchWatchlistResult = .success([makeWatchlistItem(symbol: "AAPL")])
    let viewModel = WatchlistViewModel(service: service)

    await viewModel.load()
    await viewModel.load(force: true)

    XCTAssertEqual(service.fetchWatchlistCalls, 2)
  }

  private func makeWatchlistItem(symbol: String) -> WatchlistItemResponse {
    WatchlistItemResponse(
      id: UUID().uuidString,
      symbol: symbol,
      note: nil,
      status: .active,
      nextReviewAt: nil
    )
  }
}

private final class MockStockService: StockServicing {
  var fetchWatchlistCalls = 0
  var fetchWatchlistResult: Result<[WatchlistItemResponse], Error> = .success([])

  func fetchWatchlist() async throws -> [WatchlistItemResponse] {
    fetchWatchlistCalls += 1
    return try fetchWatchlistResult.get()
  }

  func create(stock _: StockRequest) async throws -> StockResponse {
    throw MockStockError.notConfigured
  }

  func bulkCreate(stocks _: [StockRequest]) async throws -> BulkStockResponse {
    throw MockStockError.notConfigured
  }

  func fetchPortfolio() async throws -> [StockResponse] {
    throw MockStockError.notConfigured
  }

  func fetchStockDetails(stockId _: String) async throws -> StockDetails {
    throw MockStockError.notConfigured
  }

  func fetchStockHistory(symbol _: String) async throws -> [StockHistory] {
    throw MockStockError.notConfigured
  }

  func fetchStockNews(symbol _: String) async throws -> [StockNews] {
    throw MockStockError.notConfigured
  }

  func updateStock(_: StockResponse) async throws -> StockResponse {
    throw MockStockError.notConfigured
  }

  func delete(id _: String) async throws {
    throw MockStockError.notConfigured
  }

  func getValuation(symbol _: String) async throws -> StockValuationRequest {
    throw MockStockError.notConfigured
  }

  func createValuation(
    symbol _: String,
    draft _: StockValuationDraft
  ) async throws -> StockValuationRequest {
    throw MockStockError.notConfigured
  }

  func createValuation(
    symbol _: String,
    bearLow _: Double,
    bearHigh _: Double,
    baseLow _: Double,
    baseHigh _: Double,
    bullLow _: Double,
    bullHigh _: Double,
    rationale _: String?,
    targetDate _: String?
  ) async throws -> StockValuationRequest {
    throw MockStockError.notConfigured
  }

  func updateValuation(
    symbol _: String,
    draft _: StockValuationDraft
  ) async throws -> StockValuationRequest {
    throw MockStockError.notConfigured
  }

  func updateValuation(
    symbol _: String,
    bearLow _: Double,
    bearHigh _: Double,
    baseLow _: Double,
    baseHigh _: Double,
    bullLow _: Double,
    bullHigh _: Double,
    rationale _: String?,
    targetDate _: String?
  ) async throws -> StockValuationRequest {
    throw MockStockError.notConfigured
  }

  func createWatchlistItem(_ request: WatchlistItemRequest) async throws -> WatchlistItemResponse {
    throw MockStockError.notConfigured
  }

  func updateWatchlistItem(
    id _: String,
    request _: WatchlistItemUpdateRequest
  ) async throws -> WatchlistItemResponse {
    throw MockStockError.notConfigured
  }

  func deleteWatchlistItem(id _: String) async throws {
    throw MockStockError.notConfigured
  }
}

private enum MockStockError: LocalizedError {
  case notConfigured

  var errorDescription: String? {
    "Not configured."
  }
}
