import Foundation
import Testing
@testable import StockPlanShared

@Suite("Planning engine")
// swiftlint:disable:next type_body_length — one suite per engine.
struct PlanningEngineTests {
    // MARK: Growth projection

    /// The load-bearing invariant. The Grow screen uses the schedule loop and goals use the
    /// closed form; if these ever diverge the two features quietly disagree about the same plan.
    @Test
    func `schedule loop reproduces the closed form when contributions do not grow`() throws {
        let assumptions = ProjectionAssumptions(
            initialAmount: 10000,
            monthlyContribution: 400,
            annualReturnRate: 0.07,
            annualContributionGrowthRate: 0,
            years: 20
        )

        let projected = try PlanningEngine.project(assumptions).endingValueNominal
        let closedForm = PlanningEngine.futureValue(
            principal: 10000,
            monthlyContribution: 400,
            annualRate: 0.07,
            months: 240
        )

        #expect(abs(projected - closedForm) < 0.000_001)
    }

    @Test
    func `a zero year horizon returns the initial amount untouched`() throws {
        let result = try PlanningEngine.project(
            ProjectionAssumptions(
                initialAmount: 25000,
                monthlyContribution: 500,
                annualReturnRate: 0.07,
                years: 0
            )
        )

        #expect(result.endingValueNominal == 25000)
        #expect(result.totalContributed == 25000)
        #expect(result.totalGrowth == 0)
        #expect(result.years.count == 1)
    }

    @Test
    func `the year table covers every year plus today`() throws {
        let result = try PlanningEngine.project(
            ProjectionAssumptions(
                initialAmount: 1000,
                monthlyContribution: 100,
                annualReturnRate: 0.05,
                years: 30
            )
        )

        #expect(result.years.count == 31)
        #expect(result.years.first?.yearIndex == 0)
        #expect(result.years.last?.yearIndex == 30)
    }

    @Test
    func `contributions step once a year so the first year pays the base amount`() throws {
        let result = try PlanningEngine.project(
            ProjectionAssumptions(
                initialAmount: 0,
                monthlyContribution: 100,
                annualReturnRate: 0.06,
                annualContributionGrowthRate: 0.03,
                years: 3
            )
        )

        #expect(abs(result.years[1].contributedThisYear - 1200) < 0.000_001)
        #expect(abs(result.years[2].contributedThisYear - 1236) < 0.000_001)
        #expect(abs(result.years[3].contributedThisYear - 1273.08) < 0.01)
    }

    /// The closed form in the brief divides by `r - g`. The loop has no such term, so these
    /// inputs are ordinary rather than degenerate.
    @Test(arguments: [0.07, 0.10, 0.15])
    func `contribution growth at or above the return rate stays finite`(_ growth: Double) throws {
        let result = try PlanningEngine.project(
            ProjectionAssumptions(
                initialAmount: 5000,
                monthlyContribution: 300,
                annualReturnRate: 0.07,
                annualContributionGrowthRate: growth,
                years: 25
            )
        )

        #expect(result.endingValueNominal.isFinite)
        #expect(result.endingValueNominal > 0)
    }

    @Test
    func `real value deflates the nominal balance by inflation`() throws {
        let result = try PlanningEngine.project(
            ProjectionAssumptions(
                initialAmount: 100_000,
                monthlyContribution: 0,
                annualReturnRate: 0.05,
                annualInflationRate: 0.02,
                years: 10
            )
        )

        let expectedReal = result.endingValueNominal / pow(1.02, 10)
        #expect(abs(result.endingValueReal - expectedReal) < 0.000_001)
        #expect(result.endingValueReal < result.endingValueNominal)
    }

    @Test
    func `growth and contributions account for the whole ending balance`() throws {
        let result = try PlanningEngine.project(
            ProjectionAssumptions(
                initialAmount: 10000,
                monthlyContribution: 400,
                annualReturnRate: 0.07,
                years: 20
            )
        )

        #expect(abs(result.totalContributed + result.totalGrowth - result.endingValueNominal) < 0.000_001)
        #expect(abs(result.totalContributed - (10000 + 400 * 240)) < 0.000_001)
    }

    @Test
    func `sensitivity brackets the base case`() throws {
        let assumptions = ProjectionAssumptions(
            initialAmount: 10000,
            monthlyContribution: 400,
            annualReturnRate: 0.07,
            years: 20
        )
        let points = try PlanningEngine.sensitivity(assumptions)
        let base = try PlanningEngine.project(assumptions).endingValueNominal

        #expect(points.count == 3)
        #expect(points[0].endingValueNominal < base)
        #expect(abs(points[1].endingValueNominal - base) < 0.000_001)
        #expect(points[2].endingValueNominal > base)
    }

    @Test
    func `a return rate of minus one hundred percent is rejected rather than returning NaN`() {
        #expect(throws: PlanningValidationError.invalidReturnRate) {
            try PlanningEngine.project(
                ProjectionAssumptions(
                    initialAmount: 1000,
                    monthlyContribution: 0,
                    annualReturnRate: -1,
                    years: 10
                )
            )
        }
    }

    // MARK: Retirement need

    @Test
    func `spending at retirement inflates today's cost of life over the horizon`() throws {
        let input = RetirementNeedInput(
            currentAge: 40, retirementAge: 60, longevityAge: 90,
            monthlyCostOfLifeToday: 2800,
            annualInflationRate: 0.02, withdrawalRate: 0.04, expectedAnnualReturn: 0.05
        )

        let need = try PlanningEngine.retirementNeed(input, projectedPortfolioAtRetirement: 0)
        let expected: Double = 2800 * 12 * pow(1.02, 20)

        #expect(abs(need.annualSpendingAtRetirement - expected) < 0.01)
        #expect(abs(need.nestEggAtWithdrawalRate - expected / 0.04) < 0.01)
    }

    @Test
    func `other retirement income reduces what the portfolio has to cover`() throws {
        let base = RetirementNeedInput(
            currentAge: 40, retirementAge: 60, longevityAge: 90,
            monthlyCostOfLifeToday: 2800, expectedAnnualReturn: 0.05
        )
        let withPension = RetirementNeedInput(
            currentAge: 40, retirementAge: 60, longevityAge: 90,
            monthlyCostOfLifeToday: 2800, monthlyOtherIncomeAtRetirement: 800,
            expectedAnnualReturn: 0.05
        )

        let baseNeed = try PlanningEngine.retirementNeed(base, projectedPortfolioAtRetirement: 0)
        let pensionNeed = try PlanningEngine.retirementNeed(withPension, projectedPortfolioAtRetirement: 0)

        #expect(pensionNeed.nestEggAtWithdrawalRate < baseNeed.nestEggAtWithdrawalRate)
    }

    /// "If rent drops to zero at 65, you need this much less" — the depletion run is the only
    /// one of the two methods that can express this at all.
    @Test
    func `housing that ends lowers spending from that age onward`() throws {
        let input = RetirementNeedInput(
            currentAge: 40, retirementAge: 60, longevityAge: 90,
            monthlyCostOfLifeToday: 2800, monthlyHousingToday: 900, housingEndsAtAge: 65,
            expectedAnnualReturn: 0.05
        )

        let need = try PlanningEngine.retirementNeed(input, projectedPortfolioAtRetirement: 2_000_000)
        let atSixtyFour = try #require(need.depletion.first { $0.age == 64 })
        let atSixtyFive = try #require(need.depletion.first { $0.age == 65 })

        #expect(atSixtyFive.annualSpending < atSixtyFour.annualSpending)
    }

    @Test
    func `housing that never ends keeps spending rising every year`() throws {
        let input = RetirementNeedInput(
            currentAge: 40, retirementAge: 60, longevityAge: 90,
            monthlyCostOfLifeToday: 2800, monthlyHousingToday: 900, housingEndsAtAge: nil,
            expectedAnnualReturn: 0.05
        )

        let need = try PlanningEngine.retirementNeed(input, projectedPortfolioAtRetirement: 5_000_000)
        let spending = need.depletion.map(\.annualSpending)

        #expect(zip(spending, spending.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test
    func `an underfunded portfolio reports the age it runs out`() throws {
        let input = RetirementNeedInput(
            currentAge: 40, retirementAge: 60, longevityAge: 90,
            monthlyCostOfLifeToday: 2800, expectedAnnualReturn: 0.05
        )

        let need = try PlanningEngine.retirementNeed(input, projectedPortfolioAtRetirement: 200_000)

        #expect(need.shortfallAge != nil)
        #expect(need.lastsToLongevity == false)
        #expect(need.endingBalance == 0)
    }

    @Test
    func `a well funded portfolio lasts to longevity`() throws {
        let input = RetirementNeedInput(
            currentAge: 40, retirementAge: 60, longevityAge: 90,
            monthlyCostOfLifeToday: 2800, expectedAnnualReturn: 0.05
        )

        let need = try PlanningEngine.retirementNeed(input, projectedPortfolioAtRetirement: 5_000_000)

        #expect(need.shortfallAge == nil)
        #expect(need.lastsToLongevity)
        #expect(need.runwayYears == 30)
    }

    @Test
    func `ages that do not form a valid timeline are rejected`() {
        #expect(throws: PlanningValidationError.invalidAges) {
            try PlanningEngine.retirementNeed(
                RetirementNeedInput(
                    currentAge: 60,
                    retirementAge: 50,
                    longevityAge: 90,
                    monthlyCostOfLifeToday: 2000,
                    expectedAnnualReturn: 0.05
                ),
                projectedPortfolioAtRetirement: 0
            )
        }
    }

    // MARK: The lever

    /// The product line. Saving the recommended extra each month must actually land on the
    /// target it was derived from, or the advice is decoration.
    @Test
    func `the recommended extra contribution closes the gap it was derived from`() throws {
        let need = RetirementNeedInput(
            currentAge: 40, retirementAge: 60, longevityAge: 90,
            monthlyCostOfLifeToday: 2800, expectedAnnualReturn: 0.07
        )
        let plan = ProjectionAssumptions(
            initialAmount: 10000,
            monthlyContribution: 400,
            annualReturnRate: 0.07,
            years: 20
        )

        let lever = try PlanningEngine.lever(need: need, plan: plan)
        let extra = try #require(lever.additionalMonthlyContribution)
        #expect(extra > 0)

        let target = try PlanningEngine.retirementNeed(need, projectedPortfolioAtRetirement: 0)
            .nestEggAtWithdrawalRate
        let topped = try PlanningEngine.project(
            ProjectionAssumptions(
                initialAmount: 10000,
                monthlyContribution: 400 + extra,
                annualReturnRate: 0.07,
                years: 20
            )
        ).endingValueNominal

        #expect(abs(topped - target) < 0.01)
    }

    @Test
    func `a plan already ahead of its target reports no levers`() throws {
        let need = RetirementNeedInput(
            currentAge: 40, retirementAge: 60, longevityAge: 90,
            monthlyCostOfLifeToday: 500, expectedAnnualReturn: 0.07
        )
        let plan = ProjectionAssumptions(
            initialAmount: 900_000,
            monthlyContribution: 3000,
            annualReturnRate: 0.07,
            years: 20
        )

        let lever = try PlanningEngine.lever(need: need, plan: plan)

        #expect(lever.isOnTrack)
        #expect(lever.additionalMonthlyContribution == nil)
        #expect(lever.delayYears == nil)
        #expect(lever.spendingReductionMonthly == nil)
    }

    /// Delaying moves both sides — a longer horizon, but a bigger inflated need — so a
    /// near-miss plan should close within a few years rather than never.
    @Test
    func `a near miss plan closes by retiring a few years later`() throws {
        let need = RetirementNeedInput(
            currentAge: 40, retirementAge: 60, longevityAge: 90,
            monthlyCostOfLifeToday: 1200, expectedAnnualReturn: 0.07
        )
        let plan = ProjectionAssumptions(
            initialAmount: 50000,
            monthlyContribution: 550,
            annualReturnRate: 0.07,
            years: 20
        )

        let lever = try PlanningEngine.lever(need: need, plan: plan)
        #expect(lever.isOnTrack == false)
        let delay = try #require(lever.delayYears)

        #expect(delay >= 1)
        #expect(delay <= 15)

        let delayedNeed = need.with(retirementAge: 60 + delay)
        let delayedTarget = try PlanningEngine.retirementNeed(delayedNeed, projectedPortfolioAtRetirement: 0)
            .nestEggAtWithdrawalRate
        let delayedValue = try PlanningEngine.project(plan.with(years: 20 + delay)).endingValueNominal

        #expect(delayedValue >= delayedTarget)
    }

    @Test
    func `the spending reduction is expressed in today's money`() throws {
        let need = RetirementNeedInput(
            currentAge: 40, retirementAge: 60, longevityAge: 90,
            monthlyCostOfLifeToday: 2800, annualInflationRate: 0.02, expectedAnnualReturn: 0.07
        )
        let plan = ProjectionAssumptions(
            initialAmount: 10000,
            monthlyContribution: 400,
            annualReturnRate: 0.07,
            years: 20
        )

        let lever = try PlanningEngine.lever(need: need, plan: plan)
        let reduction = try #require(lever.spendingReductionMonthly)

        #expect(reduction > 0)
        #expect(reduction < 2800)
    }

    // MARK: Goal fields

    /// The defaults must reproduce the old behaviour exactly, or every existing goal's
    /// numbers move the moment these parameters are added.
    @Test
    func `omitting the new parameters leaves the closed form untouched`() {
        let withDefaults = PlanningEngine.futureValue(
            principal: 100_000, monthlyContribution: 1000, annualRate: 0.06, months: 120
        )

        #expect(abs(withDefaults - 341_558.21) < 0.01)
    }

    @Test
    func `contribution growth steps once a year, not every month`() {
        let level = PlanningEngine.futureValue(
            principal: 0, monthlyContribution: 100, annualRate: 0, months: 24
        )
        let growing = PlanningEngine.futureValue(
            principal: 0, monthlyContribution: 100, annualRate: 0, months: 24,
            annualContributionGrowthRate: 0.10
        )

        // First year at 100, second at 110, with no return in play.
        #expect(abs(level - 2400) < 0.000_001)
        #expect(abs(growing - (1200 + 1320)) < 0.000_001)
    }

    @Test
    func `growing contributions beat level ones over the same horizon`() {
        let level = PlanningEngine.futureValue(
            principal: 10000, monthlyContribution: 400, annualRate: 0.07, months: 240
        )
        let growing = PlanningEngine.futureValue(
            principal: 10000, monthlyContribution: 400, annualRate: 0.07, months: 240,
            annualContributionGrowthRate: 0.03
        )

        #expect(growing > level)
    }

    @Test
    func `a target in today's money is larger by the time it is due`() {
        let carried = PlanningEngine.inflatedTarget(50000, annualInflationRate: 0.02, months: 240)

        #expect(abs(carried - 50000 * pow(1.02, 20)) < 0.01)
    }

    @Test
    func `a target is unchanged when there is no inflation or no horizon`() {
        #expect(PlanningEngine.inflatedTarget(50000, annualInflationRate: 0, months: 240) == 50000)
        #expect(PlanningEngine.inflatedTarget(50000, annualInflationRate: 0.02, months: 0) == 50000)
    }

    /// The solve has to actually land on the target, growth and inflation included.
    @Test
    func `the required contribution reaches the inflated target`() throws {
        let required = try PlanningEngine.requiredMonthlyContribution(
            principal: 10000, target: 50000, annualRate: 0.06, months: 120,
            annualContributionGrowthRate: 0.03, annualInflationRate: 0.02
        )
        let reached = PlanningEngine.futureValue(
            principal: 10000, monthlyContribution: required, annualRate: 0.06, months: 120,
            annualContributionGrowthRate: 0.03
        )
        let goal = PlanningEngine.inflatedTarget(50000, annualInflationRate: 0.02, months: 120)

        #expect(abs(reached - goal) < 0.01)
    }

    @Test
    func `the required contribution still reaches a level target`() throws {
        let required = try PlanningEngine.requiredMonthlyContribution(
            principal: 10000, target: 50000, annualRate: 0.06, months: 120
        )
        let reached = PlanningEngine.futureValue(
            principal: 10000, monthlyContribution: required, annualRate: 0.06, months: 120
        )

        #expect(abs(reached - 50000) < 0.01)
    }

    @Test
    func `rising contributions lower what the first payment has to be`() throws {
        let level = try PlanningEngine.requiredMonthlyContribution(
            principal: 0, target: 100_000, annualRate: 0.06, months: 120
        )
        let growing = try PlanningEngine.requiredMonthlyContribution(
            principal: 0, target: 100_000, annualRate: 0.06, months: 120,
            annualContributionGrowthRate: 0.05
        )

        #expect(growing < level)
    }

    /// A target in today's money is a moving one, so reaching it takes longer.
    @Test
    func `an inflating target takes longer to catch`() throws {
        let level = try #require(PlanningEngine.monthsToTarget(
            principal: 10000, target: 50000, monthlyContribution: 300, annualRate: 0.06
        ))
        let inflating = try #require(PlanningEngine.monthsToTarget(
            principal: 10000, target: 50000, monthlyContribution: 300, annualRate: 0.06,
            annualInflationRate: 0.02
        ))

        #expect(inflating > level)
    }

    @Test
    func `a plan already past its target is there today`() {
        #expect(PlanningEngine.monthsToTarget(
            principal: 60000, target: 50000, monthlyContribution: 0, annualRate: 0.06
        ) == 0)
    }

    @Test
    func `a target that can never be reached reports no date`() {
        #expect(PlanningEngine.monthsToTarget(
            principal: 1000, target: 50000, monthlyContribution: 0, annualRate: 0
        ) == nil)
    }

    // MARK: Cost of life

    @Test
    func `cost of life totals its pillars and keeps housing as a subset`() {
        let cost = CostOfLife(
            monthlyByPillar: ["fundamentals": 1800, "futureYou": 600, "fun": 400],
            monthlyHousing: 900,
            housingEndsAtAge: 65
        )

        #expect(cost.monthlyTotal == 2800)
        #expect(cost.monthlyHousing < cost.monthlyTotal)
    }

    /// Pillar maps go over the wire as a JSON object keyed by string, matching
    /// `BudgetSnapshot.pillarActuals`. A dictionary keyed by a non-`String` type would encode
    /// as a JSON array and break the Go web client.
    @Test
    func `cost of life encodes its pillars as a keyed object`() throws {
        let cost = CostOfLife(monthlyByPillar: ["fundamentals": 1800], monthlyHousing: 900)
        let data = try JSONEncoder().encode(cost)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let pillars = try #require(object["monthlyByPillar"] as? [String: Any])

        #expect(pillars["fundamentals"] != nil)
    }
}
