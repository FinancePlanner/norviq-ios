import Foundation

public enum TaxPriceQuality: String, Codable, Sendable {
    case fresh
    case stale
    case missing
}

public enum TaxDataQuality: String, Codable, Sendable {
    case verified
    case estimated
    case incomplete
}

public struct TaxLotDetail: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let openedAt: String
    public let eligibleQuantity: Decimal
    public let unitBasis: TaxMoney
    public let adjustedBasis: TaxMoney
    public let marketValue: TaxMoney
    public let unrealizedGainLoss: TaxMoney
    public let holdingPeriod: String
    public let dataQuality: TaxDataQuality

    public init(
        id: String,
        openedAt: String,
        eligibleQuantity: Decimal,
        unitBasis: TaxMoney,
        adjustedBasis: TaxMoney,
        marketValue: TaxMoney,
        unrealizedGainLoss: TaxMoney,
        holdingPeriod: String,
        dataQuality: TaxDataQuality
    ) {
        self.id = id
        self.openedAt = openedAt
        self.eligibleQuantity = eligibleQuantity
        self.unitBasis = unitBasis
        self.adjustedBasis = adjustedBasis
        self.marketValue = marketValue
        self.unrealizedGainLoss = unrealizedGainLoss
        self.holdingPeriod = holdingPeriod
        self.dataQuality = dataQuality
    }
}

public struct TaxReplacementCandidate: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        instrumentId
    }

    public let instrumentId: String
    public let symbol: String
    public let name: String?
    public let score: Decimal
    public let correlationScore: Decimal?
    public let volatilityScore: Decimal?
    public let allocationFitScore: Decimal?
    public let expenseEfficiencyScore: Decimal?
    public let expenseRatio: Decimal?
    public let confidence: Decimal
    public let catalogVersion: String
    public let reviewedAt: String
    public let reviewReference: String
    public let warnings: [String]

    public init(
        instrumentId: String,
        symbol: String,
        name: String? = nil,
        score: Decimal,
        correlationScore: Decimal? = nil,
        volatilityScore: Decimal? = nil,
        allocationFitScore: Decimal? = nil,
        expenseEfficiencyScore: Decimal? = nil,
        expenseRatio: Decimal? = nil,
        confidence: Decimal,
        catalogVersion: String,
        reviewedAt: String,
        reviewReference: String,
        warnings: [String] = []
    ) {
        self.instrumentId = instrumentId
        self.symbol = symbol
        self.name = name
        self.score = score
        self.correlationScore = correlationScore
        self.volatilityScore = volatilityScore
        self.allocationFitScore = allocationFitScore
        self.expenseEfficiencyScore = expenseEfficiencyScore
        self.expenseRatio = expenseRatio
        self.confidence = confidence
        self.catalogVersion = catalogVersion
        self.reviewedAt = reviewedAt
        self.reviewReference = reviewReference
        self.warnings = warnings
    }
}

public struct TaxDragComponent: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let yearToDate: TaxMoney
    public let projectedYearEnd: TaxMoney
    public let dataQuality: TaxDataQuality

    public init(
        id: String,
        label: String,
        yearToDate: TaxMoney,
        projectedYearEnd: TaxMoney,
        dataQuality: TaxDataQuality
    ) {
        self.id = id
        self.label = label
        self.yearToDate = yearToDate
        self.projectedYearEnd = projectedYearEnd
        self.dataQuality = dataQuality
    }
}

public struct TaxDragProjection: Codable, Sendable, Equatable {
    public let yearToDateTax: TaxMoney
    public let projectedYearEndTax: TaxMoney
    public let annualTaxDrag: TaxMoney
    public let taxCostRatio: Decimal?
    public let components: [TaxDragComponent]

    public init(
        yearToDateTax: TaxMoney,
        projectedYearEndTax: TaxMoney,
        annualTaxDrag: TaxMoney,
        taxCostRatio: Decimal? = nil,
        components: [TaxDragComponent] = []
    ) {
        self.yearToDateTax = yearToDateTax
        self.projectedYearEndTax = projectedYearEndTax
        self.annualTaxDrag = annualTaxDrag
        self.taxCostRatio = taxCostRatio
        self.components = components
    }
}

public struct TaxGoalImpact: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        goalId
    }

    public let goalId: String
    public let goalName: String
    public let currency: String
    public let benefitApplied: Decimal
    public let baselineCompletionDate: String?
    public let projectedCompletionDate: String?
    public let monthsSooner: Int?
    public let assumption: String

    public init(
        goalId: String,
        goalName: String,
        currency: String,
        benefitApplied: Decimal,
        baselineCompletionDate: String? = nil,
        projectedCompletionDate: String? = nil,
        monthsSooner: Int? = nil,
        assumption: String
    ) {
        self.goalId = goalId
        self.goalName = goalName
        self.currency = currency
        self.benefitApplied = benefitApplied
        self.baselineCompletionDate = baselineCompletionDate
        self.projectedCompletionDate = projectedCompletionDate
        self.monthsSooner = monthsSooner
        self.assumption = assumption
    }
}

public struct TaxAllocationChange: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        instrumentId
    }

    public let instrumentId: String
    public let symbol: String
    public let beforeWeight: Decimal
    public let afterWeight: Decimal

    public init(
        instrumentId: String,
        symbol: String,
        beforeWeight: Decimal,
        afterWeight: Decimal
    ) {
        self.instrumentId = instrumentId
        self.symbol = symbol
        self.beforeWeight = beforeWeight
        self.afterWeight = afterWeight
    }
}

public struct TaxAllocationImpact: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        portfolioId
    }

    public let portfolioId: String
    public let portfolioValue: TaxMoney
    public let maximumWeightChange: Decimal
    public let changes: [TaxAllocationChange]

    public init(
        portfolioId: String,
        portfolioValue: TaxMoney,
        maximumWeightChange: Decimal,
        changes: [TaxAllocationChange]
    ) {
        self.portfolioId = portfolioId
        self.portfolioValue = portfolioValue
        self.maximumWeightChange = maximumWeightChange
        self.changes = changes
    }
}

public enum TaxLocationLegSide: String, Codable, Sendable {
    case sell
    case buy
    case futureContribution = "future_contribution"
}

public struct TaxLocationLeg: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let accountId: String
    public let instrumentId: String
    public let symbol: String
    public let side: TaxLocationLegSide
    public let notional: TaxMoney

    public init(
        id: String,
        accountId: String,
        instrumentId: String,
        symbol: String,
        side: TaxLocationLegSide,
        notional: TaxMoney
    ) {
        self.id = id
        self.accountId = accountId
        self.instrumentId = instrumentId
        self.symbol = symbol
        self.side = side
        self.notional = notional
    }
}

public struct TaxLocationOpportunity: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let supportLevel: TaxSupportLevel
    public let title: String
    public let annualSavings: TaxMoney
    public let immediateTaxCost: TaxMoney
    public let breakEvenMonths: Int?
    public let confidence: Decimal
    public let legs: [TaxLocationLeg]
    public let warnings: [String]

    public init(
        id: String,
        supportLevel: TaxSupportLevel,
        title: String,
        annualSavings: TaxMoney,
        immediateTaxCost: TaxMoney,
        breakEvenMonths: Int? = nil,
        confidence: Decimal,
        legs: [TaxLocationLeg],
        warnings: [String] = []
    ) {
        self.id = id
        self.supportLevel = supportLevel
        self.title = title
        self.annualSavings = annualSavings
        self.immediateTaxCost = immediateTaxCost
        self.breakEvenMonths = breakEvenMonths
        self.confidence = confidence
        self.legs = legs
        self.warnings = warnings
    }
}

public enum TaxActionPlanKind: String, Codable, Sendable {
    case harvest
    case assetLocation = "asset_location"
}

public enum TaxActionPlanStatus: String, Codable, Sendable {
    case accepted
    case partiallyMatched = "partially_matched"
    case requiresReview = "requires_review"
    case completed
    case cancelled
}

public enum TaxActionLegStatus: String, Codable, Sendable {
    case planned
    case matched
    case completed
    case cancelled
}

public struct TaxActionLeg: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let accountId: String
    public let portfolioId: String?
    public let instrumentId: String
    public let symbol: String
    public let side: TaxLocationLegSide
    public let quantity: Decimal?
    public let notional: TaxMoney
    public let lotIds: [String]
    public let status: TaxActionLegStatus
    public let matchedTransactionId: String?

    public init(
        id: String,
        accountId: String,
        portfolioId: String? = nil,
        instrumentId: String,
        symbol: String,
        side: TaxLocationLegSide,
        quantity: Decimal? = nil,
        notional: TaxMoney,
        lotIds: [String] = [],
        status: TaxActionLegStatus = .planned,
        matchedTransactionId: String? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.portfolioId = portfolioId
        self.instrumentId = instrumentId
        self.symbol = symbol
        self.side = side
        self.quantity = quantity
        self.notional = notional
        self.lotIds = lotIds
        self.status = status
        self.matchedTransactionId = matchedTransactionId
    }
}

public struct TaxActionPlanTransitionRequest: Codable, Sendable, Equatable {
    public let status: TaxActionPlanStatus
    public let executedAt: String?
    public let confirmationNote: String?

    public init(
        status: TaxActionPlanStatus,
        executedAt: String? = nil,
        confirmationNote: String? = nil
    ) {
        self.status = status
        self.executedAt = executedAt
        self.confirmationNote = confirmationNote
    }
}

public struct TaxLocationScenarioRequest: Codable, Sendable, Equatable {
    public let taxYear: Int
    public let opportunityIds: [String]

    public init(taxYear: Int, opportunityIds: [String]) {
        self.taxYear = taxYear
        self.opportunityIds = opportunityIds
    }
}

public struct TaxLocationScenarioResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let createdAt: String
    public let opportunities: [TaxLocationOpportunity]
    public let annualSavings: TaxMoney
    public let immediateTaxCost: TaxMoney
    public let goalImpacts: [TaxGoalImpact]
    public let warnings: [String]
    public let assumptions: [String]

    public init(
        id: String,
        createdAt: String,
        opportunities: [TaxLocationOpportunity],
        annualSavings: TaxMoney,
        immediateTaxCost: TaxMoney,
        goalImpacts: [TaxGoalImpact] = [],
        warnings: [String] = [],
        assumptions: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.opportunities = opportunities
        self.annualSavings = annualSavings
        self.immediateTaxCost = immediateTaxCost
        self.goalImpacts = goalImpacts
        self.warnings = warnings
        self.assumptions = assumptions
    }
}

public struct TaxPlacementPlanRequest: Codable, Sendable, Equatable {
    public let scenarioId: String
    public let idempotencyKey: String

    public init(scenarioId: String, idempotencyKey: String) {
        self.scenarioId = scenarioId
        self.idempotencyKey = idempotencyKey
    }
}
