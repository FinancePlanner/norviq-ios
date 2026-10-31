import Foundation

// MARK: - Growth projection

public struct GrowthProjectionRequest: Codable, Sendable, Equatable {
    public let assumptions: ProjectionAssumptions
    /// Defaults to 5% / 7% / 9% when omitted.
    public let sensitivityRates: [Double]?

    public init(assumptions: ProjectionAssumptions, sensitivityRates: [Double]? = nil) {
        self.assumptions = assumptions
        self.sensitivityRates = sensitivityRates
    }
}

public struct GrowthProjectionResponse: Codable, Sendable, Equatable {
    public let result: ProjectionResult
    public let sensitivity: [SensitivityPoint]
    /// Plain-language statement of what was assumed. Shown, never hidden.
    public let assumptionNotes: [String]

    public init(result: ProjectionResult, sensitivity: [SensitivityPoint], assumptionNotes: [String]) {
        self.result = result
        self.sensitivity = sensitivity
        self.assumptionNotes = assumptionNotes
    }
}

// MARK: - Pre-fill

/// What Norviq already knows, so the planning screens do not open on empty fields.
///
/// `monthlyCostOfLife` is `nil` rather than zero when there is no budget to read: a user with
/// no budget has an unknown cost of life, not a cost of life of zero, and the screen should
/// ask rather than quietly project a retirement that costs nothing.
public struct PlanningPrefill: Codable, Sendable, Equatable {
    public let currency: String
    public let portfolioValue: Double
    public let monthlyCostOfLife: Double?
    public let monthlyByPillar: [String: Double]
    public let monthlyHousing: Double?
    public let suggestedRetirementAge: Int?
    public let hasBudget: Bool
    public let hasPortfolio: Bool

    public init(
        currency: String,
        portfolioValue: Double,
        monthlyCostOfLife: Double? = nil,
        monthlyByPillar: [String: Double] = [:],
        monthlyHousing: Double? = nil,
        suggestedRetirementAge: Int? = nil,
        hasBudget: Bool,
        hasPortfolio: Bool
    ) {
        self.currency = currency
        self.portfolioValue = portfolioValue
        self.monthlyCostOfLife = monthlyCostOfLife
        self.monthlyByPillar = monthlyByPillar
        self.monthlyHousing = monthlyHousing
        self.suggestedRetirementAge = suggestedRetirementAge
        self.hasBudget = hasBudget
        self.hasPortfolio = hasPortfolio
    }
}

// MARK: - Retirement planning

public struct RetirementPlanningRequest: Codable, Sendable, Equatable {
    public let need: RetirementNeedInput
    public let plan: ProjectionAssumptions
    /// Runs the Monte Carlo for a readiness probability. Defaults to true.
    public let includeProbability: Bool?
    /// Annual volatility for the probability run. Defaults to 0.16.
    public let annualVolatility: Double?

    public init(
        need: RetirementNeedInput,
        plan: ProjectionAssumptions,
        includeProbability: Bool? = nil,
        annualVolatility: Double? = nil
    ) {
        self.need = need
        self.plan = plan
        self.includeProbability = includeProbability
        self.annualVolatility = annualVolatility
    }
}

public struct RetirementPlanningResponse: Codable, Sendable, Equatable {
    public let need: RetirementNeed
    public let lever: PlanLever
    public let projection: ProjectionResult
    public let projectedPortfolioAtRetirement: Double
    /// Share of Monte Carlo paths that last to longevity. `nil` when not requested.
    public let readinessProbability: Double?
    public let assumptionNotes: [String]

    public init(
        need: RetirementNeed,
        lever: PlanLever,
        projection: ProjectionResult,
        projectedPortfolioAtRetirement: Double,
        readinessProbability: Double? = nil,
        assumptionNotes: [String]
    ) {
        self.need = need
        self.lever = lever
        self.projection = projection
        self.projectedPortfolioAtRetirement = projectedPortfolioAtRetirement
        self.readinessProbability = readinessProbability
        self.assumptionNotes = assumptionNotes
    }
}

// MARK: - Saved scenarios

public enum PlanningScenarioKind: String, Codable, Sendable, CaseIterable {
    case growth
    case retirement
}

/// The stored body of a scenario. Persisted as a JSON blob, so every field is optional and
/// decoding tolerates blobs written by older versions.
public struct PlanningScenarioInput: Codable, Sendable, Equatable {
    public let growth: ProjectionAssumptions?
    public let retirement: RetirementNeedInput?

    public init(growth: ProjectionAssumptions? = nil, retirement: RetirementNeedInput? = nil) {
        self.growth = growth
        self.retirement = retirement
    }
}

public struct PlanningScenario: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let kind: PlanningScenarioKind
    public let isDefault: Bool
    public let input: PlanningScenarioInput
    public let createdAt: String
    public let updatedAt: String?

    public init(
        id: String,
        name: String,
        kind: PlanningScenarioKind,
        isDefault: Bool,
        input: PlanningScenarioInput,
        createdAt: String,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.isDefault = isDefault
        self.input = input
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct PlanningScenarioUpsertRequest: Codable, Sendable, Equatable {
    public let name: String
    public let kind: PlanningScenarioKind
    public let isDefault: Bool?
    public let input: PlanningScenarioInput

    public init(name: String, kind: PlanningScenarioKind, isDefault: Bool? = nil, input: PlanningScenarioInput) {
        self.name = name
        self.kind = kind
        self.isDefault = isDefault
        self.input = input
    }

    public func validate() throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, trimmed.count <= 60 else {
            throw PlanningValidationError.invalidScenarioName
        }
        switch kind {
        case .growth:
            guard let growth = input.growth else { throw PlanningValidationError.missingScenarioInput }
            try growth.validate()
        case .retirement:
            guard let retirement = input.retirement else { throw PlanningValidationError.missingScenarioInput }
            try retirement.validate()
        }
    }
}
