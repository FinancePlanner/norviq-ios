import StockPlanShared
import Testing
@testable import financeplan

@Suite("Budget drift view model")
@MainActor
struct BudgetDriftViewModelTests {
  @Test("Preview request carries selected goal and portfolio")
  func previewRequestCarriesDestination() throws {
    let dashboard = BudgetDriftDashboardWire(
      snapshotId: "snapshot", monthStart: "2026-07-01", currencyCode: "EUR", revision: 4,
      totalTarget: 1_000, totalActual: 1_100, totalDriftAmount: 100, totalDriftPercent: 10,
      totalLevel: .red, investmentContributionTarget: 300, lostInvestmentCapital: 100,
      categories: []
    )
    let viewModel = BudgetDriftViewModel(dashboard: dashboard)
    viewModel.adjustments = ["dining": 60]
    viewModel.selectedFinancialGoalID = "goal"
    viewModel.selectedPortfolioListID = "portfolio"

    let request = try #require(viewModel.makePreviewRequest())
    #expect(request.snapshotId == "snapshot")
    #expect(request.expectedRevision == 4)
    #expect(request.adjustments == [BudgetReallocationAdjustmentWire(planItemId: "dining", amount: 60)])
    #expect(request.financialGoalId == "goal")
    #expect(request.portfolioListId == "portfolio")
  }

  @Test("Alert policy endpoint encodes every user control")
  func alertPolicyEndpointEncoding() throws {
    let endpoint = UpdateBudgetAlertPolicyEndpoint(
      snapshotId: "snapshot",
      policy: BudgetAlertPolicy(
        categoryThreshold: 20,
        totalThreshold: 8,
        alertsEnabled: false,
        alertOnUnbudgeted: true
      )
    )

    let parameters = try endpoint.asParameters()
    #expect(endpoint.path == "/v1/budget/snapshots/snapshot/alert-policy")
    #expect(parameters["categoryThreshold"] as? Double == 20)
    #expect(parameters["totalThreshold"] as? Double == 8)
    #expect(parameters["alertsEnabled"] as? Bool == false)
    #expect(parameters["alertOnUnbudgeted"] as? Bool == true)
  }
}
