import Foundation
import Testing
@testable import StockPlanShared

struct GoalPlanningDTOTests {
    @Test(arguments: FinancialGoalRiskProfile.allCases)
    func `risk profiles expose deterministic return assumptions`(_ profile: FinancialGoalRiskProfile) {
        #expect(profile.defaultAnnualReturn >= 0.04)
        #expect(profile.defaultAnnualReturn <= 0.08)
    }

    @Test
    func `future value uses effective monthly compounding and end of month contributions`() {
        let value = GoalProjectionCalculator.futureValue(
            principal: 100_000,
            monthlyContribution: 1000,
            annualRate: 0.06,
            months: 120
        )

        #expect(abs(value - 341_558.21) < 0.01)
    }

    @Test
    func `zero return calculation has a stable linear branch`() throws {
        #expect(GoalProjectionCalculator.futureValue(
            principal: 10000,
            monthlyContribution: 500,
            annualRate: 0,
            months: 24
        ) == 22000)
        #expect(try GoalProjectionCalculator.requiredMonthlyContribution(
            principal: 10000,
            target: 22000,
            annualRate: 0,
            months: 24
        ) == 500)
    }

    @Test
    func `legacy financial goal payload receives safe planning defaults`() throws {
        let payload = """
        {
          "id":"goal-1","name":"House","portfolioListId":"portfolio-1",
          "targetAmount":150000,"targetDate":"2031-07-16","baseCurrency":"EUR",
          "monthlyContribution":1200,"annualContributionGrowth":0,"inflationAssumption":0.02
        }
        """.data(using: .utf8)!

        let goal = try JSONDecoder().decode(FinancialGoal.self, from: payload)

        #expect(goal.goalType == .custom)
        #expect(goal.riskProfile == .moderate)
        #expect(goal.expectedAnnualReturn == 0.06)
        #expect(goal.status == .active)
    }

    @Test
    func `goal input rejects allocations outside percentage bounds`() {
        let input = FinancialGoalInput(
            name: "Retirement",
            targetAmount: 1_000_000,
            targetDate: "2046-07-16",
            baseCurrency: "EUR",
            portfolioAllocations: [
                .init(id: "link-1", portfolioListId: "portfolio-1", allocationPercentage: 101),
            ]
        )

        #expect(throws: GoalPlanningValidationError.invalidAllocation) {
            try input.validate()
        }
    }
}
