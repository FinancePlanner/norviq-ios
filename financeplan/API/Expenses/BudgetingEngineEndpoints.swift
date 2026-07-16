import AnyAPI
import Foundation

nonisolated enum BudgetDriftLevelWire: String, Codable, Sendable { case green, yellow, red }
nonisolated enum BudgetAllocationKindWire: String, Codable, Sendable { case expense, investmentContribution }

nonisolated struct BudgetCategoryDriftWire: Codable, Sendable, Identifiable, Equatable {
  let id: String
  let title: String
  let categoryId: String?
  let targetAmount: Double
  let actualAmount: Double
  let driftAmount: Double
  let driftPercent: Double?
  let threshold: Double
  let level: BudgetDriftLevelWire
  let allocationKind: BudgetAllocationKindWire
  let reallocationEligible: Bool
}

nonisolated struct BudgetDriftDashboardWire: Codable, Sendable, Equatable {
  let snapshotId: String
  let monthStart: String
  let currencyCode: String
  let revision: Int
  let totalTarget: Double
  let totalActual: Double
  let totalDriftAmount: Double
  let totalDriftPercent: Double?
  let totalLevel: BudgetDriftLevelWire
  let investmentContributionTarget: Double
  let lostInvestmentCapital: Double
  let categories: [BudgetCategoryDriftWire]
}

nonisolated struct BudgetDisciplineMonthWire: Codable, Sendable, Identifiable, Equatable {
  var id: String { monthStart }
  let monthStart: String
  let score: Double?
  let compliant: Bool?
}

nonisolated struct BudgetDisciplineSummaryWire: Codable, Sendable, Equatable {
  let currentScore: Double?
  let completedMonthStreak: Int
  let compliantMonths: Int
  let evaluatedMonths: Int
  let months: [BudgetDisciplineMonthWire]
}

nonisolated struct BudgetReallocationAdjustmentWire: Codable, Sendable, Equatable {
  let planItemId: String
  let amount: Double
}

nonisolated struct BudgetReallocationPreviewRequestWire: Codable, Sendable, Equatable {
  let snapshotId: String
  let expectedRevision: Int
  let adjustments: [BudgetReallocationAdjustmentWire]
  let financialGoalId: String?
  let portfolioListId: String?
}

nonisolated struct BudgetReallocationPreviewWire: Codable, Sendable, Equatable {
  let effectiveMonth: String
  let freedCapital: Double
  let annualImpact: Double
  let investmentTargetBefore: Double
  let investmentTargetAfter: Double
  let warnings: [String]
}

nonisolated struct BudgetReallocationCommitRequestWire: Codable, Sendable {
  let requestId: String
  let preview: BudgetReallocationPreviewRequestWire
}

nonisolated struct BudgetReallocationEventWire: Codable, Sendable, Identifiable, Equatable {
  let id: String
  let requestId: String
  let sourceSnapshotId: String
  let targetSnapshotId: String
  let effectiveMonth: String
  let freedCapital: Double
  let financialGoalId: String?
  let portfolioListId: String?
  let adjustments: [BudgetReallocationAdjustmentWire]
  let createdAt: String?
}

nonisolated struct GetBudgetDriftEndpoint: Endpoint {
  typealias Response = BudgetDriftDashboardWire
  let snapshotId: String
  var method: HTTPMethod { .get }
  var path: String { "/v1/budget/snapshots/\(snapshotId)/drift" }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetBudgetDisciplineEndpoint: Endpoint {
  typealias Response = BudgetDisciplineSummaryWire
  let months: Int
  var method: HTTPMethod { .get }
  var path: String { "/v1/budget/discipline" }
  func asParameters() throws -> Parameters { ["months": String(months)] }
}

nonisolated struct PreviewBudgetReallocationEndpoint: Endpoint {
  typealias Response = BudgetReallocationPreviewWire
  let body: BudgetReallocationPreviewRequestWire
  var method: HTTPMethod { .post }
  var path: String { "/v1/budget/reallocations/preview" }
  func asParameters() throws -> Parameters {
    let data = try JSONEncoder().encode(body)
    return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
  }
}

nonisolated struct CommitBudgetReallocationEndpoint: Endpoint {
  typealias Response = BudgetReallocationEventWire
  let body: BudgetReallocationCommitRequestWire
  var method: HTTPMethod { .post }
  var path: String { "/v1/budget/reallocations" }
  func asParameters() throws -> Parameters {
    let data = try JSONEncoder().encode(body)
    return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
  }
}

nonisolated struct GetBudgetReallocationHistoryEndpoint: Endpoint {
  typealias Response = [BudgetReallocationEventWire]
  var method: HTTPMethod { .get }
  var path: String { "/v1/budget/reallocations" }
  func asParameters() throws -> Parameters { [:] }
}
