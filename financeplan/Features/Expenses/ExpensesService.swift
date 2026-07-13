import Foundation
import StockPlanShared
import Factory

@MainActor
protocol ExpenseBudgetSetupServicing: Sendable {
    func createBudgetSnapshot(request: BudgetSnapshotRequest) async throws -> BudgetSnapshotResponse
    func createExpense(request: ExpenseRequest) async throws -> ExpenseResponse
}

@MainActor
protocol ExpensesServicing: ExpenseBudgetSetupServicing, Sendable {
    func getHouseholdPartner() async throws -> HouseholdPartnerProfileResponse
    func updateHouseholdPartner(payload: HouseholdPartnerProfileRequest) async throws -> HouseholdPartnerProfileResponse

    // Snapshots
    func getSnapshots(year: Int?, month: Int?) async throws -> [BudgetSnapshotResponse]
    func updateSnapshot(snapshotId: String, payload: BudgetSnapshotRequest) async throws -> BudgetSnapshotResponse
    func deleteSnapshot(snapshotId: String) async throws
    func getSnapshotItems(snapshotId: String) async throws -> [BudgetPlanItemResponse]

    // Items
    func getAllPlanItems() async throws -> [BudgetPlanItemResponse]
    func createPlanItem(payload: BudgetPlanItemRequest) async throws -> BudgetPlanItemResponse
    func updatePlanItem(itemId: String, payload: BudgetPlanItemRequest) async throws -> BudgetPlanItemResponse
    func deletePlanItem(itemId: String) async throws

    // Expenses
    func getExpenses(from: String?, to: String?, cursor: String?, limit: Int?) async throws -> (items: [ExpenseResponse], nextCursor: String?)
    func updateExpense(expenseId: String, payload: ExpenseRequest) async throws -> ExpenseResponse
    func deleteExpense(expenseId: String) async throws

    // Categories
    func getCategories() async throws -> [ExpenseCategoryResponse]
    func createCategory(payload: ExpenseCategoryRequest) async throws -> ExpenseCategoryResponse
    func deleteCategory(categoryId: String) async throws

    // Recurring Templates
    func getRecurringTemplates() async throws -> [RecurringTemplateResponse]
    func createRecurringTemplate(payload: RecurringTemplateRequest) async throws -> RecurringTemplateResponse
    func updateRecurringTemplate(templateId: String, payload: RecurringTemplateRequest) async throws -> RecurringTemplateResponse
    func deleteRecurringTemplate(templateId: String) async throws

    // Financing planner
    func simulateFinancing(payload: FinancingSimulationRequest) async throws -> FinancingSimulationResponse
    func getFinancingPlans() async throws -> [FinancingPlanResponse]
    func createFinancingPlan(payload: FinancingPlanRequest) async throws -> FinancingPlanResponse
    func getFinancingProjections(from: String?, to: String?) async throws -> [FinancingProjectionResponse]

    // Reports
    func getReportsOverview(from: String?, to: String?) async throws -> ReportsOverviewResponse
    func getMonthlyExpenseReports(from: String?, to: String?) async throws -> [BudgetMonthSummaryResponse]
    func getYearlyExpenseReports(from: String?, to: String?) async throws -> [BudgetYearSummaryResponse]
    func getReportSuggestions(from: String?, to: String?) async throws -> ReportSuggestionsResponse
    func dismissReportSuggestion(id: String) async throws
}

// MARK: - Convenience overloads (default parameters)
extension ExpensesServicing {
    func getExpenses() async throws -> (items: [ExpenseResponse], nextCursor: String?) {
        try await getExpenses(from: nil, to: nil, cursor: nil, limit: nil)
    }

    func getExpenses(from: String? = nil, to: String? = nil) async throws -> (items: [ExpenseResponse], nextCursor: String?) {
        try await getExpenses(from: from, to: to, cursor: nil, limit: nil)
    }
}

struct ExpensesHTTPService: ExpensesServicing {
    let client: ExpensesHTTPClient

    init(environmentManager: AppEnvironmentManager, authSessionManager: any AuthSessionManaging) {
        let env = environmentManager.current
        self.client = ExpensesHTTPClient(
            baseURL: env.apiBaseUrl,
            session: URLSession.shared,
            authTokenProvider: { await Container.shared.authSessionStore().authToken }
        )
    }

    func getHouseholdPartner() async throws -> HouseholdPartnerProfileResponse {
        try await client.getHouseholdPartner()
    }

    func updateHouseholdPartner(payload: HouseholdPartnerProfileRequest) async throws -> HouseholdPartnerProfileResponse {
        try await client.updateHouseholdPartner(payload: payload)
    }

    func getSnapshots(year: Int? = nil, month: Int? = nil) async throws -> [BudgetSnapshotResponse] {
        try await client.getSnapshots(year: year, month: month)
    }

    func createBudgetSnapshot(request: BudgetSnapshotRequest) async throws -> BudgetSnapshotResponse {
        try await client.createBudgetSnapshot(request: request)
    }

    func updateSnapshot(snapshotId: String, payload: BudgetSnapshotRequest) async throws -> BudgetSnapshotResponse {
        try await client.updateSnapshot(snapshotId: snapshotId, payload: payload)
    }

    func deleteSnapshot(snapshotId: String) async throws {
        try await client.deleteSnapshot(snapshotId: snapshotId)
    }

    func getSnapshotItems(snapshotId: String) async throws -> [BudgetPlanItemResponse] {
        try await client.getSnapshotItems(snapshotId: snapshotId)
    }

    func getAllPlanItems() async throws -> [BudgetPlanItemResponse] {
        try await client.getAllPlanItems()
    }

    func createPlanItem(payload: BudgetPlanItemRequest) async throws -> BudgetPlanItemResponse {
        try await client.createPlanItem(payload: payload)
    }

    func updatePlanItem(itemId: String, payload: BudgetPlanItemRequest) async throws -> BudgetPlanItemResponse {
        try await client.updatePlanItem(itemId: itemId, payload: payload)
    }

    func deletePlanItem(itemId: String) async throws {
        try await client.deletePlanItem(itemId: itemId)
    }

    func getExpenses(from: String?, to: String?, cursor: String?, limit: Int?) async throws -> (items: [ExpenseResponse], nextCursor: String?) {
        try await client.getExpenses(from: from, to: to, cursor: cursor, limit: limit)
    }

    func createExpense(request: ExpenseRequest) async throws -> ExpenseResponse {
        try await client.createExpense(request: request)
    }

    func updateExpense(expenseId: String, payload: ExpenseRequest) async throws -> ExpenseResponse {
        try await client.updateExpense(expenseId: expenseId, payload: payload)
    }

    func deleteExpense(expenseId: String) async throws {
        try await client.deleteExpense(expenseId: expenseId)
    }

    func getCategories() async throws -> [ExpenseCategoryResponse] {
        try await client.getCategories()
    }

    func createCategory(payload: ExpenseCategoryRequest) async throws -> ExpenseCategoryResponse {
        try await client.createCategory(payload: payload)
    }

    func deleteCategory(categoryId: String) async throws {
        try await client.deleteCategory(categoryId: categoryId)
    }

    func getRecurringTemplates() async throws -> [RecurringTemplateResponse] {
        try await client.getRecurringTemplates()
    }

    func createRecurringTemplate(payload: RecurringTemplateRequest) async throws -> RecurringTemplateResponse {
        try await client.createRecurringTemplate(payload: payload)
    }

    func updateRecurringTemplate(templateId: String, payload: RecurringTemplateRequest) async throws -> RecurringTemplateResponse {
        try await client.updateRecurringTemplate(templateId: templateId, payload: payload)
    }

    func deleteRecurringTemplate(templateId: String) async throws {
        try await client.deleteRecurringTemplate(templateId: templateId)
    }

    func simulateFinancing(payload: FinancingSimulationRequest) async throws -> FinancingSimulationResponse {
        try await client.simulateFinancing(payload: payload)
    }

    func getFinancingPlans() async throws -> [FinancingPlanResponse] {
        try await client.getFinancingPlans()
    }

    func createFinancingPlan(payload: FinancingPlanRequest) async throws -> FinancingPlanResponse {
        try await client.createFinancingPlan(payload: payload)
    }

    func getFinancingProjections(from: String? = nil, to: String? = nil) async throws -> [FinancingProjectionResponse] {
        try await client.getFinancingProjections(from: from, to: to)
    }

    func getMonthlyExpenseReports(from: String? = nil, to: String? = nil) async throws -> [BudgetMonthSummaryResponse] {
        try await client.getMonthlyExpenseReports(from: from, to: to)
    }

    func getYearlyExpenseReports(from: String? = nil, to: String? = nil) async throws -> [BudgetYearSummaryResponse] {
        try await client.getYearlyExpenseReports(from: from, to: to)
    }

    func getReportsOverview(from: String? = nil, to: String? = nil) async throws -> ReportsOverviewResponse {
        try await client.getReportsOverview(from: from, to: to)
    }

    func getReportSuggestions(from: String? = nil, to: String? = nil) async throws -> ReportSuggestionsResponse {
        try await client.getReportSuggestions(from: from, to: to)
    }

    func dismissReportSuggestion(id: String) async throws {
        _ = try await client.dismissReportSuggestion(id: id)
    }
}

