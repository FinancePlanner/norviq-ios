import Foundation
import StockPlanShared
import XCTest

@testable import financeplan

@MainActor
final class PortfolioViewModelTests: XCTestCase {
  func testLoadCallsServiceAndClearsErrorOnSuccess() async {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([
      makeStock(id: "aapl", symbol: "AAPL", shares: 10, buyPrice: 150),
      makeStock(id: "msft", symbol: "MSFT", shares: 5, buyPrice: 200)
    ])

    let viewModel = PortfolioViewModel(service: service)
    await viewModel.load()

    XCTAssertEqual(service.fetchPortfolioCalls, 1)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoadWithoutForceUsesCachedResultAfterFirstSuccess() async {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([
      makeStock(id: "aapl", symbol: "AAPL", shares: 10, buyPrice: 150)
    ])

    let viewModel = PortfolioViewModel(service: service)
    await viewModel.load()
    await viewModel.load()

    XCTAssertEqual(service.fetchPortfolioCalls, 1)
  }

  func testLoadWithForceRefetchesAfterInitialSuccess() async {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([
      makeStock(id: "aapl", symbol: "AAPL", shares: 10, buyPrice: 150)
    ])

    let viewModel = PortfolioViewModel(service: service)
    await viewModel.load()
    await viewModel.load(force: true)

    XCTAssertEqual(service.fetchPortfolioCalls, 2)
  }

  func testDeleteFailurePublishesError() async {
    let service = MockStockService()
    service.deleteResult = .failure(MockError("Delete failed."))

    let viewModel = PortfolioViewModel(service: service)
    let ok = await viewModel.delete(id: "aapl")

    XCTAssertFalse(ok)
    XCTAssertEqual(viewModel.errorMessage, "Delete failed.")
    XCTAssertFalse(viewModel.isDeletingStock)
  }

  func testSaveNewPositionCreatesAndInsertsStock() async {
    let service = MockStockService()
    let created = makeStock(id: "nvda", symbol: "NVDA", shares: 3, buyPrice: 120)
    service.createResult = .success(created)

    let viewModel = PortfolioViewModel(service: service)
    let message = await viewModel.saveNewPosition(
      AddPositionDraft(
        symbol: " nvda ",
        companyName: nil,
        shares: "3",
        buyPrice: "120",
        buyDate: makeDate(2026, 3, 26),
        notes: "Core idea",
        symbolLocked: false
      )
    )

    XCTAssertNil(message)
    XCTAssertEqual(service.createCalls, 1)
    XCTAssertEqual(service.lastCreateRequest?.symbol, "NVDA")
    XCTAssertEqual(service.lastCreateRequest?.shares, 3)
    XCTAssertEqual(service.lastCreateRequest?.buyPrice, 120)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isSaving)
  }

  func testSaveNewPositionRejectsInvalidDraft() async {
    let service = MockStockService()
    let viewModel = PortfolioViewModel(service: service)

    let message = await viewModel.saveNewPosition(
      AddPositionDraft(
        symbol: "",
        companyName: nil,
        shares: "abc",
        buyPrice: "10",
        buyDate: makeDate(2026, 3, 26),
        notes: "",
        symbolLocked: false
      )
    )

    XCTAssertEqual(message, "Enter valid symbol, shares, and buy price.")
    XCTAssertEqual(service.createCalls, 0)
  }

  private func makeStock(
    id: String,
    symbol: String,
    shares: Double,
    buyPrice: Double
  ) -> StockResponse {
    StockResponse(
      id: id,
      symbol: symbol,
      shares: shares,
      buyPrice: buyPrice,
      buyDate: "2026-03-26",
      notes: nil
    )
  }

  private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) ?? .now
  }
}

private final class MockStockService: StockServicing {
  var fetchPortfolioCalls = 0
  var createCalls = 0
  var lastCreateRequest: StockRequest?
  var fetchPortfolioResult: Result<[StockResponse], Error> = .success([])
  var createResult: Result<StockResponse, Error> = .failure(MockError("Not configured."))
  var updateResult: Result<StockResponse, Error> = .failure(MockError("Not configured."))
  var deleteResult: Result<Void, Error> = .success(())

  func create(stock: StockRequest) async throws -> StockResponse {
    createCalls += 1
    lastCreateRequest = stock
    return try createResult.get()
  }

  func bulkCreate(stocks _: [StockRequest]) async throws -> BulkStockResponse {
    throw MockError("Not configured.")
  }

  func fetchPortfolio() async throws -> [StockResponse] {
    fetchPortfolioCalls += 1
    return try fetchPortfolioResult.get()
  }

  func fetchStockDetails(stockId _: String) async throws -> StockDetails {
    throw MockError("Not configured.")
  }

  func fetchStockHistory(symbol _: String) async throws -> [StockHistory] {
    throw MockError("Not configured.")
  }

  func fetchStockNews(symbol _: String) async throws -> [StockNews] {
    throw MockError("Not configured.")
  }

  func updateStock(_ stock: StockResponse) async throws -> StockResponse {
    try updateResult.get()
  }

  func delete(id _: String) async throws {
    _ = try deleteResult.get()
  }

  func getValuation(symbol _: String) async throws -> StockValuationRequest {
    throw MockError("Not configured.")
  }

  func createValuation(
    symbol _: String,
    draft _: StockValuationDraft
  ) async throws -> StockValuationRequest {
    throw MockError("Not configured.")
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
    throw MockError("Not configured.")
  }

  func updateValuation(
    symbol _: String,
    draft _: StockValuationDraft
  ) async throws -> StockValuationRequest {
    throw MockError("Not configured.")
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
    throw MockError("Not configured.")
  }

  func fetchWatchlist() async throws -> [WatchlistItemResponse] {
    throw MockError("Not configured.")
  }

  func createWatchlistItem(_ request: WatchlistItemRequest) async throws -> WatchlistItemResponse {
    throw MockError("Not configured.")
  }

  func updateWatchlistItem(
    id _: String,
    request _: WatchlistItemUpdateRequest
  ) async throws -> WatchlistItemResponse {
    throw MockError("Not configured.")
  }

  func deleteWatchlistItem(id _: String) async throws {
    throw MockError("Not configured.")
  }
}

private struct MockError: LocalizedError {
  let message: String

  init(_ message: String) {
    self.message = message
  }

  var errorDescription: String? {
    message
  }
}
