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

  private func makeMonth(_ year: Int, _ month: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
  }

  private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
  }
}
