import Foundation
import StockPlanShared
import XCTest

@testable import financeplan

@MainActor
final class PortfolioViewModelTests: XCTestCase {
  func testLoadPopulatesStocksAndPortfolioMetrics() async {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([
      makeStock(id: "aapl", symbol: "AAPL", shares: 10, buyPrice: 150),
      makeStock(id: "msft", symbol: "MSFT", shares: 5, buyPrice: 200),
    ])

    let viewModel = PortfolioViewModel(service: service)
    await viewModel.load()

    XCTAssertEqual(viewModel.stocks.count, 2)
    XCTAssertEqual(viewModel.totalShares, 15, accuracy: 0.001)
    XCTAssertEqual(viewModel.totalValue, 2500, accuracy: 0.001)
    XCTAssertEqual(viewModel.averagePositionValue, 1250, accuracy: 0.001)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testDeleteFailureRestoresStocksAndPublishesError() async {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([
      makeStock(id: "aapl", symbol: "AAPL", shares: 10, buyPrice: 150),
      makeStock(id: "msft", symbol: "MSFT", shares: 5, buyPrice: 200),
    ])
    service.deleteResult = .failure(MockError("Delete failed."))

    let viewModel = PortfolioViewModel(service: service)
    await viewModel.load()
    await viewModel.delete(id: "aapl")

    XCTAssertEqual(viewModel.stocks.count, 2)
    XCTAssertEqual(viewModel.errorMessage, "Delete failed.")
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
    XCTAssertEqual(viewModel.stocks.first?.symbol, "NVDA")
    XCTAssertEqual(viewModel.stocks.count, 1)
    XCTAssertNil(viewModel.errorMessage)
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
    XCTAssertTrue(viewModel.stocks.isEmpty)
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
  var fetchPortfolioResult: Result<[StockResponse], Error> = .success([])
  var createResult: Result<StockResponse, Error> = .failure(MockError("Not configured."))
  var updateResult: Result<StockResponse, Error> = .failure(MockError("Not configured."))
  var deleteResult: Result<Void, Error> = .success(())

  func create(stock _: StockRequest) async throws -> StockResponse {
    try createResult.get()
  }

  func bulkCreate(stocks _: [StockRequest]) async throws -> BulkCreateStocksResponse {
    throw MockError("Not configured.")
  }

  func fetchPortfolio() async throws -> [StockResponse] {
    try fetchPortfolioResult.get()
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
