import Foundation
import StockPlanShared
import SwiftData
import XCTest

@testable import financeplan

@MainActor
final class WatchlistViewModelTests: XCTestCase {
  func testLoadWithoutForceUsesCachedResultAfterInitialSuccess() async {
    let service = WatchlistViewModelMockStockService()
    service.fetchWatchlistResult = .success([makeWatchlistItem(symbol: "AAPL")])
    let viewModel = WatchlistViewModel(service: service, marketDataService: MarketDataServiceStub())

    await viewModel.load()
    await viewModel.load()

    XCTAssertEqual(service.fetchWatchlistCalls, 1)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoadWithForceRefetchesAfterInitialSuccess() async {
    let service = WatchlistViewModelMockStockService()
    service.fetchWatchlistResult = .success([makeWatchlistItem(symbol: "AAPL")])
    let viewModel = WatchlistViewModel(service: service, marketDataService: MarketDataServiceStub())

    await viewModel.load()
    await viewModel.load(force: true)

    XCTAssertEqual(service.fetchWatchlistCalls, 2)
  }

  func testLoadReconcilesRemoteItemsThroughLocalStore() async {
    let service = WatchlistViewModelMockStockService()
    service.fetchWatchlistResult = .success([
      makeWatchlistItem(symbol: "AAPL"),
      makeWatchlistItem(symbol: "MSFT")
    ])
    let localStore = MockWatchlistLocalStore()
    let viewModel = WatchlistViewModel(service: service, marketDataService: MarketDataServiceStub(), localStore: localStore)

    await viewModel.load()

    XCTAssertEqual(localStore.reconcileCalls, 1)
    XCTAssertEqual(localStore.lastReconciledCount, 2)
  }

  func testLoadUsesSelectedListWhenLoadingRemoteRows() async {
    let service = WatchlistViewModelMockStockService()
    service.fetchWatchlistListsResult = .success([
      .init(id: "tech", name: "Tech", isDefault: false, createdAt: nil, updatedAt: nil),
      .init(id: "energy", name: "Energy", isDefault: false, createdAt: nil, updatedAt: nil)
    ])
    service.fetchWatchlistResult = .success([makeWatchlistItem(symbol: "AAPL")])
    let localStore = MockWatchlistLocalStore()
    let viewModel = WatchlistViewModel(service: service, marketDataService: MarketDataServiceStub(), localStore: localStore)

    await viewModel.load()

    XCTAssertEqual(service.fetchWatchlistCallsByListID, ["tech"])
    XCTAssertEqual(viewModel.selectedWatchlistListId, "tech")
    XCTAssertEqual(localStore.lastReconciledListId, "tech")
  }

  func testSelectWatchlistListRefreshesNewList() async {
    let service = WatchlistViewModelMockStockService()
    service.fetchWatchlistListsResult = .success([
      .init(id: "tech", name: "Tech", isDefault: true, createdAt: nil, updatedAt: nil),
      .init(id: "energy", name: "Energy", isDefault: false, createdAt: nil, updatedAt: nil)
    ])
    service.fetchWatchlistResult = .success([makeWatchlistItem(symbol: "AAPL")])
    let viewModel = WatchlistViewModel(service: service, marketDataService: MarketDataServiceStub())

    await viewModel.load()
    await viewModel.selectWatchlistList("energy")

    XCTAssertEqual(viewModel.selectedWatchlistListId, "energy")
    XCTAssertEqual(service.fetchWatchlistCallsByListID, ["tech", "energy"])
  }

  func testSwiftDataStoreReconcileAppliesCreateUpdateDelete() throws {
    let container = try makeInMemoryContainer()
    let context = container.mainContext
    let store = SwiftDataWatchlistLocalStore(context: context, ownerUserId: "user-1")

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

  func testSwiftDataWatchlistItemMappingPreservesRemoteListId() {
    let response = WatchlistItemResponse(
      id: "aapl",
      symbol: "AAPL",
      note: "core",
      status: .active,
      nextReviewAt: nil,
      watchlistListId: "tech-list"
    )

    let item = SDWatchlistItem(from: response)

    XCTAssertEqual(item.watchlistListId, "tech-list")

    item.update(
      from: WatchlistItemResponse(
        id: "aapl",
        symbol: "AAPL",
        note: "updated",
        status: .waiting,
        nextReviewAt: nil,
        watchlistListId: "energy-list"
      )
    )

    XCTAssertEqual(item.watchlistListId, "energy-list")
  }

  func testSwiftDataStoreReconcileDoesNotDeleteOtherUsersRows() throws {
    let container = try makeInMemoryContainer()
    let context = container.mainContext
    let store = SwiftDataWatchlistLocalStore(context: context, ownerUserId: "user-1")

    context.insert(
      SDWatchlistItem(
        id: "other-aapl",
        ownerUserId: "user-2",
        symbol: "AAPL",
        note: "other user",
        status: WatchlistStatus.active.rawValue
      )
    )
    try context.save()

    try store.reconcile(with: [], in: nil)

    let all = try context.fetch(FetchDescriptor<SDWatchlistItem>())
    XCTAssertEqual(all.count, 1)
    XCTAssertEqual(all[0].ownerUserId, "user-2")
    XCTAssertEqual(all[0].id, "other-aapl")
  }

  func testSaveWatchlistPropagatesLocalStoreError() async {
    let service = WatchlistViewModelMockStockService()
    service.createWatchlistItemResult = .success(
      WatchlistItemResponse(id: "aapl", symbol: "AAPL", note: nil, status: .active, nextReviewAt: nil)
    )
    let localStore = MockWatchlistLocalStore()
    localStore.upsertError = MockStockError.notConfigured
    let viewModel = WatchlistViewModel(service: service, marketDataService: MarketDataServiceStub(), localStore: localStore)

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
final class WatchlistViewModelMockStockService: StockServicing {
  var fetchWatchlistCalls = 0
  var fetchWatchlistCallsByListID: [String?] = []
  var fetchWatchlistResult: Result<[WatchlistItemResponse], Error> = .success([])
  var fetchWatchlistListsResult: Result<[WatchlistListDTOResponse], Error> = .success([
    WatchlistListDTOResponse(id: "default-watchlist", name: "Default", isDefault: true, createdAt: nil, updatedAt: nil)
  ])
  var createWatchlistItemResult: Result<WatchlistItemResponse, Error> = .failure(MockStockError.notConfigured)
  var previewWatchlistCsvImportResult: Result<WatchlistCsvImportPreviewResponse, Error> = .success(
    WatchlistCsvImportPreviewResponse(watchlistListId: "default-watchlist", items: [], errors: [])
  )
  var commitWatchlistCsvImportResult: Result<WatchlistCsvImportCommitResponse, Error> = .success(
    WatchlistCsvImportCommitResponse(watchlistListId: "default-watchlist", inserted: [], updated: [], errors: [])
  )
  var previewWatchlistCsvImportCalls = 0
  var commitWatchlistCsvImportCalls = 0
  var lastPreviewWatchlistListId: String?
  var lastCommitWatchlistListId: String?
  var lastPreviewCsvData: Data?
  var lastCommitCsvData: Data?

  func fetchWatchlist() async throws -> [WatchlistItemResponse] {
    return try await fetchWatchlist(watchlistListId: nil)
  }

  func fetchWatchlist(watchlistListId: String?) async throws -> [WatchlistItemResponse] {
    fetchWatchlistCalls += 1
    fetchWatchlistCallsByListID.append(watchlistListId)
    return try fetchWatchlistResult.get()
  }

  func previewWatchlistCsvImport(
    watchlistListId: String?,
    csvData: Data
  ) async throws -> WatchlistCsvImportPreviewResponse {
    previewWatchlistCsvImportCalls += 1
    lastPreviewWatchlistListId = watchlistListId
    lastPreviewCsvData = csvData
    return try previewWatchlistCsvImportResult.get()
  }

  func commitWatchlistCsvImport(
    watchlistListId: String?,
    csvData: Data
  ) async throws -> WatchlistCsvImportCommitResponse {
    commitWatchlistCsvImportCalls += 1
    lastCommitWatchlistListId = watchlistListId
    lastCommitCsvData = csvData
    return try commitWatchlistCsvImportResult.get()
  }

  func create(stock _: StockRequest, portfolioListId _: String?) async throws -> StockResponse {
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

  func fetchPortfolioPerformance(portfolioListId _: String?) async throws -> PortfolioPerformanceResponse {
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

  func updateStock(_ stock: StockResponse, portfolioListId _: String?) async throws -> StockResponse {
    try await updateStock(stock)
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

  func createWatchlistItem(
    _ request: WatchlistItemRequest,
    watchlistListId _: String?
  ) async throws -> WatchlistItemResponse {
    _ = request
    return try createWatchlistItemResult.get()
  }

  func updateWatchlistItem(
    id _: String,
    request _: WatchlistItemUpdateRequest,
    watchlistListId _: String?
  ) async throws -> WatchlistItemResponse {
    throw MockStockError.notConfigured
  }

  func deleteWatchlistItem(id _: String) async throws {
    throw MockStockError.notConfigured
  }

  func fetchWatchlistLists() async throws -> [WatchlistListDTOResponse] {
    try fetchWatchlistListsResult.get()
  }
}

private enum MockStockError: LocalizedError {
  case notConfigured

  var errorDescription: String? {
    "Not configured."
  }
}
