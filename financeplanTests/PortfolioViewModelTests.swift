import Foundation
import StockPlanShared
import SwiftData
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
    XCTAssertEqual(service.fetchPortfolioSummaryCalls, 1)
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
    XCTAssertEqual(service.fetchPortfolioSummaryCalls, 2)
  }

  func testLoadDerivesCashBalanceFromCashAllocation() async {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([makeStock(id: "aapl", symbol: "AAPL", shares: 1, buyPrice: 100)])
    service.fetchPortfolioSummaryResult = .success(
      makeSummary(
        allocation: [
          AllocationItem(symbol: "AAPL", value: 100, currency: "USD"),
          AllocationItem(symbol: "CASH", value: 275.4, currency: "USD")
        ],
        cashBalance: 275.4
      )
    )

    let viewModel = PortfolioViewModel(service: service)
    await viewModel.load()

    XCTAssertEqual(viewModel.cashBalance, 275.4, accuracy: 0.001)
    XCTAssertEqual(service.fetchPortfolioSummaryCalls, 1)
  }

  func testLoadWithNoCashAllocationSetsCashBalanceToZero() async {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([makeStock(id: "aapl", symbol: "AAPL", shares: 1, buyPrice: 100)])
    service.fetchPortfolioSummaryResult = .success(
      makeSummary(allocation: [
        AllocationItem(symbol: "AAPL", value: 100, currency: "USD")
      ])
    )

    let viewModel = PortfolioViewModel(service: service)
    await viewModel.load()

    XCTAssertEqual(viewModel.cashBalance, 0, accuracy: 0.001)
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

  func testLoadReconcilesRemoteStocksThroughLocalStore() async throws {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([
      makeStock(id: "aapl", symbol: "AAPL", shares: 10, buyPrice: 150),
      makeStock(id: "msft", symbol: "MSFT", shares: 5, buyPrice: 200)
    ])
    let localStore = MockPortfolioLocalStore()
    let viewModel = PortfolioViewModel(service: service, localStore: localStore)

    await viewModel.load()

    XCTAssertEqual(localStore.reconcileCalls, 1)
    XCTAssertEqual(localStore.lastReconciledIDs, ["aapl", "msft"])
  }

  func testSaveNewPositionPropagatesLocalStoreError() async {
    let service = MockStockService()
    service.createResult = .success(makeStock(id: "nvda", symbol: "NVDA", shares: 3, buyPrice: 120))
    let localStore = MockPortfolioLocalStore()
    localStore.upsertError = MockError("SwiftData save failed.")
    let viewModel = PortfolioViewModel(service: service, localStore: localStore)

    let message = await viewModel.saveNewPosition(
      AddPositionDraft(
        symbol: "NVDA",
        companyName: nil,
        shares: "3",
        buyPrice: "120",
        buyDate: makeDate(2026, 3, 26),
        notes: "",
        symbolLocked: false
      )
    )

    XCTAssertEqual(message, "SwiftData save failed.")
    XCTAssertEqual(viewModel.errorMessage, "SwiftData save failed.")
  }

  func testSwiftDataStoreReconcileAppliesCreateUpdateDelete() throws {
    let container = try makeInMemoryContainer()
    let context = container.mainContext
    let store = SwiftDataPortfolioLocalStore(context: context)

    context.insert(SDPortfolioStock(id: "old", symbol: "OLD", shares: 1, buyPrice: 1, buyDate: "2025-01-01"))
    context.insert(SDPortfolioStock(id: "aapl", symbol: "AAPL", shares: 1, buyPrice: 100, buyDate: "2025-01-01"))
    try context.save()

    try store.reconcile(with: [
      makeStock(id: "aapl", symbol: "AAPL", shares: 10, buyPrice: 150),
      makeStock(id: "msft", symbol: "MSFT", shares: 5, buyPrice: 200)
    ], in: nil)

    let all = try context.fetch(FetchDescriptor<SDPortfolioStock>())
    XCTAssertEqual(Set(all.map(\.id)), Set(["aapl", "msft"]))
    XCTAssertEqual(all.first(where: { $0.id == "aapl" })?.shares, 10)
    XCTAssertEqual(all.first(where: { $0.id == "msft" })?.buyPrice, 200)
  }

  func testSwiftDataStoreReconcileUsesServerAsSourceOfTruth() throws {
    let container = try makeInMemoryContainer()
    let context = container.mainContext
    let store = SwiftDataPortfolioLocalStore(context: context)

    context.insert(SDPortfolioStock(id: "aapl", symbol: "AAPL", shares: 1, buyPrice: 99, buyDate: "2025-01-01"))
    try context.save()

    try store.reconcile(with: [
      makeStock(id: "aapl", symbol: "AAPL", shares: 25, buyPrice: 175)
    ], in: nil)

    let all = try context.fetch(FetchDescriptor<SDPortfolioStock>())
    XCTAssertEqual(all.count, 1)
    XCTAssertEqual(all[0].shares, 25)
    XCTAssertEqual(all[0].buyPrice, 175)
  }

  private func makeInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
      for: SDPortfolioStock.self,
      configurations: configuration
    )
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

  private func makeSummary(
    allocation: [AllocationItem],
    cashBalance: Double? = nil
  ) -> PortfolioSummaryResponse {
    var payload: [String: Any] = [
      "baseCurrency": "USD",
      "totalValue": 10_000,
      "totalCost": 8_000,
      "unrealizedPnl": 2_000,
      "realizedPnl": 0,
      "allocation": allocation.map { item in
        [
          "symbol": item.symbol,
          "value": item.value,
          "currency": item.currency
        ]
      }
    ]

    if let cashBalance {
      payload["cashBalance"] = cashBalance
      payload["cash_balance"] = cashBalance
    }

    let data = try! JSONSerialization.data(withJSONObject: payload)
    return try! JSONDecoder.stockPlanShared.decode(
      PortfolioSummaryResponse.self,
      from: data
    )
  }
}

@MainActor
private final class MockPortfolioLocalStore: PortfolioLocalPersisting {
  var reconcileCalls = 0
  var lastReconciledIDs: [String] = []
  var lastReconciledPortfolioListId: String?
  var upsertError: Error?

  func reconcile(with remoteStocks: [StockResponse], in portfolioListId: String?) throws {
    reconcileCalls += 1
    lastReconciledIDs = remoteStocks.map(\.id)
    lastReconciledPortfolioListId = portfolioListId
  }

  func upsert(_ stock: StockResponse, in portfolioListId: String?) throws {
    if let upsertError {
      throw upsertError
    }
    _ = stock
    _ = portfolioListId
  }

  func delete(id _: String) throws {}
}

@MainActor
private final class MockStockService: StockServicing {
  var fetchPortfolioCalls = 0
  var fetchPortfolioSummaryCalls = 0
  var createCalls = 0
  var lastCreateRequest: StockRequest?
  var fetchPortfolioResult: Result<[StockResponse], Error> = .success([])
  var fetchPortfolioSummaryResult: Result<PortfolioSummaryResponse, Error> = .success(
    PortfolioSummaryResponse(
      baseCurrency: "USD",
      totalValue: 0,
      totalCost: 0,
      unrealizedPnl: 0,
      realizedPnl: 0,
      allocation: []
    )
  )
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

  func fetchPortfolio(portfolioListId _: String?) async throws -> [StockResponse] {
    try await fetchPortfolio()
  }

  func fetchPortfolioSummary() async throws -> PortfolioSummaryResponse {
    fetchPortfolioSummaryCalls += 1
    return try fetchPortfolioSummaryResult.get()
  }

  func fetchPortfolioSummary(portfolioListId _: String?) async throws -> PortfolioSummaryResponse {
    try await fetchPortfolioSummary()
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

  func sellStock(id _: String, request _: SellStockRequest) async throws -> StockResponse {
    throw MockError("Not configured.")
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

  func fetchWatchlist(watchlistListId _: String?) async throws -> [WatchlistItemResponse] {
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
