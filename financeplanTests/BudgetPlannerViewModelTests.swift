import Foundation
import XCTest

@testable import financeplan

final class BudgetPlannerViewModelTests: XCTestCase {
  private let calendar = Calendar(identifier: .gregorian)

  func testSelectedMonthUsesSalaryAndPillarTargetsToComputeAvailability() async {
    await MainActor.run {
      let month = makeMonth(2026, 3)
      let snapshot = MonthlyBudgetSnapshot(
        monthStart: month,
        netSalary: 3000,
        targetShares: [
          .fundamentals: 0.5,
          .futureYou: 0.2,
          .fun: 0.3,
        ],
        items: [
          BudgetPlanItem(title: "Rent", plannedAmount: 1100, pillar: .fundamentals),
          BudgetPlanItem(title: "ETF", plannedAmount: 400, pillar: .futureYou),
          BudgetPlanItem(title: "Dining", plannedAmount: 300, pillar: .fun),
        ]
      )

      let viewModel = BudgetPlannerViewModel(monthlySnapshots: [snapshot], activities: [])
      let summaries = Dictionary(uniqueKeysWithValues: viewModel.selectedMonthSummaries.map { ($0.pillar, $0) })
      guard
        let fundamentalsSummary = summaries[.fundamentals],
        let futureYouSummary = summaries[.futureYou],
        let funSummary = summaries[.fun]
      else {
        XCTFail("Expected all pillar summaries to exist.")
        return
      }

      XCTAssertEqual(viewModel.selectedMonthPlannedTotal, 1800, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthAvailableAfterPillarPlan, 1200, accuracy: 0.001)
      XCTAssertEqual(fundamentalsSummary.targetAmount, 1500, accuracy: 0.001)
      XCTAssertEqual(futureYouSummary.availableToPlan, 200, accuracy: 0.001)
      XCTAssertEqual(funSummary.availableToPlan, 600, accuracy: 0.001)
    }
  }

  func testRecordExpenseUpdatesActualTotalsAndMoneyLeft() async {
    await MainActor.run {
      let month = makeMonth(2026, 3)
      let rent = BudgetPlanItem(id: UUID(), title: "Rent", plannedAmount: 1100, pillar: .fundamentals)
      let snapshot = MonthlyBudgetSnapshot(
        monthStart: month,
        netSalary: 3000,
        items: [rent]
      )

      let viewModel = BudgetPlannerViewModel(monthlySnapshots: [snapshot], activities: [])

      viewModel.recordExpense(
        BudgetActivityDraft(
          title: "Rent",
          amount: 980,
          pillar: .fundamentals,
          occurredOn: makeDate(2026, 3, 2),
          linkedPlanItemID: rent.id
        )
      )

      XCTAssertEqual(viewModel.actualAmount(for: rent), 980, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthActualTotal, 980, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthLeftAfterSpending, 2020, accuracy: 0.001)
    }
  }

  func testCreateNextMonthPlanCopiesSalaryTargetsAndItems() async {
    await MainActor.run {
      let march = makeMonth(2026, 3)
      let snapshot = MonthlyBudgetSnapshot(
        monthStart: march,
        netSalary: 2700,
        targetShares: [
          .fundamentals: 0.45,
          .futureYou: 0.30,
          .fun: 0.25,
        ],
        items: [
          BudgetPlanItem(title: "Rent", plannedAmount: 980, pillar: .fundamentals),
          BudgetPlanItem(title: "ETF", plannedAmount: 350, pillar: .futureYou),
        ]
      )

      let viewModel = BudgetPlannerViewModel(monthlySnapshots: [snapshot], activities: [])
      viewModel.createNextMonthPlan()

      XCTAssertEqual(viewModel.availableMonths.count, 2)
      XCTAssertEqual(viewModel.selectedMonthSnapshot.netSalary, 2700, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedMonthSnapshot.items.count, 2)
      guard let futureYouTarget = viewModel.selectedMonthSnapshot.targetShares[.futureYou] else {
        XCTFail("Expected Future You target share.")
        return
      }
      XCTAssertEqual(futureYouTarget, 0.30, accuracy: 0.001)
      XCTAssertEqual(
        viewModel.selectedMonthStart,
        calendar.date(byAdding: .month, value: 1, to: march)
      )
    }
  }

  func testSelectYearBuildsYearSummaryAndMovesSelectionToLatestMonthInYear() async {
    await MainActor.run {
      let december2025 = makeMonth(2025, 12)
      let january2026 = makeMonth(2026, 1)
      let march2026 = makeMonth(2026, 3)

      let snapshots = [
        MonthlyBudgetSnapshot(monthStart: december2025, netSalary: 2600, items: []),
        MonthlyBudgetSnapshot(monthStart: january2026, netSalary: 2700, items: []),
        MonthlyBudgetSnapshot(monthStart: march2026, netSalary: 2800, items: []),
      ]

      let activities = [
        BudgetActivity(title: "December spend", amount: 900, pillar: .fundamentals, occurredOn: makeDate(2025, 12, 5)),
        BudgetActivity(title: "January spend", amount: 1100, pillar: .fundamentals, occurredOn: makeDate(2026, 1, 5)),
        BudgetActivity(title: "March spend", amount: 1300, pillar: .fun, occurredOn: makeDate(2026, 3, 6)),
      ]

      let viewModel = BudgetPlannerViewModel(monthlySnapshots: snapshots, activities: activities)

      viewModel.selectYear(2025)

      XCTAssertEqual(viewModel.selectedYear, 2025)
      XCTAssertEqual(viewModel.selectedMonthStart, december2025)
      XCTAssertEqual(viewModel.selectedYearSummaries.count, 1)
      XCTAssertEqual(viewModel.selectedYearActualTotal, 900, accuracy: 0.001)
      XCTAssertEqual(viewModel.selectedYearChartPoints.count, 12)
      XCTAssertEqual(
        viewModel.selectedYearChartPoints[11].actual,
        900,
        accuracy: 0.001
      )
    }
  }

  private func makeMonth(_ year: Int, _ month: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
  }

  private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
  }
}
