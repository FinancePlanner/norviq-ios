import AnyAPI
import Foundation
import StockPlanShared

// MARK: - Snapshots

struct GetSnapshotsEndpoint: Endpoint {
    typealias Response = [BudgetSnapshotResponse]
    let year: Int?
    let month: Int?
    var method: HTTPMethod { .get }
    var path: String { "/v1/budget/snapshots" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let year { params["year"] = String(year) }
        if let month { params["month"] = String(month) }
        return params
    }
}

struct CreateSnapshotEndpoint: Endpoint {
    typealias Response = BudgetSnapshotResponse
    let payload: BudgetSnapshotRequest
    var method: HTTPMethod { .post }
    var path: String { "/v1/budget/snapshots" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        [
            "month_start": payload.monthStart,
            "net_salary": payload.netSalary,
            "target_shares": payload.targetShares
        ]
    }
}

struct UpdateSnapshotEndpoint: Endpoint {
    typealias Response = BudgetSnapshotResponse
    let snapshotId: String
    let payload: BudgetSnapshotRequest
    var method: HTTPMethod { .patch }
    var path: String { "/v1/budget/snapshots/\(snapshotId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        [
            "month_start": payload.monthStart,
            "net_salary": payload.netSalary,
            "target_shares": payload.targetShares
        ]
    }
}

struct DeleteSnapshotEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let snapshotId: String
    var method: HTTPMethod { .delete }
    var path: String { "/v1/budget/snapshots/\(snapshotId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct GetSnapshotItemsEndpoint: Endpoint {
    typealias Response = [BudgetPlanItemResponse]
    let snapshotId: String
    var method: HTTPMethod { .get }
    var path: String { "/v1/budget/snapshots/\(snapshotId)/items" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

// MARK: - Plan Items

struct GetAllPlanItemsEndpoint: Endpoint {
    typealias Response = [BudgetPlanItemResponse]
    var method: HTTPMethod { .get }
    var path: String { "/v1/budget/items" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct CreatePlanItemEndpoint: Endpoint {
    typealias Response = BudgetPlanItemResponse
    let payload: BudgetPlanItemRequest
    var method: HTTPMethod { .post }
    var path: String { "/v1/budget/items" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        [
            "snapshot_id": payload.snapshotId,
            "title": payload.title,
            "planned_amount": payload.plannedAmount,
            "pillar": payload.pillar.rawValue,
            "split_mode": payload.splitMode.rawValue,
            "user_share_percent": payload.userSharePercent
        ]
    }
}

struct UpdatePlanItemEndpoint: Endpoint {
    typealias Response = BudgetPlanItemResponse
    let itemId: String
    let payload: BudgetPlanItemRequest
    var method: HTTPMethod { .patch }
    var path: String { "/v1/budget/items/\(itemId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        [
            "snapshot_id": payload.snapshotId,
            "title": payload.title,
            "planned_amount": payload.plannedAmount,
            "pillar": payload.pillar.rawValue,
            "split_mode": payload.splitMode.rawValue,
            "user_share_percent": payload.userSharePercent
        ]
    }
}

struct DeletePlanItemEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let itemId: String
    var method: HTTPMethod { .delete }
    var path: String { "/v1/budget/items/\(itemId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

// MARK: - Expenses

struct GetHouseholdPartnerEndpoint: Endpoint {
    typealias Response = HouseholdPartnerProfileResponse
    var method: HTTPMethod { .get }
    var path: String { "/v1/expenses/partner" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct UpdateHouseholdPartnerEndpoint: Endpoint {
    typealias Response = HouseholdPartnerProfileResponse
    let payload: HouseholdPartnerProfileRequest
    var method: HTTPMethod { .put }
    var path: String { "/v1/expenses/partner" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        let data = try JSONEncoder.stockPlanShared.encode(payload)
        return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
    }
}

struct GetExpensesEndpoint: Endpoint {
    typealias Response = [ExpenseResponse]
    let from: String?
    let to: String?
    let cursor: String?
    let limit: Int?

    var method: HTTPMethod { .get }
    var path: String { "/v1/expenses" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let from { params["from"] = from }
        if let to { params["to"] = to }
        if let cursor { params["cursor"] = cursor }
        if let limit { params["limit"] = String(limit) }
        return params
    }
}

struct CreateExpenseEndpoint: Endpoint {
    typealias Response = ExpenseResponse
    let payload: ExpenseRequest
    var method: HTTPMethod { .post }
    var path: String { "/v1/expenses" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        var params: Parameters = [
            "title": payload.title,
            "amount": payload.amount,
            "pillar": payload.pillar.rawValue,
            "occurred_on": payload.occurredOn,
            "split_mode": payload.splitMode.rawValue,
            "user_share_percent": payload.userSharePercent
        ]
        if let linkedPlanItemId = payload.linkedPlanItemId { params["linked_plan_item_id"] = linkedPlanItemId }
        if let categoryId = payload.categoryId { params["category_id"] = categoryId }
        if let fa = payload.foreignAmount { params["foreign_amount"] = fa }
        if let fc = payload.foreignCurrency { params["foreign_currency"] = fc }
        if let rate = payload.exchangeRate { params["exchange_rate"] = rate }
        return params
    }
}

struct UpdateExpenseEndpoint: Endpoint {
    typealias Response = ExpenseResponse
    let expenseId: String
    let payload: ExpenseRequest
    var method: HTTPMethod { .patch }
    var path: String { "/v1/expenses/\(expenseId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        var params: Parameters = [
            "title": payload.title,
            "amount": payload.amount,
            "pillar": payload.pillar.rawValue,
            "occurred_on": payload.occurredOn,
            "split_mode": payload.splitMode.rawValue,
            "user_share_percent": payload.userSharePercent
        ]
        if let linkedPlanItemId = payload.linkedPlanItemId { params["linked_plan_item_id"] = linkedPlanItemId }
        if let categoryId = payload.categoryId { params["category_id"] = categoryId }
        if let fa = payload.foreignAmount { params["foreign_amount"] = fa }
        if let fc = payload.foreignCurrency { params["foreign_currency"] = fc }
        if let rate = payload.exchangeRate { params["exchange_rate"] = rate }
        return params
    }
}

struct DeleteExpenseEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let expenseId: String
    var method: HTTPMethod { .delete }
    var path: String { "/v1/expenses/\(expenseId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

// MARK: - Categories

struct GetCategoriesEndpoint: Endpoint {
    typealias Response = [ExpenseCategoryResponse]
    var method: HTTPMethod { .get }
    var path: String { "/v1/expenses/categories" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct CreateCategoryEndpoint: Endpoint {
    typealias Response = ExpenseCategoryResponse
    let payload: ExpenseCategoryRequest
    var method: HTTPMethod { .post }
    var path: String { "/v1/expenses/categories" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        var params: Parameters = ["name": payload.name]
        if let pillar = payload.pillar { params["pillar"] = pillar.rawValue }
        return params
    }
}

struct DeleteCategoryEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let categoryId: String
    var method: HTTPMethod { .delete }
    var path: String { "/v1/expenses/categories/\(categoryId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

// MARK: - Recurring Templates

struct GetRecurringTemplatesEndpoint: Endpoint {
    typealias Response = [RecurringTemplateResponse]
    var method: HTTPMethod { .get }
    var path: String { "/v1/expenses/recurring" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct CreateRecurringTemplateEndpoint: Endpoint {
    typealias Response = RecurringTemplateResponse
    let payload: RecurringTemplateRequest
    var method: HTTPMethod { .post }
    var path: String { "/v1/expenses/recurring" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        var params: Parameters = [
            "title": payload.title,
            "amount": payload.amount,
            "pillar": payload.pillar.rawValue,
            "frequency": payload.frequency.rawValue,
            "split_mode": payload.splitMode.rawValue,
            "user_share_percent": payload.userSharePercent
        ]
        if let categoryId = payload.categoryId { params["category_id"] = categoryId }
        return params
    }
}

struct UpdateRecurringTemplateEndpoint: Endpoint {
    typealias Response = RecurringTemplateResponse
    let templateId: String
    let payload: RecurringTemplateRequest
    var method: HTTPMethod { .patch }
    var path: String { "/v1/expenses/recurring/\(templateId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        var params: Parameters = [
            "title": payload.title,
            "amount": payload.amount,
            "pillar": payload.pillar.rawValue,
            "frequency": payload.frequency.rawValue,
            "split_mode": payload.splitMode.rawValue,
            "user_share_percent": payload.userSharePercent
        ]
        if let categoryId = payload.categoryId { params["category_id"] = categoryId }
        return params
    }
}

struct DeleteRecurringTemplateEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let templateId: String
    var method: HTTPMethod { .delete }
    var path: String { "/v1/expenses/recurring/\(templateId)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

// MARK: - Reports

struct GetReportsOverviewEndpoint: Endpoint {
    typealias Response = ReportsOverviewResponse
    let from: String?
    let to: String?
    var method: HTTPMethod { .get }
    var path: String { "/v1/reports/overview" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let from { params["from"] = from }
        if let to { params["to"] = to }
        return params
    }
}

struct GetMonthlyExpenseReportsEndpoint: Endpoint {
    typealias Response = [BudgetMonthSummaryResponse]
    let from: String?
    let to: String?
    var method: HTTPMethod { .get }
    var path: String { "/v1/reports/expenses" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        var params: Parameters = ["granularity": "month"]
        if let from { params["from"] = from }
        if let to { params["to"] = to }
        return params
    }
}

struct GetYearlyExpenseReportsEndpoint: Endpoint {
    typealias Response = [BudgetYearSummaryResponse]
    let from: String?
    let to: String?
    var method: HTTPMethod { .get }
    var path: String { "/v1/reports/expenses" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        var params: Parameters = ["granularity": "year"]
        if let from { params["from"] = from }
        if let to { params["to"] = to }
        return params
    }
}

struct GetReportSuggestionsEndpoint: Endpoint {
    typealias Response = ReportSuggestionsResponse
    let from: String?
    let to: String?
    var method: HTTPMethod { .get }
    var path: String { "/v1/reports/suggestions" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let from { params["from"] = from }
        if let to { params["to"] = to }
        return params
    }
}

struct DismissReportSuggestionEndpoint: Endpoint {
    typealias Response = APISuccess
    let suggestionId: String
    var method: HTTPMethod { .post }
    var path: String { "/v1/reports/suggestions/\(suggestionId)/dismiss" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}
