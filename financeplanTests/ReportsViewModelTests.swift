import Foundation
import StockPlanShared
import XCTest

@testable import financeplan

@MainActor
final class ReportsViewModelTests: XCTestCase {
  func testLoadWithoutForceUsesCachedResultAfterInitialSuccess() async {
    let service = MockExpensesService()
    service.partnerResult = .success(HouseholdPartnerProfileResponse(displayName: "Ana"))
    service.reportsOverviewResult = .success(makeReportsOverview())

    let viewModel = ReportsViewModel(expensesService: service)
    await viewModel.load()
    await viewModel.load()

    XCTAssertEqual(service.getHouseholdPartnerCalls, 1)
    XCTAssertEqual(service.getReportsOverviewCalls, 1)
    XCTAssertEqual(viewModel.partnerDisplayName, "Ana")
  }

  func testLoadWithForceRefetchesAfterInitialSuccess() async {
    let service = MockExpensesService()
    service.partnerResult = .success(HouseholdPartnerProfileResponse(displayName: "Ana"))
    service.reportsOverviewResult = .success(makeReportsOverview())

    let viewModel = ReportsViewModel(expensesService: service)
    await viewModel.load()
    await viewModel.load(force: true)

    XCTAssertEqual(service.getHouseholdPartnerCalls, 2)
    XCTAssertEqual(service.getReportsOverviewCalls, 2)
  }

  func testLoadMapsAndSortsMonthSummariesNewestFirst() async {
    let service = MockExpensesService()
    service.partnerResult = .success(HouseholdPartnerProfileResponse(displayName: "Partner X"))
    service.reportsOverviewResult = .success(
      makeReportsOverview(
        monthly: [
          makeMonthSummary(monthStart: "2026-01-01", planned: 1000, actual: 950),
          makeMonthSummary(monthStart: "2026-03-01", planned: 1100, actual: 1050)
        ],
        latest: makeMonthSummary(monthStart: "2026-03-01", planned: 1100, actual: 1050)
      )
    )

    let viewModel = ReportsViewModel(expensesService: service)
    await viewModel.load()

    XCTAssertEqual(viewModel.monthlySummaries.count, 2)
    XCTAssertEqual(viewModel.monthlySummaries.first?.monthStart, makeDate(2026, 3, 1))
    XCTAssertEqual(viewModel.monthlySummaries.last?.monthStart, makeDate(2026, 1, 1))
    XCTAssertEqual(viewModel.latestMonthSummary?.monthStart, makeDate(2026, 3, 1))
    XCTAssertEqual(viewModel.partnerDisplayName, "Partner X")
  }

  func testLoadFallsBackToPortfolioWhenOverviewStatsAreZero() async {
    let service = MockExpensesService()
    service.partnerResult = .success(HouseholdPartnerProfileResponse(displayName: "Ana"))
    service.reportsOverviewResult = .success(
      ReportsOverviewResponse(
        generatedAt: "2026-04-08T00:00:00Z",
        portfolioStatistics: ImportedStocksStatisticsDTO(
          totalPositions: 0,
          totalMarketValue: 0,
          totalCostBasis: 0,
          totalUnrealizedPnl: 0,
          totalRealizedPnl: 0,
          stockSummaries: [],
          stockAllocations: [],
          sectorAllocations: [],
          calendarPerformance: []
        ),
        monthlySummaries: [],
        yearlySummaries: [],
        latestMonthSummary: nil,
        latestPillarSummaries: [],
        cashFlow: []
      )
    )

    let stockService = MockStockService()
    stockService.fetchPortfolioResult = .success([
      StockResponse(
        id: "1",
        symbol: "AAPL",
        shares: 2,
        buyPrice: 100,
        buyDate: "2026-01-01",
        notes: nil
      )
    ])

    let viewModel = ReportsViewModel(expensesService: service, stockService: stockService)
    await viewModel.load(force: true)

    XCTAssertEqual(stockService.fetchPortfolioCalls, 1)
    XCTAssertEqual(viewModel.portfolioStatistics?.totalPositions, 1)
    XCTAssertEqual(viewModel.portfolioStatistics?.totalMarketValue, 200)
    XCTAssertEqual(viewModel.portfolioStatistics?.stockAllocations.count, 1)
  }

  private func makeReportsOverview(
    monthly: [BudgetMonthSummaryResponse] = [],
    latest: BudgetMonthSummaryResponse? = nil
  ) -> ReportsOverviewResponse {
    ReportsOverviewResponse(
      generatedAt: "2026-04-08T00:00:00Z",
      portfolioStatistics: StatisticsDTO.mock.importedStocks,
      monthlySummaries: monthly,
      yearlySummaries: [],
      latestMonthSummary: latest,
      latestPillarSummaries: [],
      cashFlow: []
    )
  }

  private func makeMonthSummary(
    monthStart: String,
    planned: Double,
    actual: Double
  ) -> BudgetMonthSummaryResponse {
    BudgetMonthSummaryResponse(
      monthStart: monthStart,
      planned: planned,
      actual: actual,
      salary: 3000,
      myPlanned: planned * 0.6,
      partnerPlanned: planned * 0.4,
      myActual: actual * 0.6,
      partnerActual: actual * 0.4,
      pillarActuals: [BudgetPillar.fundamentals.rawValue: actual],
      pillarPlans: [BudgetPillar.fundamentals.rawValue: planned],
      myPillarActuals: [BudgetPillar.fundamentals.rawValue: actual * 0.6],
      partnerPillarActuals: [BudgetPillar.fundamentals.rawValue: actual * 0.4],
      myPillarPlans: [BudgetPillar.fundamentals.rawValue: planned * 0.6],
      partnerPillarPlans: [BudgetPillar.fundamentals.rawValue: planned * 0.4]
    )
  }

  private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) ?? .now
  }
}

private final class MockExpensesService: ExpensesServicing {
  var getHouseholdPartnerCalls = 0
  var getReportsOverviewCalls = 0
  var partnerResult: Result<HouseholdPartnerProfileResponse, Error> = .success(
    HouseholdPartnerProfileResponse(displayName: nil)
  )
  var reportsOverviewResult: Result<ReportsOverviewResponse, Error> = .success(
    ReportsOverviewResponse(
      generatedAt: "",
      portfolioStatistics: StatisticsDTO.mock.importedStocks,
      monthlySummaries: [],
      yearlySummaries: [],
      latestMonthSummary: nil,
      latestPillarSummaries: [],
      cashFlow: []
    )
  )

  func getHouseholdPartner() async throws -> HouseholdPartnerProfileResponse {
    getHouseholdPartnerCalls += 1
    return try partnerResult.get()
  }

  func getReportsOverview(from _: String?, to _: String?) async throws -> ReportsOverviewResponse {
    getReportsOverviewCalls += 1
    return try reportsOverviewResult.get()
  }

  func updateHouseholdPartner(
    payload _: HouseholdPartnerProfileRequest
  ) async throws -> HouseholdPartnerProfileResponse {
    throw MockExpensesError.notConfigured
  }

  func getSnapshots(year _: Int?, month _: Int?) async throws -> [BudgetSnapshotResponse] {
    throw MockExpensesError.notConfigured
  }

  func createBudgetSnapshot(request _: BudgetSnapshotRequest) async throws -> BudgetSnapshotResponse {
    throw MockExpensesError.notConfigured
  }

  func updateSnapshot(
    snapshotId _: String,
    payload _: BudgetSnapshotRequest
  ) async throws -> BudgetSnapshotResponse {
    throw MockExpensesError.notConfigured
  }

  func deleteSnapshot(snapshotId _: String) async throws {
    throw MockExpensesError.notConfigured
  }

  func getSnapshotItems(snapshotId _: String) async throws -> [BudgetPlanItemResponse] {
    throw MockExpensesError.notConfigured
  }

  func getAllPlanItems() async throws -> [BudgetPlanItemResponse] {
    throw MockExpensesError.notConfigured
  }

  func createPlanItem(payload _: BudgetPlanItemRequest) async throws -> BudgetPlanItemResponse {
    throw MockExpensesError.notConfigured
  }

  func updatePlanItem(
    itemId _: String,
    payload _: BudgetPlanItemRequest
  ) async throws -> BudgetPlanItemResponse {
    throw MockExpensesError.notConfigured
  }

  func deletePlanItem(itemId _: String) async throws {
    throw MockExpensesError.notConfigured
  }

  func getExpenses(from _: String?, to _: String?) async throws -> [ExpenseResponse] {
    throw MockExpensesError.notConfigured
  }

  func createExpense(request _: ExpenseRequest) async throws -> ExpenseResponse {
    throw MockExpensesError.notConfigured
  }

  func updateExpense(
    expenseId _: String,
    payload _: ExpenseRequest
  ) async throws -> ExpenseResponse {
    throw MockExpensesError.notConfigured
  }

  func deleteExpense(expenseId _: String) async throws {
    throw MockExpensesError.notConfigured
  }

  func getCategories() async throws -> [ExpenseCategoryResponse] {
    throw MockExpensesError.notConfigured
  }

  func createCategory(payload _: ExpenseCategoryRequest) async throws -> ExpenseCategoryResponse {
    throw MockExpensesError.notConfigured
  }

  func deleteCategory(categoryId _: String) async throws {
    throw MockExpensesError.notConfigured
  }

  func getRecurringTemplates() async throws -> [RecurringTemplateResponse] {
    throw MockExpensesError.notConfigured
  }

  func createRecurringTemplate(payload _: RecurringTemplateRequest) async throws -> RecurringTemplateResponse {
    throw MockExpensesError.notConfigured
  }

  func updateRecurringTemplate(
    templateId _: String,
    payload _: RecurringTemplateRequest
  ) async throws -> RecurringTemplateResponse {
    throw MockExpensesError.notConfigured
  }

  func deleteRecurringTemplate(templateId _: String) async throws {
    throw MockExpensesError.notConfigured
  }

  func getMonthlyExpenseReports(
    from _: String?,
    to _: String?
  ) async throws -> [BudgetMonthSummaryResponse] {
    throw MockExpensesError.notConfigured
  }

  func getYearlyExpenseReports(
    from _: String?,
    to _: String?
  ) async throws -> [BudgetYearSummaryResponse] {
    throw MockExpensesError.notConfigured
  }

  func getReportSuggestions(
    from _: String?,
    to _: String?
  ) async throws -> StockPlanShared.ReportSuggestionsResponse {
    throw MockExpensesError.notConfigured
  }

  func dismissReportSuggestion(id _: String) async throws {
    throw MockExpensesError.notConfigured
  }
}

private enum MockExpensesError: LocalizedError {
  case notConfigured

  var errorDescription: String? {
    "Not configured."
  }
}

@MainActor
private final class MockStockService: StockServicing {
  var fetchPortfolioCalls = 0
  var fetchPortfolioResult: Result<[StockResponse], Error> = .success([])

  @discardableResult
  func create(stock _: StockRequest) async throws -> StockResponse { throw MockExpensesError.notConfigured }
  @discardableResult
  func create(stock: StockRequest, portfolioListId _: String?) async throws -> StockResponse {
    try await create(stock: stock)
  }

  @discardableResult
  func bulkCreate(stocks _: [StockRequest]) async throws -> BulkStockResponse { throw MockExpensesError.notConfigured }

  func fetchPortfolio() async throws -> [StockResponse] {
    fetchPortfolioCalls += 1
    return try fetchPortfolioResult.get()
  }
  func fetchPortfolio(portfolioListId _: String?) async throws -> [StockResponse] { try await fetchPortfolio() }

  func fetchStockDetails(stockId _: String) async throws -> StockDetails { throw MockExpensesError.notConfigured }
  func fetchStockInsights(symbol _: String) async throws -> StockInsightsResponse { throw MockExpensesError.notConfigured }
  func fetchPortfolioPerformance(portfolioListId _: String?) async throws -> PortfolioPerformanceResponse { throw MockExpensesError.notConfigured }
  func fetchPortfolioPerformance() async throws -> PortfolioPerformanceResponse { throw MockExpensesError.notConfigured }
  func fetchPortfolioSummary(portfolioListId _: String?) async throws -> PortfolioSummaryResponse { throw MockExpensesError.notConfigured }
  func fetchPortfolioSummary() async throws -> PortfolioSummaryResponse { throw MockExpensesError.notConfigured }
  func fetchStockHistory(symbol _: String) async throws -> [StockHistory] { throw MockExpensesError.notConfigured }
  func fetchStockNews(symbol _: String) async throws -> [StockNews] { throw MockExpensesError.notConfigured }
  func updateStock(_ stock: StockResponse, portfolioListId _: String?) async throws -> StockResponse { try await updateStock(stock) }
  func updateStock(_: StockResponse) async throws -> StockResponse { throw MockExpensesError.notConfigured }
  func delete(id _: String) async throws { throw MockExpensesError.notConfigured }
  func getValuation(symbol _: String) async throws -> StockValuationRequest { throw MockExpensesError.notConfigured }
  func createValuation(symbol _: String, draft _: StockValuationDraft) async throws -> StockValuationRequest { throw MockExpensesError.notConfigured }
  func createValuation(symbol _: String, bearLow _: Double, bearHigh _: Double, baseLow _: Double, baseHigh _: Double, bullLow _: Double, bullHigh _: Double, rationale _: String?, targetDate _: String?) async throws -> StockValuationRequest { throw MockExpensesError.notConfigured }
  func updateValuation(symbol _: String, draft _: StockValuationDraft) async throws -> StockValuationRequest { throw MockExpensesError.notConfigured }
  func updateValuation(symbol _: String, bearLow _: Double, bearHigh _: Double, baseLow _: Double, baseHigh _: Double, bullLow _: Double, bullHigh _: Double, rationale _: String?, targetDate _: String?) async throws -> StockValuationRequest { throw MockExpensesError.notConfigured }
  func fetchWatchlist() async throws -> [WatchlistItemResponse] { throw MockExpensesError.notConfigured }
  func fetchWatchlist(watchlistListId _: String?) async throws -> [WatchlistItemResponse] { throw MockExpensesError.notConfigured }
  @discardableResult
  func createWatchlistItem(_: WatchlistItemRequest) async throws -> WatchlistItemResponse { throw MockExpensesError.notConfigured }
  @discardableResult
  func createWatchlistItem(_: WatchlistItemRequest, watchlistListId _: String?) async throws -> WatchlistItemResponse {
    throw MockExpensesError.notConfigured
  }
  @discardableResult
  func updateWatchlistItem(id _: String, request _: WatchlistItemUpdateRequest) async throws -> WatchlistItemResponse { throw MockExpensesError.notConfigured }
  @discardableResult
  func updateWatchlistItem(
    id _: String,
    request _: WatchlistItemUpdateRequest,
    watchlistListId _: String?
  ) async throws -> WatchlistItemResponse { throw MockExpensesError.notConfigured }
  func deleteWatchlistItem(id _: String) async throws { throw MockExpensesError.notConfigured }
  func sellStock(id _: String, request _: SellStockRequest) async throws -> StockResponse { throw MockExpensesError.notConfigured }
}
