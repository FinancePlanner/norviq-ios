import Foundation

// MARK: - Validation

public enum PlanningValidationError: Error, Equatable, Sendable {
    case invalidHorizon
    case invalidReturnRate
    case invalidInflationRate
    case invalidWithdrawalRate
    case invalidAges
    case invalidScenarioName
    case missingScenarioInput
}

// MARK: - Growth projection

/// Inputs for an investment growth projection.
///
/// `annualReturnRate` and `annualInflationRate` are annual *effective* rates, matching
/// ``PlanningEngine/monthlyRate(annualRate:)``. Contributions are made at the end of each
/// month (ordinary annuity) and step up once a year by `annualContributionGrowthRate`, so
/// the first year always contributes `monthlyContribution`.
public struct ProjectionAssumptions: Codable, Sendable, Equatable {
    public let initialAmount: Double
    public let monthlyContribution: Double
    public let annualReturnRate: Double
    public let annualContributionGrowthRate: Double
    public let annualInflationRate: Double
    public let years: Int

    public init(
        initialAmount: Double,
        monthlyContribution: Double,
        annualReturnRate: Double,
        annualContributionGrowthRate: Double = 0,
        annualInflationRate: Double = 0.02,
        years: Int
    ) {
        self.initialAmount = initialAmount
        self.monthlyContribution = monthlyContribution
        self.annualReturnRate = annualReturnRate
        self.annualContributionGrowthRate = annualContributionGrowthRate
        self.annualInflationRate = annualInflationRate
        self.years = years
    }

    public func validate() throws {
        guard years >= 0, years <= 100 else { throw PlanningValidationError.invalidHorizon }
        guard annualReturnRate > -1 else { throw PlanningValidationError.invalidReturnRate }
        guard annualInflationRate > -1 else { throw PlanningValidationError.invalidInflationRate }
    }

    /// A copy of these assumptions with a different return rate, used by the sensitivity row.
    public func with(annualReturnRate rate: Double) -> ProjectionAssumptions {
        ProjectionAssumptions(
            initialAmount: initialAmount,
            monthlyContribution: monthlyContribution,
            annualReturnRate: rate,
            annualContributionGrowthRate: annualContributionGrowthRate,
            annualInflationRate: annualInflationRate,
            years: years
        )
    }

    /// A copy of these assumptions over a different horizon, used when solving for a delay.
    public func with(years value: Int) -> ProjectionAssumptions {
        ProjectionAssumptions(
            initialAmount: initialAmount,
            monthlyContribution: monthlyContribution,
            annualReturnRate: annualReturnRate,
            annualContributionGrowthRate: annualContributionGrowthRate,
            annualInflationRate: annualInflationRate,
            years: value
        )
    }
}

/// One row of the year-by-year projection table. `yearIndex` 0 is today.
public struct ProjectionYear: Codable, Sendable, Equatable, Identifiable {
    public var id: Int {
        yearIndex
    }

    public let yearIndex: Int
    public let contributedThisYear: Double
    public let cumulativeContributions: Double
    public let endingBalanceNominal: Double
    public let endingBalanceReal: Double
    public let growthToDate: Double

    public init(
        yearIndex: Int,
        contributedThisYear: Double,
        cumulativeContributions: Double,
        endingBalanceNominal: Double,
        endingBalanceReal: Double,
        growthToDate: Double
    ) {
        self.yearIndex = yearIndex
        self.contributedThisYear = contributedThisYear
        self.cumulativeContributions = cumulativeContributions
        self.endingBalanceNominal = endingBalanceNominal
        self.endingBalanceReal = endingBalanceReal
        self.growthToDate = growthToDate
    }
}

public struct ProjectionResult: Codable, Sendable, Equatable {
    public let assumptions: ProjectionAssumptions
    public let years: [ProjectionYear]
    public let endingValueNominal: Double
    public let endingValueReal: Double
    public let totalContributed: Double
    public let totalGrowth: Double

    public init(
        assumptions: ProjectionAssumptions,
        years: [ProjectionYear],
        endingValueNominal: Double,
        endingValueReal: Double,
        totalContributed: Double,
        totalGrowth: Double
    ) {
        self.assumptions = assumptions
        self.years = years
        self.endingValueNominal = endingValueNominal
        self.endingValueReal = endingValueReal
        self.totalContributed = totalContributed
        self.totalGrowth = totalGrowth
    }
}

public struct SensitivityPoint: Codable, Sendable, Equatable, Identifiable {
    public var id: Double {
        annualReturnRate
    }

    public let annualReturnRate: Double
    public let endingValueNominal: Double
    public let endingValueReal: Double

    public init(annualReturnRate: Double, endingValueNominal: Double, endingValueReal: Double) {
        self.annualReturnRate = annualReturnRate
        self.endingValueNominal = endingValueNominal
        self.endingValueReal = endingValueReal
    }
}

// MARK: - Cost of life

/// The user's cost of life, expressed in today's money.
///
/// `monthlyByPillar` is keyed by ``BudgetPillar`` `rawValue` rather than by the pillar type,
/// because the wire format for pillar maps elsewhere in the API is a JSON object keyed by
/// string (see `BudgetSnapshot.pillarActuals`). A dictionary keyed by a non-`String` type
/// would encode as a JSON array and break the Go web client.
///
/// `monthlyHousing` is a *subset* of the pillar totals, not an addition to them — it is
/// carved out so it can stop at `housingEndsAtAge` (a mortgage being paid off) while the
/// pillar totals still reconcile with the expenses screens.
public struct CostOfLife: Codable, Sendable, Equatable {
    public let monthlyByPillar: [String: Double]
    public let monthlyHousing: Double
    public let housingEndsAtAge: Int?

    public init(monthlyByPillar: [String: Double], monthlyHousing: Double = 0, housingEndsAtAge: Int? = nil) {
        self.monthlyByPillar = monthlyByPillar
        self.monthlyHousing = monthlyHousing
        self.housingEndsAtAge = housingEndsAtAge
    }

    public var monthlyTotal: Double {
        monthlyByPillar.values.reduce(0, +)
    }
}

// MARK: - Retirement need

public struct RetirementNeedInput: Codable, Sendable, Equatable {
    public let currentAge: Int
    public let retirementAge: Int
    public let longevityAge: Int
    public let monthlyCostOfLifeToday: Double
    public let monthlyHousingToday: Double
    public let housingEndsAtAge: Int?
    public let monthlyOtherIncomeAtRetirement: Double
    public let annualInflationRate: Double
    public let withdrawalRate: Double
    public let expectedAnnualReturn: Double

    public init(
        currentAge: Int,
        retirementAge: Int,
        longevityAge: Int,
        monthlyCostOfLifeToday: Double,
        monthlyHousingToday: Double = 0,
        housingEndsAtAge: Int? = nil,
        monthlyOtherIncomeAtRetirement: Double = 0,
        annualInflationRate: Double = 0.02,
        withdrawalRate: Double = 0.04,
        expectedAnnualReturn: Double
    ) {
        self.currentAge = currentAge
        self.retirementAge = retirementAge
        self.longevityAge = longevityAge
        self.monthlyCostOfLifeToday = monthlyCostOfLifeToday
        self.monthlyHousingToday = monthlyHousingToday
        self.housingEndsAtAge = housingEndsAtAge
        self.monthlyOtherIncomeAtRetirement = monthlyOtherIncomeAtRetirement
        self.annualInflationRate = annualInflationRate
        self.withdrawalRate = withdrawalRate
        self.expectedAnnualReturn = expectedAnnualReturn
    }

    public var yearsToRetirement: Int {
        max(0, retirementAge - currentAge)
    }

    public func validate() throws {
        guard currentAge >= 18, currentAge < 100 else { throw PlanningValidationError.invalidAges }
        guard retirementAge > currentAge, retirementAge <= 100 else { throw PlanningValidationError.invalidAges }
        guard longevityAge > retirementAge, longevityAge <= 120 else { throw PlanningValidationError.invalidAges }
        guard withdrawalRate > 0, withdrawalRate <= 0.20 else { throw PlanningValidationError.invalidWithdrawalRate }
        guard annualInflationRate > -1 else { throw PlanningValidationError.invalidInflationRate }
        guard expectedAnnualReturn > -1 else { throw PlanningValidationError.invalidReturnRate }
    }

    public func with(retirementAge value: Int) -> RetirementNeedInput {
        RetirementNeedInput(
            currentAge: currentAge,
            retirementAge: value,
            longevityAge: max(longevityAge, value + 1),
            monthlyCostOfLifeToday: monthlyCostOfLifeToday,
            monthlyHousingToday: monthlyHousingToday,
            housingEndsAtAge: housingEndsAtAge,
            monthlyOtherIncomeAtRetirement: monthlyOtherIncomeAtRetirement,
            annualInflationRate: annualInflationRate,
            withdrawalRate: withdrawalRate,
            expectedAnnualReturn: expectedAnnualReturn
        )
    }
}

/// One year of the retirement depletion run.
public struct DepletionYear: Codable, Sendable, Equatable, Identifiable {
    public var id: Int {
        age
    }

    public let age: Int
    public let annualSpending: Double
    public let endingBalance: Double

    public init(age: Int, annualSpending: Double, endingBalance: Double) {
        self.age = age
        self.annualSpending = annualSpending
        self.endingBalance = endingBalance
    }
}

public struct RetirementNeed: Codable, Sendable, Equatable {
    /// Annual spending in the first year of retirement, in nominal money of that year.
    public let annualSpendingAtRetirement: Double
    /// The familiar `S / w` headline.
    public let nestEggAtWithdrawalRate: Double
    /// The year-by-year run the verdict actually comes from.
    public let depletion: [DepletionYear]
    public let runwayYears: Int
    public let endingBalance: Double
    public let shortfallAge: Int?

    public init(
        annualSpendingAtRetirement: Double,
        nestEggAtWithdrawalRate: Double,
        depletion: [DepletionYear],
        runwayYears: Int,
        endingBalance: Double,
        shortfallAge: Int?
    ) {
        self.annualSpendingAtRetirement = annualSpendingAtRetirement
        self.nestEggAtWithdrawalRate = nestEggAtWithdrawalRate
        self.depletion = depletion
        self.runwayYears = runwayYears
        self.endingBalance = endingBalance
        self.shortfallAge = shortfallAge
    }

    public var lastsToLongevity: Bool {
        shortfallAge == nil
    }
}

/// The exact lever. A calculator that only reports a gap is forgettable; this says what to do
/// about it. Every field is `nil` when the plan is already on track.
public struct PlanLever: Codable, Sendable, Equatable {
    /// Positive means short by this much; zero or negative means on track.
    public let gap: Double
    public let additionalMonthlyContribution: Double?
    public let delayYears: Int?
    public let spendingReductionMonthly: Double?

    public init(
        gap: Double,
        additionalMonthlyContribution: Double? = nil,
        delayYears: Int? = nil,
        spendingReductionMonthly: Double? = nil
    ) {
        self.gap = gap
        self.additionalMonthlyContribution = additionalMonthlyContribution
        self.delayYears = delayYears
        self.spendingReductionMonthly = spendingReductionMonthly
    }

    public var isOnTrack: Bool {
        gap <= 0
    }
}

// MARK: - Engine

/// Shared planning math. Deterministic and dependency-free, so the backend and the iOS app
/// compute identical numbers and iOS can drive sliders without a round trip.
///
/// Rates are annual *effective* rates throughout: a monthly rate is
/// `(1 + annual) ^ (1/12) - 1`, never `annual / 12`.
public enum PlanningEngine {
    // MARK: Closed form (unchanged; goals depend on these)

    public static func monthlyRate(annualRate: Double) -> Double {
        pow(1 + annualRate, 1.0 / 12.0) - 1
    }

    /// Future value of a plan.
    ///
    /// `annualContributionGrowthRate` steps the contribution once every twelve months, so the
    /// first year always pays `monthlyContribution`. At zero it takes the closed form; above
    /// zero it walks the months, because an annual step against monthly compounding has no
    /// clean closed form. A test pins the two together at zero so they cannot drift apart.
    public static func futureValue(
        principal: Double,
        monthlyContribution: Double,
        annualRate: Double,
        months: Int,
        annualContributionGrowthRate: Double = 0
    ) -> Double {
        guard months > 0 else { return principal }
        let rate = monthlyRate(annualRate: annualRate)

        guard abs(annualContributionGrowthRate) > 0.000_000_001 else {
            guard abs(rate) > 0.000_000_001 else {
                return principal + monthlyContribution * Double(months)
            }
            let growth = pow(1 + rate, Double(months))
            return principal * growth + monthlyContribution * ((growth - 1) / rate)
        }

        var balance = principal
        var contribution = monthlyContribution
        for month in 1 ... months {
            balance *= 1 + rate
            balance += contribution
            if month % 12 == 0 {
                contribution *= 1 + annualContributionGrowthRate
            }
        }
        return balance
    }

    /// A target stated in today's money, carried forward to the horizon.
    ///
    /// Norviq treats a goal's target as today's buying power: "50,000 in twenty years" means
    /// 50,000 of what money buys now, so the number to actually hit is larger.
    public static func inflatedTarget(_ target: Double, annualInflationRate: Double, months: Int) -> Double {
        guard months > 0, abs(annualInflationRate) > 0.000_000_001 else { return target }
        return target * pow(1 + annualInflationRate, Double(months) / 12)
    }

    /// The contribution needed to reach a target, which may itself be inflating.
    ///
    /// Future value is linear in the contribution for a fixed growth rate, so the annuity
    /// factor is recovered by projecting a contribution of exactly 1 with no principal. That
    /// keeps this exact rather than iterative even when contributions grow.
    public static func requiredMonthlyContribution(
        principal: Double,
        target: Double,
        annualRate: Double,
        months: Int,
        annualContributionGrowthRate: Double = 0,
        annualInflationRate: Double = 0
    ) throws -> Double {
        guard months > 0 else { throw GoalPlanningValidationError.invalidHorizon }
        let goal = inflatedTarget(target, annualInflationRate: annualInflationRate, months: months)
        let rate = monthlyRate(annualRate: annualRate)
        let grown = principal * pow(1 + rate, Double(months))

        let factor = futureValue(
            principal: 0, monthlyContribution: 1, annualRate: annualRate, months: months,
            annualContributionGrowthRate: annualContributionGrowthRate
        )
        guard factor > 0.000_000_001 else { return 0 }
        return max(0, (goal - grown) / factor)
    }

    /// How many months until the plan overtakes the target.
    ///
    /// When the target is stated in today's money it moves as well, so each month is compared
    /// against the target as it will stand *that* month rather than against a fixed number.
    public static func monthsToTarget(
        principal: Double,
        target: Double,
        monthlyContribution: Double,
        annualRate: Double,
        maximumMonths: Int = 1200,
        annualContributionGrowthRate: Double = 0,
        annualInflationRate: Double = 0
    ) -> Int? {
        if principal >= inflatedTarget(target, annualInflationRate: annualInflationRate, months: 0) {
            return 0
        }
        guard monthlyContribution > 0 || annualRate > 0 else { return nil }
        return (1 ... maximumMonths).first { month in
            let goal = inflatedTarget(target, annualInflationRate: annualInflationRate, months: month)
            let value = futureValue(
                principal: principal, monthlyContribution: monthlyContribution,
                annualRate: annualRate, months: month,
                annualContributionGrowthRate: annualContributionGrowthRate
            )
            return value >= goal
        }
    }

    // MARK: Growth projection

    /// Projects a plan month by month and reports it year by year.
    ///
    /// This is a schedule loop rather than the growing-annuity closed form on purpose:
    /// contributions step once a year while interest compounds monthly, which has no clean
    /// closed form, and the loop has no `r == g` singularity to guard against. With at most
    /// 1200 months the cost is irrelevant. When `annualContributionGrowthRate` is 0 it
    /// reproduces ``futureValue(principal:monthlyContribution:annualRate:months:)`` exactly,
    /// which is enforced by test.
    public static func project(_ assumptions: ProjectionAssumptions) throws -> ProjectionResult {
        try assumptions.validate()

        let rate = monthlyRate(annualRate: assumptions.annualReturnRate)
        var balance = assumptions.initialAmount
        var contribution = assumptions.monthlyContribution
        var cumulativeContributions = assumptions.initialAmount

        var rows = [ProjectionYear(
            yearIndex: 0,
            contributedThisYear: 0,
            cumulativeContributions: cumulativeContributions,
            endingBalanceNominal: balance,
            endingBalanceReal: balance,
            growthToDate: 0
        )]
        rows.reserveCapacity(assumptions.years + 1)

        for year in 1 ... max(assumptions.years, 1) where assumptions.years > 0 {
            var contributedThisYear = 0.0
            for _ in 1 ... 12 {
                balance *= 1 + rate
                balance += contribution
                contributedThisYear += contribution
            }
            cumulativeContributions += contributedThisYear
            let deflator = pow(1 + assumptions.annualInflationRate, Double(year))
            rows.append(ProjectionYear(
                yearIndex: year,
                contributedThisYear: contributedThisYear,
                cumulativeContributions: cumulativeContributions,
                endingBalanceNominal: balance,
                endingBalanceReal: balance / deflator,
                growthToDate: balance - cumulativeContributions
            ))
            contribution *= 1 + assumptions.annualContributionGrowthRate
        }

        let last = rows[rows.count - 1]
        return ProjectionResult(
            assumptions: assumptions,
            years: rows,
            endingValueNominal: last.endingBalanceNominal,
            endingValueReal: last.endingBalanceReal,
            totalContributed: last.cumulativeContributions,
            totalGrowth: last.endingBalanceNominal - last.cumulativeContributions
        )
    }

    /// "If the return is 5% / 7% / 9%" — the honest companion to a single projected number.
    public static func sensitivity(
        _ assumptions: ProjectionAssumptions,
        rates: [Double] = [0.05, 0.07, 0.09]
    ) throws -> [SensitivityPoint] {
        try rates.map { rate in
            let result = try project(assumptions.with(annualReturnRate: rate))
            return SensitivityPoint(
                annualReturnRate: rate,
                endingValueNominal: result.endingValueNominal,
                endingValueReal: result.endingValueReal
            )
        }
    }

    // MARK: Retirement need

    /// Turns a cost of life into a target number, then runs it down year by year.
    ///
    /// The `S / w` nest egg is reported because it is the number people recognise, but the
    /// verdict — runway, shortfall age — comes from the depletion run, which is the only one
    /// of the two that can express housing ending at a mortgage payoff.
    public static func retirementNeed(
        _ input: RetirementNeedInput,
        projectedPortfolioAtRetirement: Double
    ) throws -> RetirementNeed {
        try input.validate()

        let years = Double(input.yearsToRetirement)
        let annualCostToday = input.monthlyCostOfLifeToday * 12
        let annualHousingToday = input.monthlyHousingToday * 12
        let annualOtherIncomeToday = input.monthlyOtherIncomeAtRetirement * 12
        let inflationAtRetirement = pow(1 + input.annualInflationRate, years)

        // S = (L - I_other) * (1 + i)^y
        let spendingAtRetirement = max(0, annualCostToday - annualOtherIncomeToday) * inflationAtRetirement
        let nestEgg = spendingAtRetirement / input.withdrawalRate

        var balance = projectedPortfolioAtRetirement
        var depletion = [DepletionYear]()
        var shortfallAge: Int?
        var runway = 0

        for age in input.retirementAge ..< input.longevityAge {
            let offset = Double(age - input.retirementAge)
            let inflationFactor = pow(1 + input.annualInflationRate, years + offset)

            var annualToday = annualCostToday - annualOtherIncomeToday
            if let end = input.housingEndsAtAge, age >= end {
                annualToday -= annualHousingToday
            }
            let annualSpending = max(0, annualToday) * inflationFactor

            balance = balance * (1 + input.expectedAnnualReturn) - annualSpending
            depletion.append(DepletionYear(age: age, annualSpending: annualSpending, endingBalance: max(0, balance)))

            if balance <= 0 {
                shortfallAge = age
                balance = 0
                break
            }
            runway += 1
        }

        return RetirementNeed(
            annualSpendingAtRetirement: spendingAtRetirement,
            nestEggAtWithdrawalRate: nestEgg,
            depletion: depletion,
            runwayYears: runway,
            endingBalance: max(0, balance),
            shortfallAge: shortfallAge
        )
    }

    // MARK: The lever

    /// Solves the gap into the three moves a user can actually make: save more, retire later,
    /// or spend less. Both sides of the delay move — a longer horizon but a bigger inflated
    /// need — so it is solved by iteration rather than in closed form.
    ///
    /// `additionalMonthlyContribution` assumes level contributions for the solve; when
    /// `annualContributionGrowthRate` is non-zero it is a slight over-estimate of what is
    /// needed, which is the safe direction to err.
    public static func lever(
        need input: RetirementNeedInput,
        plan: ProjectionAssumptions,
        maximumDelayYears: Int = 15
    ) throws -> PlanLever {
        try input.validate()
        try plan.validate()

        let target = try retirementNeed(input, projectedPortfolioAtRetirement: 0).nestEggAtWithdrawalRate
        let projected = try project(plan).endingValueNominal
        let gap = target - projected
        guard gap > 0 else { return PlanLever(gap: gap) }

        let months = input.yearsToRetirement * 12
        var additional: Double?
        if months > 0 {
            let required = try requiredMonthlyContribution(
                principal: plan.initialAmount,
                target: target,
                annualRate: plan.annualReturnRate,
                months: months
            )
            additional = max(0, required - plan.monthlyContribution)
        }

        var delay: Int?
        for candidate in 1 ... maximumDelayYears {
            let delayedInput = input.with(retirementAge: input.retirementAge + candidate)
            let delayedTarget = try retirementNeed(delayedInput, projectedPortfolioAtRetirement: 0)
                .nestEggAtWithdrawalRate
            let delayedProjection = try project(plan.with(years: plan.years + candidate)).endingValueNominal
            if delayedProjection >= delayedTarget {
                delay = candidate
                break
            }
        }

        let sustainableSpendingAtRetirement = projected * input.withdrawalRate
        let shortfallAnnualAtRetirement = max(0, input.annualSpendingShortfall(
            spendingAtRetirement: target * input.withdrawalRate,
            sustainable: sustainableSpendingAtRetirement
        ))
        let deflator = pow(1 + input.annualInflationRate, Double(input.yearsToRetirement))
        let reductionMonthly = shortfallAnnualAtRetirement / deflator / 12

        return PlanLever(
            gap: gap,
            additionalMonthlyContribution: additional,
            delayYears: delay,
            spendingReductionMonthly: reductionMonthly > 0 ? reductionMonthly : nil
        )
    }
}

private extension RetirementNeedInput {
    func annualSpendingShortfall(spendingAtRetirement: Double, sustainable: Double) -> Double {
        spendingAtRetirement - sustainable
    }
}

// MARK: - Compatibility

@available(*, deprecated, renamed: "PlanningEngine")
public typealias GoalProjectionCalculator = PlanningEngine
