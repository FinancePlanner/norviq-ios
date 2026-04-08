import XCTest
import StockPlanShared
@testable import financeplan

final class ExpensesLogicTests: XCTestCase {
    
    func testBudgetMonthSummaryCalculations() {
        let calendar = Calendar(identifier: .gregorian)
        let monthStart = calendar.date(from: DateComponents(year: 2024, month: 4, day: 1))!
        
        let pillarActuals: [BudgetPillar: Double] = [
            .fundamentals: 1500.0,
            .fun: 500.0,
            .futureYou: 1000.0
        ]
        
        let pillarPlans: [BudgetPillar: Double] = [
            .fundamentals: 1400.0,
            .fun: 600.0,
            .futureYou: 1000.0
        ]
        
        let summary = BudgetMonthSummary(
            monthStart: monthStart,
            planned: 3000.0,
            actual: 3000.0,
            salary: 5000.0,
            pillarActuals: pillarActuals,
            pillarPlans: pillarPlans
        )
        
        XCTAssertEqual(summary.remainingAfterPlanning, 2000.0)
        XCTAssertEqual(summary.remainingAfterSpending, 2000.0)
        XCTAssertEqual(summary.longLabel, "April 2024")
    }
    
    func testBudgetPlanItemInitialization() {
        let id = UUID()
        let item = BudgetPlanItem(id: id, title: "Rent", plannedAmount: 1200.0, pillar: .fundamentals)
        
        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.title, "Rent")
        XCTAssertEqual(item.plannedAmount, 1200.0)
        XCTAssertEqual(item.pillar, .fundamentals)
    }
    
    func testBudgetActivityInitialization() {
        let id = UUID()
        let date = Date()
        let activity = BudgetActivity(id: id, title: "Grocery", amount: 50.0, pillar: .fundamentals, occurredOn: date)
        
        XCTAssertEqual(activity.id, id)
        XCTAssertEqual(activity.title, "Grocery")
        XCTAssertEqual(activity.amount, 50.0)
        XCTAssertEqual(activity.pillar, .fundamentals)
        XCTAssertEqual(activity.occurredOn, date)
    }
}
