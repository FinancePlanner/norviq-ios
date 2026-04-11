import Foundation
import StockPlanShared
import SwiftData
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

  func testLoadReconcilesRemoteItemsThroughLocalStore() async {
    let service = MockStockService()
    service.fetchWatchlistResult = .success([
      makeWatchlistItem(symbol: "AAPL"),
      makeWatchlistItem(symbol: "MSFT")
    ])
    let localStore = MockWatchlistLocalStore()
    let viewModel = WatchlistViewModel(service: service, localStore: localStore)

    await viewModel.load()

    XCTAssertEqual(localStore.reconcileCalls, 1)
    XCTAssertEqual(localStore.lastReconciledCount, 2)
  }

  func testSwiftDataStoreReconcileAppliesCreateUpdateDelete() throws {
    let container = try makeInMemoryContainer()
    let context = container.mainContext
    let store = SwiftDataWatchlistLocalStore(context: context)

    context.insert(SDWatchlistItem(id: "old", symbol: "OLD", status: "active"))
    context.insert(SDWatchlistItem(id: "aapl", symbol: "AAPL", status: "active"))
    try context.save()

    try store.reconcile(with: [
      WatchlistItemResponse(id: "aapl", symbol: "AAPL", note: "updated", status: .waiting, nextReviewAt: nil),
      WatchlistItemResponse(id: "msft", symbol: "MSFT", note: nil, status: .active, nextReviewAt: nil)
    ], in: nil)

    let all = try context.fetch(FetchDescriptor<SDWatchlistItem>())
    XCTAssertEqual(Set(all.map(\.id)), Set(["aapl", "msft"]))
    XCTAssertEqual(all.first(where: { $0.id == "aapl" })?.status, WatchlistStatus.waiting.rawValue)
    XCTAssertEqual(all.first(where: { $0.id == "aapl" })?.note, "updated")
  }

  func testSaveWatchlistPropagatesLocalStoreError() async {
    let service = MockStockService()
    service.createWatchlistItemResult = .success(
      WatchlistItemResponse(id: "aapl", symbol: "AAPL", note: nil, status: .active, nextReviewAt: nil)
    )
    let localStore = MockWatchlistLocalStore()
    localStore.upsertError = MockStockError.notConfigured
    let viewModel = WatchlistViewModel(service: service, localStore: localStore)

    let error = await viewModel.saveWatchlist(AddWatchlistDraft(symbol: "AAPL", note: "", status: .active))

    XCTAssertEqual(error, "Not configured.")
  }

  private func makeInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
      for: SDWatchlistItem.self,
      configurations: configuration
    )
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

@MainActor
private final class MockWatchlistLocalStore: WatchlistLocalPersisting {
  var reconcileCalls = 0
  var lastReconciledCount = 0
  var lastReconciledListId: String?
  var upsertError: Error?

  func reconcile(with remoteItems: [WatchlistItemResponse], in watchlistListId: String?) throws {
    reconcileCalls += 1
    lastReconciledCount = remoteItems.count
    lastReconciledListId = watchlistListId
  }

  func upsert(_ item: WatchlistItemResponse, in watchlistListId: String?) throws {
    _ = item
    _ = watchlistListId
    if let upsertError {
      throw upsertError
    }
  }

  func delete(id _: String) throws {}
}

@MainActor
private final class MockStockService: StockServicing {
  var fetchWatchlistCalls = 0
  var fetchWatchlistResult: Result<[WatchlistItemResponse], Error> = .success([])
  var createWatchlistItemResult: Result<WatchlistItemResponse, Error> = .failure(MockStockError.notConfigured)

  func fetchWatchlist() async throws -> [WatchlistItemResponse] {
    fetchWatchlistCalls += 1
    return try fetchWatchlistResult.get()
  }

  func fetchWatchlist(watchlistListId _: String?) async throws -> [WatchlistItemResponse] {
    try await fetchWatchlist()
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

  func fetchPortfolio(portfolioListId _: String?) async throws -> [StockResponse] {
    throw MockStockError.notConfigured
  }

  func fetchPortfolioSummary(portfolioListId _: String?) async throws -> PortfolioSummaryResponse {
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

  func sellStock(id _: String, request _: SellStockRequest) async throws -> StockResponse {
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
    _ = request
    return try createWatchlistItemResult.get()
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
