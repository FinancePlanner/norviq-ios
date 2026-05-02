import AnyAPI
import Foundation
import OSLog
import StockPlanShared

// MARK: - Client

struct ExpensesHTTPClient: Sendable {
    enum Error: HTTPClientError {
        case invalidResponse
        case invalidStatus(Int)
        case unauthorized(String?)
        case api(String)

        nonisolated var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid server response."
            case let .invalidStatus(code):
                return "Request failed (\(code))."
            case let .unauthorized(message):
                return message ?? "Your session expired. Please sign in again."
            case let .api(message):
                return message
            }
        }

        nonisolated var statusCode: Int? {
            if case let .invalidStatus(code) = self { return code }
            return nil
        }

        nonisolated static func == (lhs: Error, rhs: Error) -> Bool {
            switch (lhs, rhs) {
            case (.invalidResponse, .invalidResponse): return true
            case let (.invalidStatus(l), .invalidStatus(r)): return l == r
            case let (.unauthorized(l), .unauthorized(r)): return l == r
            case let (.api(l), .api(r)): return l == r
            default: return false
            }
        }

        static func makeInvalidResponse() -> Error { .invalidResponse }
        static func makeInvalidStatus(_ code: Int) -> Error { .invalidStatus(code) }
        static func makeUnauthorized(_ message: String?) -> Error { .unauthorized(message) }
        static func makeAPI(_ message: String) -> Error { .api(message) }
    }

    private let client: BaseHTTPClient

    init(
        baseURL: URL,
        session: any HTTPClientSession = URLSession.shared,
        authTokenProvider: @escaping @Sendable () -> String? = { nil }
    ) {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "ExpensesHTTPClient")
        self.client = BaseHTTPClient(
            baseURL: baseURL,
            session: session,
            authTokenProvider: authTokenProvider,
            requestLogger: { path, method, parameters in
                ExpensesHTTPClient.logRequest(logger: logger, path: path, method: method, parameters: parameters)
            },
            logger: logger,
            decoder: .stockPlanShared
        )
    }

    // MARK: - Snapshots

    func getSnapshots(year: Int? = nil, month: Int? = nil) async throws -> [BudgetSnapshotResponse] {
        try await client.call(GetSnapshotsEndpoint(year: year, month: month), errorType: Error.self)
    }

    func createBudgetSnapshot(request: BudgetSnapshotRequest) async throws -> BudgetSnapshotResponse {
        try await client.call(CreateSnapshotEndpoint(payload: request), errorType: Error.self)
    }

    func updateSnapshot(snapshotId: String, payload: BudgetSnapshotRequest) async throws -> BudgetSnapshotResponse {
        try await client.call(UpdateSnapshotEndpoint(snapshotId: snapshotId, payload: payload), errorType: Error.self)
    }

    func deleteSnapshot(snapshotId: String) async throws {
        try await client.callWithoutResponse(DeleteSnapshotEndpoint(snapshotId: snapshotId), errorType: Error.self)
    }

    func getSnapshotItems(snapshotId: String) async throws -> [BudgetPlanItemResponse] {
        try await client.call(GetSnapshotItemsEndpoint(snapshotId: snapshotId), errorType: Error.self)
    }

    // MARK: - Plan Items

    func getAllPlanItems() async throws -> [BudgetPlanItemResponse] {
        try await client.call(GetAllPlanItemsEndpoint(), errorType: Error.self)
    }

    func createPlanItem(payload: BudgetPlanItemRequest) async throws -> BudgetPlanItemResponse {
        try await client.call(CreatePlanItemEndpoint(payload: payload), errorType: Error.self)
    }

    func updatePlanItem(itemId: String, payload: BudgetPlanItemRequest) async throws -> BudgetPlanItemResponse {
        try await client.call(UpdatePlanItemEndpoint(itemId: itemId, payload: payload), errorType: Error.self)
    }

    func deletePlanItem(itemId: String) async throws {
        try await client.callWithoutResponse(DeletePlanItemEndpoint(itemId: itemId), errorType: Error.self)
    }

    // MARK: - Expenses

    func getHouseholdPartner() async throws -> HouseholdPartnerProfileResponse {
        try await client.call(GetHouseholdPartnerEndpoint(), errorType: Error.self)
    }

    func updateHouseholdPartner(payload: HouseholdPartnerProfileRequest) async throws -> HouseholdPartnerProfileResponse {
        try await client.call(UpdateHouseholdPartnerEndpoint(payload: payload), errorType: Error.self)
    }

    func getExpenses(from: String? = nil, to: String? = nil, cursor: String? = nil, limit: Int? = nil) async throws -> (items: [ExpenseResponse], nextCursor: String?) {
        let endpoint = GetExpensesEndpoint(from: from, to: to, cursor: cursor, limit: limit)
        let (items, httpResponse) = try await client.callWithHeaders(endpoint, errorType: Error.self)
        let nextCursor = httpResponse.value(forHTTPHeaderField: "X-Next-Cursor")
        return (items, nextCursor)
    }

    func createExpense(request: ExpenseRequest) async throws -> ExpenseResponse {
        try await client.call(CreateExpenseEndpoint(payload: request), errorType: Error.self)
    }

    func updateExpense(expenseId: String, payload: ExpenseRequest) async throws -> ExpenseResponse {
        try await client.call(UpdateExpenseEndpoint(expenseId: expenseId, payload: payload), errorType: Error.self)
    }

    func deleteExpense(expenseId: String) async throws {
        try await client.callWithoutResponse(DeleteExpenseEndpoint(expenseId: expenseId), errorType: Error.self)
    }

    // MARK: - Categories

    func getCategories() async throws -> [ExpenseCategoryResponse] {
        try await client.call(GetCategoriesEndpoint(), errorType: Error.self)
    }

    func createCategory(payload: ExpenseCategoryRequest) async throws -> ExpenseCategoryResponse {
        try await client.call(CreateCategoryEndpoint(payload: payload), errorType: Error.self)
    }

    func deleteCategory(categoryId: String) async throws {
        try await client.callWithoutResponse(DeleteCategoryEndpoint(categoryId: categoryId), errorType: Error.self)
    }

    // MARK: - Recurring Templates

    func getRecurringTemplates() async throws -> [RecurringTemplateResponse] {
        try await client.call(GetRecurringTemplatesEndpoint(), errorType: Error.self)
    }

    func createRecurringTemplate(payload: RecurringTemplateRequest) async throws -> RecurringTemplateResponse {
        try await client.call(CreateRecurringTemplateEndpoint(payload: payload), errorType: Error.self)
    }

    func updateRecurringTemplate(templateId: String, payload: RecurringTemplateRequest) async throws -> RecurringTemplateResponse {
        try await client.call(UpdateRecurringTemplateEndpoint(templateId: templateId, payload: payload), errorType: Error.self)
    }

    func deleteRecurringTemplate(templateId: String) async throws {
        try await client.callWithoutResponse(DeleteRecurringTemplateEndpoint(templateId: templateId), errorType: Error.self)
    }

    // MARK: - Reports

    func getReportsOverview(from: String? = nil, to: String? = nil) async throws -> ReportsOverviewResponse {
        try await client.call(GetReportsOverviewEndpoint(from: from, to: to), errorType: Error.self)
    }

    func getMonthlyExpenseReports(from: String? = nil, to: String? = nil) async throws -> [BudgetMonthSummaryResponse] {
        try await client.call(GetMonthlyExpenseReportsEndpoint(from: from, to: to), errorType: Error.self)
    }

    func getYearlyExpenseReports(from: String? = nil, to: String? = nil) async throws -> [BudgetYearSummaryResponse] {
        try await client.call(GetYearlyExpenseReportsEndpoint(from: from, to: to), errorType: Error.self)
    }

    func getReportSuggestions(from: String? = nil, to: String? = nil) async throws -> ReportSuggestionsResponse {
        try await client.call(GetReportSuggestionsEndpoint(from: from, to: to), errorType: Error.self)
    }

    func dismissReportSuggestion(id: String) async throws -> APISuccess {
        try await client.call(DismissReportSuggestionEndpoint(suggestionId: id), errorType: Error.self)
    }

    // MARK: - Logging
    
    nonisolated private static func logRequest(logger: Logger, path: String, method: HTTPMethod, parameters: Parameters) {
        logger.debug(
            "Expenses request [\(method.rawValue, privacy: .public)] \(path, privacy: .public)"
        )
        
        if path == "/v1/budget/snapshots" || path.hasPrefix("/v1/budget/snapshots/") 
            || (path == "/v1/expenses" || path.hasPrefix("/v1/expenses/")) && method != .get {
            let body = (try? JSONSerialization.data(withJSONObject: parameters)).flatMap { String(data: $0, encoding: .utf8) } ?? "<empty>"
            logger.debug(
                "Expenses payload [\(path, privacy: .public)] body=\(body, privacy: .public)"
            )
        }
    }
}
