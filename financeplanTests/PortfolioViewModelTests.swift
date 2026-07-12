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

    let viewModel = PortfolioViewModel(service: service, marketDataService: MarketDataServiceStub())
    await viewModel.load()

    XCTAssertEqual(service.fetchPortfolioCalls, 1)
    XCTAssertEqual(service.fetchPortfolioSummaryCalls, 1)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoadSucceedsWhenTargetAlertsFail() async {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([
      makeStock(id: "aapl", symbol: "AAPL", shares: 10, buyPrice: 150)
    ])
    service.fetchTargetsResult = .failure(MockError("Upgrade required."))

    let viewModel = PortfolioViewModel(service: service, marketDataService: MarketDataServiceStub())
    await viewModel.load()

    XCTAssertEqual(service.fetchPortfolioCalls, 1)
    XCTAssertEqual(service.fetchPortfolioSummaryCalls, 1)
    XCTAssertEqual(service.fetchTargetsCalls, 1)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.targetAlertsBySymbol.isEmpty)
  }

  func testLoadWithoutForceUsesCachedResultAfterFirstSuccess() async {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([
      makeStock(id: "aapl", symbol: "AAPL", shares: 10, buyPrice: 150)
    ])

    let viewModel = PortfolioViewModel(service: service, marketDataService: MarketDataServiceStub())
    await viewModel.load()
    await viewModel.load()

    XCTAssertEqual(service.fetchPortfolioCalls, 1)
  }

  func testLoadWithForceRefetchesAfterInitialSuccess() async {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([
      makeStock(id: "aapl", symbol: "AAPL", shares: 10, buyPrice: 150)
    ])

    let viewModel = PortfolioViewModel(service: service, marketDataService: MarketDataServiceStub())
    await viewModel.load()
    await viewModel.load(force: true)

    XCTAssertEqual(service.fetchPortfolioCalls, 2)
    XCTAssertEqual(service.fetchPortfolioSummaryCalls, 2)
  }

  func testRefreshLiveQuotesUsesQuoteBatchWithoutReloadingPortfolioData() async {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([
      makeStock(id: "aapl", symbol: "AAPL", shares: 10, buyPrice: 150),
      makeStock(id: "msft", symbol: "MSFT", shares: 5, buyPrice: 200)
    ])
    let marketDataService = PortfolioQuoteMarketDataServiceMock()
    marketDataService.fetchQuoteBatchResult = .success(
      QuoteBatchResponse(quotes: [
        makeQuote(symbol: "AAPL", currentPrice: 171),
        makeQuote(symbol: "MSFT", currentPrice: 311)
      ])
    )
    let viewModel = PortfolioViewModel(service: service, marketDataService: marketDataService)

    await viewModel.load()

    let portfolioCallsAfterLoad = service.fetchPortfolioCalls
    let summaryCallsAfterLoad = service.fetchPortfolioSummaryCalls
    let targetsCallsAfterLoad = service.fetchTargetsCalls
    marketDataService.fetchQuoteBatchResult = .success(
      QuoteBatchResponse(quotes: [
        makeQuote(symbol: "AAPL", currentPrice: 172.5),
        makeQuote(symbol: "MSFT", currentPrice: 314.2)
      ])
    )

    await viewModel.refreshLiveQuotes()

    XCTAssertEqual(marketDataService.fetchQuoteBatchCalls, 2)
    XCTAssertEqual(Set(marketDataService.requestedSymbolBatches.last ?? []), Set(["AAPL", "MSFT"]))
    XCTAssertEqual(service.fetchPortfolioCalls, portfolioCallsAfterLoad)
    XCTAssertEqual(service.fetchPortfolioSummaryCalls, summaryCallsAfterLoad)
    XCTAssertEqual(service.fetchTargetsCalls, targetsCallsAfterLoad)
    XCTAssertEqual(viewModel.liveQuotes["AAPL"]?.currentPrice, 172.5)
    XCTAssertEqual(viewModel.liveQuotes["MSFT"]?.currentPrice, 314.2)
  }

  func testRefreshLiveQuotesFailurePreservesExistingQuotesAndErrorState() async {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([
      makeStock(id: "aapl", symbol: "AAPL", shares: 10, buyPrice: 150)
    ])
    let marketDataService = PortfolioQuoteMarketDataServiceMock()
    marketDataService.fetchQuoteBatchResult = .success(
      QuoteBatchResponse(quotes: [
        makeQuote(symbol: "AAPL", currentPrice: 171)
      ])
    )
    let viewModel = PortfolioViewModel(service: service, marketDataService: marketDataService)

    await viewModel.load()
    marketDataService.fetchQuoteBatchResult = .failure(MockError("Quote refresh failed."))

    await viewModel.refreshLiveQuotes()

    XCTAssertEqual(marketDataService.fetchQuoteBatchCalls, 2)
    XCTAssertEqual(viewModel.liveQuotes["AAPL"]?.currentPrice, 171)
    XCTAssertNil(viewModel.errorMessage)
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

    let viewModel = PortfolioViewModel(service: service, marketDataService: MarketDataServiceStub())
    await viewModel.load()

    XCTAssertEqual(viewModel.cashBalance, 275.4, accuracy: 0.001)
    XCTAssertEqual(service.fetchPortfolioSummaryCalls, 1)
  }

  func testLoadStoresSectorExposure() async {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([makeStock(id: "aapl", symbol: "AAPL", shares: 1, buyPrice: 100)])
    service.fetchPortfolioSectorExposureResult = .success(
      PortfolioSectorExposureResponse(
        baseCurrency: "USD",
        totalValue: 100,
        investedValue: 100,
        cashBalance: 0,
        benchmarkName: "S&P 500",
        benchmarkAsOf: "2026-05-29",
        sectors: [
          PortfolioSectorExposureItem(
            sector: "Information Technology",
            value: 100,
            weightPercent: 100,
            benchmarkWeightPercent: 38.6,
            overweightPercent: 61.4,
            holdings: [
              PortfolioSectorHoldingContribution(symbol: "AAPL", value: 100, weightPercent: 100)
            ]
          )
        ]
      )
    )

    let viewModel = PortfolioViewModel(service: service)
    await viewModel.load()

    XCTAssertEqual(service.fetchPortfolioSectorExposureCalls, 1)
    XCTAssertEqual(viewModel.sectorExposure?.sectors.first?.sector, "Information Technology")
    XCTAssertEqual(viewModel.sectorExposure?.sectors.first?.overweightPercent, 61.4)
  }

  func testLoadWithNoCashAllocationSetsCashBalanceToZero() async {
    let service = MockStockService()
    service.fetchPortfolioResult = .success([makeStock(id: "aapl", symbol: "AAPL", shares: 1, buyPrice: 100)])
    service.fetchPortfolioSummaryResult = .success(
      makeSummary(allocation: [
        AllocationItem(symbol: "AAPL", value: 100, currency: "USD")
      ])
    )

    let viewModel = PortfolioViewModel(service: service, marketDataService: MarketDataServiceStub())
    await viewModel.load()

    XCTAssertEqual(viewModel.cashBalance, 0, accuracy: 0.001)
  }

  func testDeleteFailurePublishesError() async {
    let service = MockStockService()
    service.deleteResult = .failure(MockError("Delete failed."))

    let viewModel = PortfolioViewModel(service: service, marketDataService: MarketDataServiceStub())
    let ok = await viewModel.delete(id: "aapl")

    XCTAssertFalse(ok)
    XCTAssertEqual(viewModel.errorMessage, "Delete failed.")
    XCTAssertFalse(viewModel.isDeletingStock)
  }

  func testSaveNewPositionCreatesAndInsertsStock() async {
    let service = MockStockService()
    let created = makeStock(id: "nvda", symbol: "NVDA", shares: 3, buyPrice: 120)
    service.createResult = .success(created)

    let viewModel = PortfolioViewModel(service: service, marketDataService: MarketDataServiceStub())
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
    let viewModel = PortfolioViewModel(service: service, marketDataService: MarketDataServiceStub())

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
    let viewModel = PortfolioViewModel(service: service, marketDataService: MarketDataServiceStub(), localStore: localStore)

    await viewModel.load()

    XCTAssertEqual(localStore.reconcileCalls, 1)
    XCTAssertEqual(localStore.lastReconciledIDs, ["aapl", "msft"])
  }

  func testSaveNewPositionPropagatesLocalStoreError() async {
    let service = MockStockService()
    service.createResult = .success(makeStock(id: "nvda", symbol: "NVDA", shares: 3, buyPrice: 120))
    let localStore = MockPortfolioLocalStore()
    localStore.upsertError = MockError("SwiftData save failed.")
    let viewModel = PortfolioViewModel(service: service, marketDataService: MarketDataServiceStub(), localStore: localStore)

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
    let store = SwiftDataPortfolioLocalStore(context: context, ownerUserId: "user-1")

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
    let store = SwiftDataPortfolioLocalStore(context: context, ownerUserId: "user-1")

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

  func testSwiftDataStoreReconcileDoesNotDeleteOtherUsersRows() throws {
    let container = try makeInMemoryContainer()
    let context = container.mainContext
    let store = SwiftDataPortfolioLocalStore(context: context, ownerUserId: "user-1")

    context.insert(
      SDPortfolioStock(
        id: "other-aapl",
        ownerUserId: "user-2",
        symbol: "AAPL",
        shares: 99,
        buyPrice: 50,
        buyDate: "2025-01-01"
      )
    )
    try context.save()

    try store.reconcile(with: [], in: nil)

    let all = try context.fetch(FetchDescriptor<SDPortfolioStock>())
    XCTAssertEqual(all.count, 1)
    XCTAssertEqual(all[0].ownerUserId, "user-2")
    XCTAssertEqual(all[0].id, "other-aapl")
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
      notes: nil,
      createdAt: "2026-03-26T00:00:00Z"
    )
  }

  private func makeQuote(symbol: String, currentPrice: Double) -> QuoteResponse {
    QuoteResponse(
      symbol: symbol,
      currency: "USD",
      currentPrice: currentPrice,
      change: 1.25,
      percentChange: 0.73,
      high: currentPrice + 2,
      low: currentPrice - 2,
      open: currentPrice - 1,
      previousClose: currentPrice - 1.25,
      timestamp: 1_775_073_600
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

extension MarketDataServicing {
  func fetchCompanyProfile(symbol _: String) async throws -> CompanyProfileResponse {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchQuote(symbol _: String) async throws -> QuoteResponse {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchQuoteBatch(symbols _: [String]) async throws -> QuoteBatchResponse {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchAnalystConsensus(symbol _: String) async throws -> StockAnalystConsensus {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchBasicFinancials(symbol _: String) async throws -> StockBasicFinancials {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchAnalysisMetrics(
    symbol _: String,
    wacc _: Double?,
    terminalGrowthRate _: Double?,
    terminalMargin _: Double?,
    fcfMarginAssumption _: Double?
  ) async throws -> StockAnalysisMetrics {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchMarketCompare(symbols _: [String]) async throws -> [StockAnalysisMetrics] {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchBalanceSheetStatement(symbol _: String, limit _: Int?, period _: String?) async throws -> [BalanceSheetStatementResponse] {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchCashFlowStatement(symbol _: String, limit _: Int?, period _: String?) async throws -> [CashFlowStatementResponse] {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchIncomeStatement(symbol _: String, limit _: Int?, period _: String?) async throws -> [IncomeStatementResponse] {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchRatios(symbol _: String, limit _: Int?, period _: String?) async throws -> [RatiosResponse] {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchRatiosTTM(symbol _: String) async throws -> [RatiosTTMResponse] {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchFinancialGrowth(symbol _: String, limit _: Int?, period _: String?) async throws -> [FinancialGrowthResponse] {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchAnalystEstimates(symbol _: String, limit _: Int?, period _: String?) async throws -> [AnalystEstimatesResponse] {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchStockEarnings(symbol _: String, limit _: Int) async throws -> [EarningsEvent] {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchStockEarningsTranscript(symbol _: String, date _: String) async throws -> EarningsTranscript {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchEarningsCalendar(from _: String, to _: String) async throws -> [EarningsEvent] {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchMarketNews(limit _: Int?) async throws -> [StockNews] {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchFinancialStatements(symbol _: String) async throws -> StockFinancialStatements {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchPriceChart(symbol _: String, range _: String) async throws -> financeplan.PriceChartSeries {
    throw QuoteMarketDataMockError.notConfigured
  }

  func fetchPriceChartComparison(symbols _: [String], range _: String) async throws -> financeplan.PriceChartComparisonResponse {
    throw QuoteMarketDataMockError.notConfigured
  }
}

enum QuoteMarketDataMockError: LocalizedError {
  case notConfigured

  var errorDescription: String? {
    "Not configured."
  }
}

@MainActor
private final class PortfolioQuoteMarketDataServiceMock: MarketDataServicing, @unchecked Sendable {
  var fetchQuoteBatchCalls = 0
  var requestedSymbolBatches: [[String]] = []
  var fetchQuoteBatchResult: Result<QuoteBatchResponse, Error> = .failure(QuoteMarketDataMockError.notConfigured)

  func fetchQuoteBatch(symbols: [String]) async throws -> QuoteBatchResponse {
    fetchQuoteBatchCalls += 1
    requestedSymbolBatches.append(symbols)
    return try fetchQuoteBatchResult.get()
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
  var fetchPortfolioSectorExposureCalls = 0

  var createCalls = 0
  var lastCreateRequest: StockRequest?
  var lastCreatePortfolioListId: String?
  var fetchPortfolioResult: Result<[StockResponse], Error> = .success([])
  var fetchPortfolioListsResult: Result<[PortfolioListDTOResponse], Error> = .success([
    PortfolioListDTOResponse(id: "default-list", name: "Default", isDefault: true, createdAt: nil, updatedAt: nil)
  ])
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
  var fetchPortfolioSectorExposureResult: Result<PortfolioSectorExposureResponse, Error> = .success(
    PortfolioSectorExposureResponse(
      baseCurrency: "USD",
      totalValue: 0,
      investedValue: 0,
      cashBalance: 0,
      benchmarkName: "S&P 500",
      benchmarkAsOf: "2026-05-29",
      sectors: []
    )
  )
  var fetchTargetsResult: Result<[TargetResponse], Error> = .success([])
  var createResult: Result<StockResponse, Error> = .failure(MockError("Not configured."))
  var updateResult: Result<StockResponse, Error> = .failure(MockError("Not configured."))
  var deleteResult: Result<Void, Error> = .success(())

  func create(stock: StockRequest, portfolioListId: String?) async throws -> StockResponse {
    createCalls += 1
    lastCreateRequest = stock
    lastCreatePortfolioListId = portfolioListId
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

  func fetchPortfolio(portfolioListId _: String?, cursor _: String?, limit _: Int?) async throws -> (items: [StockResponse], nextCursor: String?) {

    fetchPortfolioCalls += 1
    return (try fetchPortfolioResult.get(), nil)
  }

  func fetchPortfolioSummary() async throws -> PortfolioSummaryResponse {
    fetchPortfolioSummaryCalls += 1
    return try fetchPortfolioSummaryResult.get()
  }

  func fetchPortfolioSummary(portfolioListId _: String?) async throws -> PortfolioSummaryResponse {
    try await fetchPortfolioSummary()
  }

  func fetchPortfolioSectorExposure(portfolioListId _: String?) async throws -> PortfolioSectorExposureResponse {
    fetchPortfolioSectorExposureCalls += 1
    return try fetchPortfolioSectorExposureResult.get()
  }

  func fetchTargets(symbol _: String?) async throws -> [TargetResponse] {
    fetchTargetsCalls += 1
    return try fetchTargetsResult.get()
  }

  func fetchPortfolioPerformance(portfolioListId _: String?) async throws -> PortfolioPerformanceResponse {
    throw MockError("Not configured.")
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

  func updateStock(_ stock: StockResponse, portfolioListId _: String?) async throws -> StockResponse {
    _ = stock
    return try updateResult.get()
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

  func createWatchlistItem(
    _ request: WatchlistItemRequest,
    watchlistListId _: String?
  ) async throws -> WatchlistItemResponse {
    try await createWatchlistItem(request)
  }

  func updateWatchlistItem(
    id _: String,
    request _: WatchlistItemUpdateRequest
  ) async throws -> WatchlistItemResponse {
    throw MockError("Not configured.")
  }

  func updateWatchlistItem(
    id: String,
    request: WatchlistItemUpdateRequest,
    watchlistListId _: String?
  ) async throws -> WatchlistItemResponse {
    try await updateWatchlistItem(id: id, request: request)
  }

  func deleteWatchlistItem(id _: String) async throws {
    throw MockError("Not configured.")
  }

  func fetchPortfolioLists() async throws -> [PortfolioListDTOResponse] {
    try fetchPortfolioListsResult.get()
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
