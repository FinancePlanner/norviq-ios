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
    var method: HTTPMethod { .get }
    var path: String { "/v1/expenses" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let from { params["from"] = from }
        if let to { params["to"] = to }
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
        if let linkedPlanItemId = payload.linkedPlanItemId {
            params["linked_plan_item_id"] = linkedPlanItemId
        }
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
        if let linkedPlanItemId = payload.linkedPlanItemId {
            params["linked_plan_item_id"] = linkedPlanItemId
        }
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
