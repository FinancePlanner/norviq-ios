import Foundation

public enum RetirementWrapperKind: String, Codable, Sendable, CaseIterable {
    case taxable
    case us401k = "us_401k"
    case us403b = "us_403b"
    case traditionalIRA = "traditional_ira"
    case rothIRA = "roth_ira"
    case portugalPPR = "pt_ppr"
    case portugalOccupationalPension = "pt_occupational_pension"
    case spainIndividualPension = "es_individual_pension"
    case spainEmploymentPension = "es_employment_pension"
    case germanyRiester = "de_riester"
    case germanyRurup = "de_rurup"
    case germanyOccupationalPension = "de_occupational_pension"
    case francePERIndividual = "fr_per_individual"
    case francePERCompany = "fr_per_company"
    case italyComplementaryFund = "it_complementary_fund"
    case italyPIP = "it_pip"
    case genericPension = "generic_pension"
}

public enum RetirementWithdrawalStrategy: String, Codable, Sendable, CaseIterable {
    case fixedRealSpending = "fixed_real_spending"
    case percentageOfPortfolio = "percentage_of_portfolio"
    case guardrails
}

public enum RetirementProjectionPhase: String, Codable, Sendable, CaseIterable {
    case accumulation
    case retirement
}

public struct EmployerMatchRule: Codable, Sendable, Equatable {
    public let matchRate: Double
    public let upToSalaryPercent: Double
    public let annualCap: Double?

    public init(matchRate: Double, upToSalaryPercent: Double, annualCap: Double? = nil) {
        self.matchRate = matchRate
        self.upToSalaryPercent = upToSalaryPercent
        self.annualCap = annualCap
    }
}

public struct RetirementAccountPlan: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let accountId: String?
    public let name: String
    public let wrapper: RetirementWrapperKind
    public let currentBalance: Double
    public let employeeAnnualContribution: Double
    public let employerMatch: EmployerMatchRule?
    public let annualFeeRate: Double

    public init(
        id: String,
        accountId: String? = nil,
        name: String,
        wrapper: RetirementWrapperKind,
        currentBalance: Double,
        employeeAnnualContribution: Double,
        employerMatch: EmployerMatchRule? = nil,
        annualFeeRate: Double = 0
    ) {
        self.id = id
        self.accountId = accountId
        self.name = name
        self.wrapper = wrapper
        self.currentBalance = currentBalance
        self.employeeAnnualContribution = employeeAnnualContribution
        self.employerMatch = employerMatch
        self.annualFeeRate = annualFeeRate
    }
}

public struct RetirementPensionIncome: Codable, Sendable, Equatable {
    public let annualAmount: Double
    public let startAge: Int
    public let annualIndexationRate: Double
    public let currency: String

    public init(
        annualAmount: Double,
        startAge: Int,
        annualIndexationRate: Double = 0,
        currency: String
    ) {
        self.annualAmount = annualAmount
        self.startAge = startAge
        self.annualIndexationRate = annualIndexationRate
        self.currency = currency
    }
}

public struct RetirementPlanInput: Codable, Sendable, Equatable {
    public let jurisdiction: TaxJurisdiction
    public let currency: String
    public let currentAge: Int
    public let retirementAge: Int
    public let longevityAge: Int
    public let annualSalary: Double
    public let annualSalaryGrowthRate: Double
    public let desiredAnnualSpending: Double
    public let inflationRate: Double
    public let expectedAnnualReturn: Double
    public let annualVolatility: Double
    public let annualContributionGrowthRate: Double
    public let withdrawalStrategy: RetirementWithdrawalStrategy
    public let withdrawalRate: Double?
    public let accounts: [RetirementAccountPlan]
    public let publicPension: RetirementPensionIncome?
    public let otherAnnualRetirementIncome: Double

    public init(
        jurisdiction: TaxJurisdiction,
        currency: String,
        currentAge: Int,
        retirementAge: Int,
        longevityAge: Int,
        annualSalary: Double,
        annualSalaryGrowthRate: Double = 0,
        desiredAnnualSpending: Double,
        inflationRate: Double = 0.02,
        expectedAnnualReturn: Double,
        annualVolatility: Double,
        annualContributionGrowthRate: Double = 0,
        withdrawalStrategy: RetirementWithdrawalStrategy = .fixedRealSpending,
        withdrawalRate: Double? = nil,
        accounts: [RetirementAccountPlan],
        publicPension: RetirementPensionIncome? = nil,
        otherAnnualRetirementIncome: Double = 0
    ) {
        self.jurisdiction = jurisdiction
        self.currency = currency
        self.currentAge = currentAge
        self.retirementAge = retirementAge
        self.longevityAge = longevityAge
        self.annualSalary = annualSalary
        self.annualSalaryGrowthRate = annualSalaryGrowthRate
        self.desiredAnnualSpending = desiredAnnualSpending
        self.inflationRate = inflationRate
        self.expectedAnnualReturn = expectedAnnualReturn
        self.annualVolatility = annualVolatility
        self.annualContributionGrowthRate = annualContributionGrowthRate
        self.withdrawalStrategy = withdrawalStrategy
        self.withdrawalRate = withdrawalRate
        self.accounts = accounts
        self.publicPension = publicPension
        self.otherAnnualRetirementIncome = otherAnnualRetirementIncome
    }
}

public struct RetirementPlan: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let portfolioId: String
    public let ruleVersion: String
    public let input: RetirementPlanInput
    public let newerRuleVersion: String?
    public let createdAt: String
    public let updatedAt: String?

    public init(
        id: String,
        portfolioId: String,
        ruleVersion: String,
        input: RetirementPlanInput,
        newerRuleVersion: String? = nil,
        createdAt: String,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.portfolioId = portfolioId
        self.ruleVersion = ruleVersion
        self.input = input
        self.newerRuleVersion = newerRuleVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct RetirementPlanUpsertRequest: Codable, Sendable, Equatable {
    public let input: RetirementPlanInput
    public let ruleVersion: String?

    public init(input: RetirementPlanInput, ruleVersion: String? = nil) {
        self.input = input
        self.ruleVersion = ruleVersion
    }
}

public struct RetirementRuleSource: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        url
    }

    public let title: String
    public let url: String
    public let reviewedAt: String

    public init(title: String, url: String, reviewedAt: String) {
        self.title = title
        self.url = url
        self.reviewedAt = reviewedAt
    }
}

public struct RetirementWrapperRule: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        wrapper.rawValue
    }

    public let wrapper: RetirementWrapperKind
    public let maximumEmployeeAnnualContribution: Double?
    public let maximumTotalAnnualContribution: Double?
    public let minimumContributionAge: Int?
    public let minimumWithdrawalAge: Int?
    public let earlyWithdrawalPenaltyRate: Double?
    public let contributionTaxDeductible: Bool
    public let withdrawalsTaxable: Bool
    public let notes: [String]

    public init(
        wrapper: RetirementWrapperKind,
        maximumEmployeeAnnualContribution: Double? = nil,
        maximumTotalAnnualContribution: Double? = nil,
        minimumContributionAge: Int? = nil,
        minimumWithdrawalAge: Int? = nil,
        earlyWithdrawalPenaltyRate: Double? = nil,
        contributionTaxDeductible: Bool,
        withdrawalsTaxable: Bool,
        notes: [String] = []
    ) {
        self.wrapper = wrapper
        self.maximumEmployeeAnnualContribution = maximumEmployeeAnnualContribution
        self.maximumTotalAnnualContribution = maximumTotalAnnualContribution
        self.minimumContributionAge = minimumContributionAge
        self.minimumWithdrawalAge = minimumWithdrawalAge
        self.earlyWithdrawalPenaltyRate = earlyWithdrawalPenaltyRate
        self.contributionTaxDeductible = contributionTaxDeductible
        self.withdrawalsTaxable = withdrawalsTaxable
        self.notes = notes
    }
}

public struct RetirementRulePack: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        "\(jurisdiction.rawValue):\(version)"
    }

    public let jurisdiction: TaxJurisdiction
    public let version: String
    public let effectiveFrom: String
    public let effectiveTo: String?
    public let currency: String
    public let wrappers: [RetirementWrapperRule]
    public let sources: [RetirementRuleSource]
    public let disclaimer: String

    public init(
        jurisdiction: TaxJurisdiction,
        version: String,
        effectiveFrom: String,
        effectiveTo: String? = nil,
        currency: String,
        wrappers: [RetirementWrapperRule],
        sources: [RetirementRuleSource],
        disclaimer: String
    ) {
        self.jurisdiction = jurisdiction
        self.version = version
        self.effectiveFrom = effectiveFrom
        self.effectiveTo = effectiveTo
        self.currency = currency
        self.wrappers = wrappers
        self.sources = sources
        self.disclaimer = disclaimer
    }
}

public struct RetirementProjectionRequest: Codable, Sendable, Equatable {
    public let ruleVersion: String?
    public let pathCount: Int
    public let seed: UInt64

    public init(ruleVersion: String? = nil, pathCount: Int = 10000, seed: UInt64 = 42) {
        self.ruleVersion = ruleVersion
        self.pathCount = pathCount
        self.seed = seed
    }
}

public struct RetirementProjectionPoint: Codable, Sendable, Equatable, Identifiable {
    public var id: Int {
        age
    }

    public let age: Int
    public let year: Int
    public let phase: RetirementProjectionPhase
    public let p10: Double
    public let p25: Double
    public let p50: Double
    public let p75: Double
    public let p90: Double
    public let annualContribution: Double
    public let annualWithdrawal: Double
    public let annualPensionIncome: Double

    public init(
        age: Int,
        year: Int,
        phase: RetirementProjectionPhase,
        p10: Double,
        p25: Double,
        p50: Double,
        p75: Double,
        p90: Double,
        annualContribution: Double,
        annualWithdrawal: Double,
        annualPensionIncome: Double
    ) {
        self.age = age
        self.year = year
        self.phase = phase
        self.p10 = p10
        self.p25 = p25
        self.p50 = p50
        self.p75 = p75
        self.p90 = p90
        self.annualContribution = annualContribution
        self.annualWithdrawal = annualWithdrawal
        self.annualPensionIncome = annualPensionIncome
    }
}

public struct RetirementProjectionSummary: Codable, Sendable, Equatable {
    public let readinessProbability: Double
    public let sustainableAnnualSpending: Double
    public let projectedAnnualRetirementIncome: Double
    public let annualContributionHeadroom: Double
    public let shortfallAge: Int?
    public let medianValueAtRetirement: Double
    public let medianValueAtLongevityAge: Double

    public init(
        readinessProbability: Double,
        sustainableAnnualSpending: Double,
        projectedAnnualRetirementIncome: Double,
        annualContributionHeadroom: Double,
        shortfallAge: Int? = nil,
        medianValueAtRetirement: Double,
        medianValueAtLongevityAge: Double
    ) {
        self.readinessProbability = readinessProbability
        self.sustainableAnnualSpending = sustainableAnnualSpending
        self.projectedAnnualRetirementIncome = projectedAnnualRetirementIncome
        self.annualContributionHeadroom = annualContributionHeadroom
        self.shortfallAge = shortfallAge
        self.medianValueAtRetirement = medianValueAtRetirement
        self.medianValueAtLongevityAge = medianValueAtLongevityAge
    }
}

public struct RetirementProjection: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    /// `nil` when the projection is user-scoped rather than about one portfolio.
    public let portfolioId: String?
    public let ruleVersion: String
    public let currency: String
    public let summary: RetirementProjectionSummary
    public let points: [RetirementProjectionPoint]
    public let assumptions: [String]
    public let warnings: [String]
    public let generatedAt: String

    public init(
        id: String,
        portfolioId: String? = nil,
        ruleVersion: String,
        currency: String,
        summary: RetirementProjectionSummary,
        points: [RetirementProjectionPoint],
        assumptions: [String],
        warnings: [String],
        generatedAt: String
    ) {
        self.id = id
        self.portfolioId = portfolioId
        self.ruleVersion = ruleVersion
        self.currency = currency
        self.summary = summary
        self.points = points
        self.assumptions = assumptions
        self.warnings = warnings
        self.generatedAt = generatedAt
    }
}
