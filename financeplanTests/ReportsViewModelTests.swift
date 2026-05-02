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

  func testLoadKeepsBackendPortfolioStatsWhenOverviewStatsAreZero() async {
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

    let viewModel = ReportsViewModel(expensesService: service)
    await viewModel.load(force: true)

    XCTAssertEqual(viewModel.portfolioStatistics?.totalPositions, 0)
    XCTAssertEqual(viewModel.portfolioStatistics?.totalMarketValue, 0)
    XCTAssertTrue(viewModel.monthlySummaries.isEmpty)
    XCTAssertNil(viewModel.latestMonthSummary)
  }

  func testLoadFailurePublishesErrorAndKeepsCollectionsEmpty() async {
    let service = MockExpensesService()
    service.partnerResult = .success(HouseholdPartnerProfileResponse(displayName: "Ana"))
    service.reportsOverviewResult = .failure(MockExpensesError.notConfigured)

    let viewModel = ReportsViewModel(expensesService: service)
    await viewModel.load(force: true)

    XCTAssertEqual(viewModel.errorMessage, "Not configured.")
    XCTAssertTrue(viewModel.monthlySummaries.isEmpty)
    XCTAssertTrue(viewModel.yearlySummaries.isEmpty)
    XCTAssertTrue(viewModel.cashFlow.isEmpty)
    XCTAssertNil(viewModel.latestMonthSummary)
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

  func getExpenses(from _: String?, to _: String?, cursor _: String? = nil, limit _: Int? = nil) async throws -> (items: [ExpenseResponse], nextCursor: String?) {
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
