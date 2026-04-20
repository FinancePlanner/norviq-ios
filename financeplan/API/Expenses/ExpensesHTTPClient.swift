import AnyAPI
import Foundation
import OSLog
import StockPlanShared

private let expensesHTTPLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "ExpensesHTTPClient"
)

struct ExpensesHTTPClient {
    enum Error: LocalizedError, Equatable {
        case invalidResponse
        case invalidStatus(Int)
        case unauthorized(String?)
        case api(String)

        var errorDescription: String? {
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
    }

    let baseURL: URL
    let session: URLSession
    let authTokenProvider: () -> String?

    init(
        baseURL: URL,
        session: URLSession = .shared,
        authTokenProvider: @escaping () -> String? = { nil }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
    }

    // MARK: - Snapshots

    func getSnapshots(year: Int? = nil, month: Int? = nil) async throws -> [BudgetSnapshotResponse] {
        try await call(GetSnapshotsEndpoint(year: year, month: month))
    }

    func createBudgetSnapshot(request: BudgetSnapshotRequest) async throws -> BudgetSnapshotResponse {
        try await call(CreateSnapshotEndpoint(payload: request))
    }

    func updateSnapshot(snapshotId: String, payload: BudgetSnapshotRequest) async throws -> BudgetSnapshotResponse {
        try await call(UpdateSnapshotEndpoint(snapshotId: snapshotId, payload: payload))
    }

    func deleteSnapshot(snapshotId: String) async throws {
        _ = try await call(DeleteSnapshotEndpoint(snapshotId: snapshotId))
    }

    func getSnapshotItems(snapshotId: String) async throws -> [BudgetPlanItemResponse] {
        try await call(GetSnapshotItemsEndpoint(snapshotId: snapshotId))
    }

    // MARK: - Plan Items

    func getAllPlanItems() async throws -> [BudgetPlanItemResponse] {
        try await call(GetAllPlanItemsEndpoint())
    }

    func createPlanItem(payload: BudgetPlanItemRequest) async throws -> BudgetPlanItemResponse {
        try await call(CreatePlanItemEndpoint(payload: payload))
    }

    func updatePlanItem(itemId: String, payload: BudgetPlanItemRequest) async throws -> BudgetPlanItemResponse {
        try await call(UpdatePlanItemEndpoint(itemId: itemId, payload: payload))
    }

    func deletePlanItem(itemId: String) async throws {
        _ = try await call(DeletePlanItemEndpoint(itemId: itemId))
    }

    // MARK: - Expenses

    func getHouseholdPartner() async throws -> HouseholdPartnerProfileResponse {
        try await call(GetHouseholdPartnerEndpoint())
    }

    func updateHouseholdPartner(payload: HouseholdPartnerProfileRequest) async throws -> HouseholdPartnerProfileResponse {
        try await call(UpdateHouseholdPartnerEndpoint(payload: payload))
    }

    func getExpenses(from: String? = nil, to: String? = nil) async throws -> [ExpenseResponse] {
        try await call(GetExpensesEndpoint(from: from, to: to))
    }

    func createExpense(request: ExpenseRequest) async throws -> ExpenseResponse {
        try await call(CreateExpenseEndpoint(payload: request))
    }

    func updateExpense(expenseId: String, payload: ExpenseRequest) async throws -> ExpenseResponse {
        try await call(UpdateExpenseEndpoint(expenseId: expenseId, payload: payload))
    }

    func deleteExpense(expenseId: String) async throws {
        _ = try await call(DeleteExpenseEndpoint(expenseId: expenseId))
    }

    // MARK: - Categories

    func getCategories() async throws -> [ExpenseCategoryResponse] {
        try await call(GetCategoriesEndpoint())
    }

    func createCategory(payload: ExpenseCategoryRequest) async throws -> ExpenseCategoryResponse {
        try await call(CreateCategoryEndpoint(payload: payload))
    }

    func deleteCategory(categoryId: String) async throws {
        _ = try await call(DeleteCategoryEndpoint(categoryId: categoryId))
    }

    // MARK: - Recurring Templates

    func getRecurringTemplates() async throws -> [RecurringTemplateResponse] {
        try await call(GetRecurringTemplatesEndpoint())
    }

    func createRecurringTemplate(payload: RecurringTemplateRequest) async throws -> RecurringTemplateResponse {
        try await call(CreateRecurringTemplateEndpoint(payload: payload))
    }

    func updateRecurringTemplate(templateId: String, payload: RecurringTemplateRequest) async throws -> RecurringTemplateResponse {
        try await call(UpdateRecurringTemplateEndpoint(templateId: templateId, payload: payload))
    }

    func deleteRecurringTemplate(templateId: String) async throws {
        _ = try await call(DeleteRecurringTemplateEndpoint(templateId: templateId))
    }

    // MARK: - Reports

    func getReportsOverview(from: String? = nil, to: String? = nil) async throws -> ReportsOverviewResponse {
        try await call(GetReportsOverviewEndpoint(from: from, to: to))
    }

    func getMonthlyExpenseReports(from: String? = nil, to: String? = nil) async throws -> [BudgetMonthSummaryResponse] {
        try await call(GetMonthlyExpenseReportsEndpoint(from: from, to: to))
    }

    func getYearlyExpenseReports(from: String? = nil, to: String? = nil) async throws -> [BudgetYearSummaryResponse] {
        try await call(GetYearlyExpenseReportsEndpoint(from: from, to: to))
    }

    func getReportSuggestions(from: String? = nil, to: String? = nil) async throws -> ReportSuggestionsResponse {
        try await call(GetReportSuggestionsEndpoint(from: from, to: to))
    }

    func dismissReportSuggestion(id: String) async throws -> APISuccess {
        try await call(DismissReportSuggestionEndpoint(suggestionId: id))
    }

    // MARK: - Core Logic

    private func call<E: Endpoint>(_ endpoint: E) async throws -> E.Response where E.Response: Codable {
        let data = try await perform(endpoint)
        do {
            return try endpoint.decode(data)
        } catch {
            if let envelope = try? endpoint.decoder.decode(HTTPEnvelope<E.Response>.self, from: data) {
                if let payload = envelope.data {
                    return payload
                }
                if let message = envelope.message, !message.isEmpty {
                    throw Error.api(message)
                }
            }
            throw error
        }
    }

    private func perform<E: Endpoint>(_ endpoint: E) async throws -> Data {
        let request = try makeURLRequest(for: endpoint)
        logRequest(request, endpoint: endpoint)
        logSnapshotRequestIfNeeded(request, endpointPath: endpoint.path)
        logExpenseRequestIfNeeded(request, endpointPath: endpoint.path)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }

        expensesHTTPLogger.debug(
            "Expenses response [\(endpoint.path, privacy: .public)] status=\(httpResponse.statusCode, privacy: .public)"
        )

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = errorMessage(from: data)

            if httpResponse.statusCode == 401 {
                throw Error.unauthorized(message)
            }

            if let message, !message.isEmpty {
                throw Error.api(message)
            }
            throw Error.invalidStatus(httpResponse.statusCode)
        }

        return data
    }

    private func logRequest<E: Endpoint>(_ request: URLRequest, endpoint: E) {
        let method = request.httpMethod ?? endpoint.method.rawValue
        let urlString =
            request.url?.absoluteString ?? baseURL.appendingPathComponent(endpoint.path).absoluteString
        expensesHTTPLogger.debug(
            "Expenses request [\(method, privacy: .public)] \(urlString, privacy: .public)"
        )
    }

    private func logSnapshotRequestIfNeeded(_ request: URLRequest, endpointPath: String) {
        guard endpointPath == "/v1/budget/snapshots" || endpointPath.hasPrefix("/v1/budget/snapshots/") else {
            return
        }

        let body = request.httpBody.flatMap {
            String(data: $0, encoding: .utf8)
        } ?? "<empty>"

        expensesHTTPLogger.debug(
            "Expenses request [\(endpointPath, privacy: .public)] body=\(body, privacy: .public)"
        )
    }

    private func logExpenseRequestIfNeeded(_ request: URLRequest, endpointPath: String) {
        guard endpointPath == "/v1/expenses" || endpointPath.hasPrefix("/v1/expenses/") else {
            return
        }
        guard request.httpMethod != HTTPMethod.get.rawValue else { return }

        let body = request.httpBody.flatMap {
            String(data: $0, encoding: .utf8)
        } ?? "<empty>"

        expensesHTTPLogger.debug(
            "Expenses request [\(endpointPath, privacy: .public)] body=\(body, privacy: .public)"
        )
    }

    private func errorMessage(from data: Data) -> String? {
        let decoder = JSONDecoder.stockPlanShared
        if let stockError = try? decoder.decode(StockPlanShared.APIErrorResponse.self, from: data),
           !stockError.error.isEmpty {
            return stockError.error
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? String, !error.isEmpty { return error }
            if let reason = json["reason"] as? String, !reason.isEmpty { return reason }
            if let message = json["message"] as? String, !message.isEmpty { return message }
        }

        return nil
    }

    private func makeURLRequest<E: Endpoint>(for endpoint: E) throws -> URLRequest {
        let normalizedPath = endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let base = baseURL.appendingPathComponent(normalizedPath)
        let parameters = try endpoint.asParameters()
        let url = try url(for: endpoint.method, baseURL: base, parameters: parameters)

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if endpoint.method != .get, !parameters.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        }

        return request
    }

    private func url(for method: HTTPMethod, baseURL: URL, parameters: Parameters) throws -> URL {
        guard method == .get, !parameters.isEmpty else { return baseURL }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = parameters.compactMap { key, value in
            URLQueryItem(name: key, value: String(describing: value))
        }

        guard let url = components?.url else { throw Error.invalidResponse }
        return url
    }
}

private struct HTTPEnvelope<T: Codable>: Codable {
    let data: T?
    let message: String?
}
