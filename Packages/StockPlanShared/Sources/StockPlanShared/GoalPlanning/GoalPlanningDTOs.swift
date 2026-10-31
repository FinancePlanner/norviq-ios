import Foundation

public enum FinancialGoalType: String, Codable, CaseIterable, Sendable {
    case retirement
    case homePurchase = "home_purchase"
    case financialIndependence = "financial_independence"
    case education
    case emergencyFund = "emergency_fund"
    case investmentTarget = "investment_target"
    case custom
}

public enum FinancialGoalStatus: String, Codable, CaseIterable, Sendable {
    case active
    case paused
    case completed
    case archived
}

public enum FinancialGoalRiskProfile: String, Codable, CaseIterable, Sendable {
    case conservative
    case moderate
    case aggressive

    public var defaultAnnualReturn: Double {
        switch self {
        case .conservative: 0.04
        case .moderate: 0.06
        case .aggressive: 0.08
        }
    }
}

public enum GoalExpenseCategoryRole: String, Codable, CaseIterable, Sendable {
    case observedContribution = "observed_contribution"
    case reductionCandidate = "reduction_candidate"
}

public enum GoalDriftState: String, Codable, CaseIterable, Sendable {
    case ahead
    case onTrack = "on_track"
    case behind
    case complete
    case insufficientData = "insufficient_data"
}

public enum GoalSuggestionKind: String, Codable, CaseIterable, Sendable {
    case increaseContribution = "increase_contribution"
    case reduceContribution = "reduce_contribution"
    case reduceSpending = "reduce_spending"
    case extendTargetDate = "extend_target_date"
    case rebalanceAllocation = "rebalance_allocation"
}

public enum GoalSuggestionStatus: String, Codable, CaseIterable, Sendable {
    case proposed
    case accepted
    case dismissed
}

public enum GoalAdjustmentDestination: String, Codable, CaseIterable, Sendable {
    case budget
    case rebalancing
    case goal
}

public struct GoalPortfolioAllocation: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let portfolioListId: String
    public let allocationPercentage: Double

    public init(id: String, portfolioListId: String, allocationPercentage: Double) {
        self.id = id
        self.portfolioListId = portfolioListId
        self.allocationPercentage = allocationPercentage
    }
}

public struct GoalExpenseCategoryLink: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let categoryId: String
    public let role: GoalExpenseCategoryRole

    public init(id: String, categoryId: String, role: GoalExpenseCategoryRole) {
        self.id = id
        self.categoryId = categoryId
        self.role = role
    }
}

public struct FinancialGoalInput: Codable, Equatable, Sendable {
    public let name: String
    public let goalType: FinancialGoalType
    public let targetAmount: Double
    public let targetDate: String
    public let baseCurrency: String
    public let startingCapital: Double
    public let monthlyContribution: Double
    public let annualContributionGrowth: Double
    public let inflationAssumption: Double
    public let riskProfile: FinancialGoalRiskProfile
    public let expectedAnnualReturn: Double?
    public let status: FinancialGoalStatus
    public let portfolioAllocations: [GoalPortfolioAllocation]
    public let expenseCategoryLinks: [GoalExpenseCategoryLink]

    public init(
        name: String,
        goalType: FinancialGoalType = .custom,
        targetAmount: Double,
        targetDate: String,
        baseCurrency: String,
        startingCapital: Double = 0,
        monthlyContribution: Double = 0,
        annualContributionGrowth: Double = 0,
        inflationAssumption: Double = 0.02,
        riskProfile: FinancialGoalRiskProfile = .moderate,
        expectedAnnualReturn: Double? = nil,
        status: FinancialGoalStatus = .active,
        portfolioAllocations: [GoalPortfolioAllocation] = [],
        expenseCategoryLinks: [GoalExpenseCategoryLink] = []
    ) {
        self.name = name
        self.goalType = goalType
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.baseCurrency = baseCurrency
        self.startingCapital = startingCapital
        self.monthlyContribution = monthlyContribution
        self.annualContributionGrowth = annualContributionGrowth
        self.inflationAssumption = inflationAssumption
        self.riskProfile = riskProfile
        self.expectedAnnualReturn = expectedAnnualReturn
        self.status = status
        self.portfolioAllocations = portfolioAllocations
        self.expenseCategoryLinks = expenseCategoryLinks
    }

    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScenarioValidationError.invalidName
        }
        guard baseCurrency.count == 3 else { throw ScenarioValidationError.invalidCurrency }
        guard targetAmount.isFinite, startingCapital.isFinite, monthlyContribution.isFinite,
              targetAmount > 0, startingCapital >= 0, monthlyContribution >= 0
        else {
            throw ScenarioValidationError.invalidAmount
        }
        guard annualContributionGrowth.isFinite, inflationAssumption.isFinite,
              (-1 ... 1).contains(annualContributionGrowth), (-1 ... 1).contains(inflationAssumption),
              expectedAnnualReturn.map({ $0.isFinite && (-0.5 ... 0.5).contains($0) }) ?? true
        else {
            throw ScenarioValidationError.invalidAmount
        }
        guard portfolioAllocations.allSatisfy({ ($0.allocationPercentage > 0) && $0.allocationPercentage <= 100 })
        else {
            throw GoalPlanningValidationError.invalidAllocation
        }
    }
}

public enum GoalPlanningValidationError: Error, Equatable, Sendable {
    case invalidAllocation
    case invalidHorizon
}

public struct FinancialGoal: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let portfolioListId: String
    public let goalType: FinancialGoalType
    public let targetAmount: Double
    public let targetDate: String
    public let baseCurrency: String
    public let startingCapital: Double
    public let monthlyContribution: Double
    public let annualContributionGrowth: Double
    public let inflationAssumption: Double
    public let riskProfile: FinancialGoalRiskProfile
    public let expectedAnnualReturn: Double
    public let status: FinancialGoalStatus
    public let portfolioAllocations: [GoalPortfolioAllocation]
    public let expenseCategoryLinks: [GoalExpenseCategoryLink]
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        name: String,
        portfolioListId: String,
        goalType: FinancialGoalType = .custom,
        targetAmount: Double,
        targetDate: String,
        baseCurrency: String,
        startingCapital: Double = 0,
        monthlyContribution: Double = 0,
        annualContributionGrowth: Double = 0,
        inflationAssumption: Double = 0.02,
        riskProfile: FinancialGoalRiskProfile = .moderate,
        expectedAnnualReturn: Double? = nil,
        status: FinancialGoalStatus = .active,
        portfolioAllocations: [GoalPortfolioAllocation] = [],
        expenseCategoryLinks: [GoalExpenseCategoryLink] = [],
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.portfolioListId = portfolioListId
        self.goalType = goalType
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.baseCurrency = baseCurrency
        self.startingCapital = startingCapital
        self.monthlyContribution = monthlyContribution
        self.annualContributionGrowth = annualContributionGrowth
        self.inflationAssumption = inflationAssumption
        self.riskProfile = riskProfile
        self.expectedAnnualReturn = expectedAnnualReturn ?? riskProfile.defaultAnnualReturn
        self.status = status
        self.portfolioAllocations = portfolioAllocations
        self.expenseCategoryLinks = expenseCategoryLinks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func validate() throws {
        try FinancialGoalInput(
            name: name,
            goalType: goalType,
            targetAmount: targetAmount,
            targetDate: targetDate,
            baseCurrency: baseCurrency,
            startingCapital: startingCapital,
            monthlyContribution: monthlyContribution,
            annualContributionGrowth: annualContributionGrowth,
            inflationAssumption: inflationAssumption,
            riskProfile: riskProfile,
            expectedAnnualReturn: expectedAnnualReturn,
            status: status,
            portfolioAllocations: portfolioAllocations,
            expenseCategoryLinks: expenseCategoryLinks
        ).validate()
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, portfolioListId, goalType, targetAmount, targetDate, baseCurrency
        case startingCapital, monthlyContribution, annualContributionGrowth, inflationAssumption
        case riskProfile, expectedAnnualReturn, status, portfolioAllocations, expenseCategoryLinks
        case createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let riskProfile = try values.decodeIfPresent(FinancialGoalRiskProfile.self, forKey: .riskProfile) ?? .moderate
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        portfolioListId = try values.decode(String.self, forKey: .portfolioListId)
        goalType = try values.decodeIfPresent(FinancialGoalType.self, forKey: .goalType) ?? .custom
        targetAmount = try values.decode(Double.self, forKey: .targetAmount)
        targetDate = try values.decode(String.self, forKey: .targetDate)
        baseCurrency = try values.decode(String.self, forKey: .baseCurrency)
        startingCapital = try values.decodeIfPresent(Double.self, forKey: .startingCapital) ?? 0
        monthlyContribution = try values.decodeIfPresent(Double.self, forKey: .monthlyContribution) ?? 0
        annualContributionGrowth = try values.decodeIfPresent(Double.self, forKey: .annualContributionGrowth) ?? 0
        inflationAssumption = try values.decodeIfPresent(Double.self, forKey: .inflationAssumption) ?? 0.02
        self.riskProfile = riskProfile
        expectedAnnualReturn = try values.decodeIfPresent(Double.self, forKey: .expectedAnnualReturn)
            ?? riskProfile.defaultAnnualReturn
        status = try values.decodeIfPresent(FinancialGoalStatus.self, forKey: .status) ?? .active
        portfolioAllocations = try values.decodeIfPresent(
            [GoalPortfolioAllocation].self,
            forKey: .portfolioAllocations
        ) ?? []
        expenseCategoryLinks = try values.decodeIfPresent(
            [GoalExpenseCategoryLink].self,
            forKey: .expenseCategoryLinks
        ) ?? []
        createdAt = try values.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try values.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

public struct GoalContributionInput: Codable, Equatable, Sendable {
    public let amount: Double
    public let occurredAt: String
    public let note: String?

    public init(amount: Double, occurredAt: String, note: String? = nil) {
        self.amount = amount
        self.occurredAt = occurredAt
        self.note = note
    }
}

public struct GoalContribution: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let goalId: String
    public let amount: Double
    public let occurredAt: String
    public let note: String?
    public let createdAt: String

    public init(
        id: String,
        goalId: String,
        amount: Double,
        occurredAt: String,
        note: String? = nil,
        createdAt: String
    ) {
        self.id = id
        self.goalId = goalId
        self.amount = amount
        self.occurredAt = occurredAt
        self.note = note
        self.createdAt = createdAt
    }
}

public struct GoalTrajectoryPoint: Codable, Equatable, Identifiable, Sendable {
    public var id: String {
        date
    }

    public let date: String
    public let plannedValue: Double
    public let actualValue: Double?
    public let projectedValue: Double

    public init(date: String, plannedValue: Double, actualValue: Double? = nil, projectedValue: Double) {
        self.date = date
        self.plannedValue = plannedValue
        self.actualValue = actualValue
        self.projectedValue = projectedValue
    }
}

public struct GoalProgress: Codable, Equatable, Sendable {
    public let goalId: String
    public let currency: String
    public let currentValue: Double
    public let targetAmount: Double
    public let percentComplete: Double
    public let plannedValueToday: Double
    public let projectedValueAtTarget: Double
    public let projectedCompletionDate: String?
    public let driftAmount: Double
    public let driftMonths: Int?
    public let driftState: GoalDriftState
    public let plannedMonthlyContribution: Double
    public let observedMonthlyContribution: Double
    public let trajectory: [GoalTrajectoryPoint]
    public let warnings: [String]
    public let calculatedAt: String

    public init(
        goalId: String,
        currency: String,
        currentValue: Double,
        targetAmount: Double,
        percentComplete: Double,
        plannedValueToday: Double,
        projectedValueAtTarget: Double,
        projectedCompletionDate: String?,
        driftAmount: Double,
        driftMonths: Int?,
        driftState: GoalDriftState,
        plannedMonthlyContribution: Double,
        observedMonthlyContribution: Double,
        trajectory: [GoalTrajectoryPoint],
        warnings: [String] = [],
        calculatedAt: String
    ) {
        self.goalId = goalId
        self.currency = currency
        self.currentValue = currentValue
        self.targetAmount = targetAmount
        self.percentComplete = percentComplete
        self.plannedValueToday = plannedValueToday
        self.projectedValueAtTarget = projectedValueAtTarget
        self.projectedCompletionDate = projectedCompletionDate
        self.driftAmount = driftAmount
        self.driftMonths = driftMonths
        self.driftState = driftState
        self.plannedMonthlyContribution = plannedMonthlyContribution
        self.observedMonthlyContribution = observedMonthlyContribution
        self.trajectory = trajectory
        self.warnings = warnings
        self.calculatedAt = calculatedAt
    }
}

public struct GoalOverviewItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let goal: FinancialGoal
    public let progress: GoalProgress

    public init(goal: FinancialGoal, progress: GoalProgress) {
        id = goal.id
        self.goal = goal
        self.progress = progress
    }
}

public struct GoalOverview: Codable, Equatable, Sendable {
    public let items: [GoalOverviewItem]
    public let totalCurrentValue: Double
    public let totalTargetAmount: Double
    public let activeGoalCount: Int
    public let activeGoalLimit: Int?
    public let isPro: Bool

    public init(
        items: [GoalOverviewItem],
        totalCurrentValue: Double,
        totalTargetAmount: Double,
        activeGoalCount: Int,
        activeGoalLimit: Int?,
        isPro: Bool
    ) {
        self.items = items
        self.totalCurrentValue = totalCurrentValue
        self.totalTargetAmount = totalTargetAmount
        self.activeGoalCount = activeGoalCount
        self.activeGoalLimit = activeGoalLimit
        self.isPro = isPro
    }
}

public struct GoalWhatIfRequest: Codable, Equatable, Sendable {
    public let monthlyContribution: Double?
    public let expectedAnnualReturn: Double?
    public let targetDate: String?

    public init(monthlyContribution: Double? = nil, expectedAnnualReturn: Double? = nil, targetDate: String? = nil) {
        self.monthlyContribution = monthlyContribution
        self.expectedAnnualReturn = expectedAnnualReturn
        self.targetDate = targetDate
    }
}

public struct GoalWhatIfResponse: Codable, Equatable, Sendable {
    public let baseline: GoalProgress
    public let scenario: GoalProgress

    public init(baseline: GoalProgress, scenario: GoalProgress) {
        self.baseline = baseline
        self.scenario = scenario
    }
}

public struct GoalSuggestion: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let goalId: String
    public let kind: GoalSuggestionKind
    public let title: String
    public let explanation: String
    public let monthlyAmount: Double?
    public let allocationPercentage: Double?
    public let estimatedMonthsChanged: Int?
    public let status: GoalSuggestionStatus
    public let createdAt: String

    public init(
        id: String,
        goalId: String,
        kind: GoalSuggestionKind,
        title: String,
        explanation: String,
        monthlyAmount: Double? = nil,
        allocationPercentage: Double? = nil,
        estimatedMonthsChanged: Int? = nil,
        status: GoalSuggestionStatus = .proposed,
        createdAt: String
    ) {
        self.id = id
        self.goalId = goalId
        self.kind = kind
        self.title = title
        self.explanation = explanation
        self.monthlyAmount = monthlyAmount
        self.allocationPercentage = allocationPercentage
        self.estimatedMonthsChanged = estimatedMonthsChanged
        self.status = status
        self.createdAt = createdAt
    }
}

public struct GoalAdjustmentDraft: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let suggestionId: String
    public let destination: GoalAdjustmentDestination
    public let payload: [String: String]
    public let createdAt: String

    public init(
        id: String,
        suggestionId: String,
        destination: GoalAdjustmentDestination,
        payload: [String: String],
        createdAt: String
    ) {
        self.id = id
        self.suggestionId = suggestionId
        self.destination = destination
        self.payload = payload
        self.createdAt = createdAt
    }
}

public struct GoalTemplate: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let goalType: FinancialGoalType
    public let suggestedYears: Int
    public let riskProfile: FinancialGoalRiskProfile

    public init(
        id: String,
        name: String,
        goalType: FinancialGoalType,
        suggestedYears: Int,
        riskProfile: FinancialGoalRiskProfile
    ) {
        self.id = id
        self.name = name
        self.goalType = goalType
        self.suggestedYears = suggestedYears
        self.riskProfile = riskProfile
    }
}

public struct FinancialGoalBulkUpdate: Codable, Equatable, Sendable {
    public let goalIds: [String]
    public let status: FinancialGoalStatus

    public init(goalIds: [String], status: FinancialGoalStatus) {
        self.goalIds = goalIds
        self.status = status
    }
}
