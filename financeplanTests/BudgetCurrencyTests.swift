import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

/// The budget planner speaks one currency, in one format, about the month on
/// screen (spec § 2.0 A4, A11, A15).
@MainActor
final class BudgetCurrencyTests: XCTestCase {
  private let portugal = Locale(identifier: "pt_PT")
  private let calendar = Calendar(identifier: .gregorian)

  private func month(_ year: Int, _ month: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: 1))!
  }

  private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
  }

  func testDriftTotalsShareOneFormat() {
    let texts = BudgetDriftDashboardCard.totalTexts(actual: 0, target: 0, currencyCode: "USD", locale: portugal)
    XCTAssertEqual(texts.actual, "0,00\u{00A0}US$")
    XCTAssertEqual(texts.target, "0,00\u{00A0}US$")
  }

  func testCommandDeckTagIsPlain() {
    XCTAssertEqual(VigilExpensesCommandDeck.tagLabel(for: .fundamentals), "Fixed")
    XCTAssertEqual(VigilExpensesCommandDeck.tagLabel(for: .fun), "Leisure")
    XCTAssertEqual(VigilExpensesCommandDeck.tagLabel(for: .futureYou), "Variable")
  }

  func testCommandDeckUsesSelectedMonth() {
    let june = BudgetActivity(title: "Coffee", amount: 3.5, pillar: .fun, occurredOn: day(2026, 6, 27))
    let november = BudgetActivity(title: "Groceries", amount: 82, pillar: .fundamentals, occurredOn: day(2026, 11, 20))
    let viewModel = BudgetPlannerViewModel(
      monthlySnapshots: [
        MonthlyBudgetSnapshot(monthStart: month(2026, 6), netSalary: 2000, items: []),
        MonthlyBudgetSnapshot(monthStart: month(2026, 11), netSalary: 2000, items: []),
      ],
      activities: [june, november]
    )
    viewModel.selectMonth(month(2026, 11))

    XCTAssertEqual(viewModel.commandDeckActivities.map(\.title), ["Groceries"])
  }

  func testBudgetCurrencyComesFromTheBudgetSnapshot() {
    let viewModel = BudgetPlannerViewModel(
      monthlySnapshots: [
        MonthlyBudgetSnapshot(monthStart: month(2026, 11), netSalary: 2000, items: [], currencyCode: "EUR"),
      ],
      activities: []
    )
    viewModel.selectMonth(month(2026, 11))
    XCTAssertEqual(viewModel.budgetCurrencyCode, "EUR")
  }

  func testBudgetCurrencyIsUnknownWithoutASnapshot() {
    let viewModel = BudgetPlannerViewModel(monthlySnapshots: [], activities: [])
    // Unknown renders " —" through MoneyFormatter; never a guessed "USD".
    XCTAssertNil(viewModel.budgetCurrencyCode)
  }
}
