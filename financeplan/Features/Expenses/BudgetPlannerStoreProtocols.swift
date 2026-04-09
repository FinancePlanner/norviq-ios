import Foundation
import StockPlanShared

@MainActor
protocol BudgetPlannerStoreProtocol: AnyObject {
  var monthlySnapshots: [MonthlyBudgetSnapshot] { get }
  var activities: [BudgetActivity] { get }
  var selectedMonthStart: Date { get set }
  var selectedMonthSnapshot: MonthlyBudgetSnapshot? { get }
  var selectedMonthActivities: [BudgetActivity] { get }
  var selectedMonthSummaries: [PillarPlanningSummary] { get }
  var selectedMonthAvailableAfterPillarPlan: Double { get }
  var selectedMonthLeftAfterSpending: Double { get }
  var errorMessage: String? { get set }

  func load(force: Bool) async
  func addOrUpdatePlanItem(_ draft: BudgetPlanItemDraft)
  func removePlanItem(_ itemID: UUID)
  func recordExpense(_ draft: BudgetActivityDraft)
  func recordExpenseAndWait(_ draft: BudgetActivityDraft) async -> Bool
  func updateNetSalary(_ amount: Double)
  func updateTargetShares(_ shares: [BudgetPillar: Double])
}

@MainActor
protocol ActivityTimelineStoreProtocol: AnyObject {
  var recentExpenseActivities: [BudgetActivity] { get }
}
