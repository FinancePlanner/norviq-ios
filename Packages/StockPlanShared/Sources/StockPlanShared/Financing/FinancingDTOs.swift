import Foundation

public enum FinancingMarket: String, Codable, CaseIterable, Sendable, Equatable, Hashable {
    case portugal = "PT"
    case germany = "DE"
    case france = "FR"
    case italy = "IT"
    case spain = "ES"
    case netherlands = "NL"
    case poland = "PL"
    case brazil = "BR"
    case unitedStates = "US"

    public var defaultCurrency: String {
        switch self {
        case .poland: "PLN"
        case .brazil: "BRL"
        case .unitedStates: "USD"
        default: "EUR"
        }
    }
}

public enum FinancingPurchaseType: String, Codable, CaseIterable, Sendable, Equatable, Hashable {
    case vehicle
    case home
    case utility
    case education
    case other
}

public enum FinancingRateType: String, Codable, CaseIterable, Sendable, Equatable, Hashable {
    case fixed
    case variable
    case unknown
}

public enum FinancingCostCadence: String, Codable, CaseIterable, Sendable, Equatable, Hashable {
    case oneTime = "one_time"
    case monthly
    case annual
}

public enum FinancingPlanStatus: String, Codable, CaseIterable, Sendable, Equatable, Hashable {
    case active
    case paused
    case completed
    case cancelled
}

public enum FinancingInstallmentStatus: String, Codable, CaseIterable, Sendable, Equatable, Hashable {
    case projected
    case due
    case overdue
    case matched
    case cancelled
    case completed
}

public enum FinancingCashFlowStatus: String, Codable, CaseIterable, Sendable, Equatable, Hashable {
    case doable
    case tight
    case notDoable = "not_doable"
    case insufficientData = "insufficient_data"
}

public enum FinancingBenchmarkStatus: String, Codable, CaseIterable, Sendable, Equatable, Hashable {
    case pass
    case aboveGuidance = "above_guidance"
    case notEvaluated = "not_evaluated"
    case stale
}

public enum FinancingIncomeScope: String, Codable, CaseIterable, Sendable, Equatable, Hashable {
    case personal
    case household
}

public struct FinancingAdditionalCost: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let amount: Double
    public let cadence: FinancingCostCadence
    public let startMonth: Int
    public let endMonth: Int?

    public init(
        id: String = UUID().uuidString,
        title: String,
        amount: Double,
        cadence: FinancingCostCadence,
        startMonth: Int = 1,
        endMonth: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.cadence = cadence
        self.startMonth = startMonth
        self.endMonth = endMonth
    }
}

public struct FinancingOfferTerms: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let purchaseAmount: Double
    public let downPayment: Double
    public let financedAmount: Double?
    public let termMonths: Int
    public let firstPaymentDate: String
    public let quotedMonthlyPayment: Double?
    public let nominalAnnualRate: Double?
    public let effectiveAnnualRate: Double?
    public let rateType: FinancingRateType
    public let upfrontFees: Double
    public let financedFees: Double
    public let balloonPayment: Double
    public let additionalCosts: [FinancingAdditionalCost]

    public init(
        id: String = UUID().uuidString,
        name: String,
        purchaseAmount: Double,
        downPayment: Double = 0,
        financedAmount: Double? = nil,
        termMonths: Int,
        firstPaymentDate: String,
        quotedMonthlyPayment: Double? = nil,
        nominalAnnualRate: Double? = nil,
        effectiveAnnualRate: Double? = nil,
        rateType: FinancingRateType = .fixed,
        upfrontFees: Double = 0,
        financedFees: Double = 0,
        balloonPayment: Double = 0,
        additionalCosts: [FinancingAdditionalCost] = []
    ) {
        self.id = id
        self.name = name
        self.purchaseAmount = purchaseAmount
        self.downPayment = downPayment
        self.financedAmount = financedAmount
        self.termMonths = termMonths
        self.firstPaymentDate = firstPaymentDate
        self.quotedMonthlyPayment = quotedMonthlyPayment
        self.nominalAnnualRate = nominalAnnualRate
        self.effectiveAnnualRate = effectiveAnnualRate
        self.rateType = rateType
        self.upfrontFees = upfrontFees
        self.financedFees = financedFees
        self.balloonPayment = balloonPayment
        self.additionalCosts = additionalCosts
    }
}

public struct FinancingAffordabilityAssumptions: Codable, Sendable, Equatable {
    public let incomeScope: FinancingIncomeScope
    public let netMonthlyIncomeOverride: Double?
    public let grossMonthlyIncome: Double?
    public let externalMonthlyDebtPayments: Double
    public let safetyBufferPercent: Double
    public let monthlySavingsTargetOverride: Double?

    public init(
        incomeScope: FinancingIncomeScope = .personal,
        netMonthlyIncomeOverride: Double? = nil,
        grossMonthlyIncome: Double? = nil,
        externalMonthlyDebtPayments: Double = 0,
        safetyBufferPercent: Double = 10,
        monthlySavingsTargetOverride: Double? = nil
    ) {
        self.incomeScope = incomeScope
        self.netMonthlyIncomeOverride = netMonthlyIncomeOverride
        self.grossMonthlyIncome = grossMonthlyIncome
        self.externalMonthlyDebtPayments = externalMonthlyDebtPayments
        self.safetyBufferPercent = safetyBufferPercent
        self.monthlySavingsTargetOverride = monthlySavingsTargetOverride
    }
}

public struct FinancingSimulationRequest: Codable, Sendable, Equatable {
    public let market: FinancingMarket
    public let purchaseType: FinancingPurchaseType
    public let currency: String
    public let offers: [FinancingOfferTerms]
    public let assumptions: FinancingAffordabilityAssumptions?

    public init(
        market: FinancingMarket,
        purchaseType: FinancingPurchaseType,
        currency: String,
        offers: [FinancingOfferTerms],
        assumptions: FinancingAffordabilityAssumptions? = nil
    ) {
        self.market = market
        self.purchaseType = purchaseType
        self.currency = currency
        self.offers = offers
        self.assumptions = assumptions
    }
}

public struct FinancingProjectionResponse: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        "\(planId ?? offerId)-\(installmentNumber)"
    }

    public let planId: String?
    public let offerId: String
    public let installmentNumber: Int
    public let dueDate: String
    public let paymentAmount: Double
    public let additionalCostAmount: Double
    public let totalAmount: Double
    public let currency: String
    public let status: FinancingInstallmentStatus
    public let matchedExpenseId: String?

    public init(
        planId: String? = nil,
        offerId: String,
        installmentNumber: Int,
        dueDate: String,
        paymentAmount: Double,
        additionalCostAmount: Double,
        totalAmount: Double,
        currency: String,
        status: FinancingInstallmentStatus = .projected,
        matchedExpenseId: String? = nil
    ) {
        self.planId = planId
        self.offerId = offerId
        self.installmentNumber = installmentNumber
        self.dueDate = dueDate
        self.paymentAmount = paymentAmount
        self.additionalCostAmount = additionalCostAmount
        self.totalAmount = totalAmount
        self.currency = currency
        self.status = status
        self.matchedExpenseId = matchedExpenseId
    }
}

public struct FinancingBenchmarkResult: Codable, Sendable, Equatable {
    public let status: FinancingBenchmarkStatus
    public let ratio: Double?
    public let guidanceMinimum: Double?
    public let guidanceMaximum: Double?
    public let incomeBasis: String?
    public let sourceURL: String?
    public let reviewedAt: String?
    public let message: String

    public init(
        status: FinancingBenchmarkStatus,
        ratio: Double? = nil,
        guidanceMinimum: Double? = nil,
        guidanceMaximum: Double? = nil,
        incomeBasis: String? = nil,
        sourceURL: String? = nil,
        reviewedAt: String? = nil,
        message: String
    ) {
        self.status = status
        self.ratio = ratio
        self.guidanceMinimum = guidanceMinimum
        self.guidanceMaximum = guidanceMaximum
        self.incomeBasis = incomeBasis
        self.sourceURL = sourceURL
        self.reviewedAt = reviewedAt
        self.message = message
    }
}

public struct FinancingAffordabilityAssessment: Codable, Sendable, Equatable {
    public let cashFlowStatus: FinancingCashFlowStatus
    public let benchmark: FinancingBenchmarkResult
    public let monthlyIncome: Double?
    public let baselineSpending: Double
    public let savingsTarget: Double
    public let safetyBuffer: Double
    public let monthlyFinancing: Double
    public let residualAfterPlan: Double?
    public let stressedResidual: Double?
    public let message: String

    public init(
        cashFlowStatus: FinancingCashFlowStatus,
        benchmark: FinancingBenchmarkResult,
        monthlyIncome: Double?,
        baselineSpending: Double,
        savingsTarget: Double,
        safetyBuffer: Double,
        monthlyFinancing: Double,
        residualAfterPlan: Double?,
        stressedResidual: Double?,
        message: String
    ) {
        self.cashFlowStatus = cashFlowStatus
        self.benchmark = benchmark
        self.monthlyIncome = monthlyIncome
        self.baselineSpending = baselineSpending
        self.savingsTarget = savingsTarget
        self.safetyBuffer = safetyBuffer
        self.monthlyFinancing = monthlyFinancing
        self.residualAfterPlan = residualAfterPlan
        self.stressedResidual = stressedResidual
        self.message = message
    }
}

public struct FinancingOfferSimulationResponse: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        offer.id
    }

    public let offer: FinancingOfferTerms
    public let monthlyPayment: Double
    public let totalLoanPayments: Double
    public let totalOutOfPocket: Double
    public let totalCreditCost: Double
    public let projections: [FinancingProjectionResponse]
    public let affordability: FinancingAffordabilityAssessment
    public let warnings: [String]

    public init(
        offer: FinancingOfferTerms,
        monthlyPayment: Double,
        totalLoanPayments: Double,
        totalOutOfPocket: Double,
        totalCreditCost: Double,
        projections: [FinancingProjectionResponse],
        affordability: FinancingAffordabilityAssessment,
        warnings: [String] = []
    ) {
        self.offer = offer
        self.monthlyPayment = monthlyPayment
        self.totalLoanPayments = totalLoanPayments
        self.totalOutOfPocket = totalOutOfPocket
        self.totalCreditCost = totalCreditCost
        self.projections = projections
        self.affordability = affordability
        self.warnings = warnings
    }
}

public struct FinancingSimulationResponse: Codable, Sendable, Equatable {
    public let currency: String
    public let results: [FinancingOfferSimulationResponse]
    public let generatedAt: String

    public init(currency: String, results: [FinancingOfferSimulationResponse], generatedAt: String) {
        self.currency = currency
        self.results = results
        self.generatedAt = generatedAt
    }
}

public struct FinancingPlanRequest: Codable, Sendable, Equatable {
    public let title: String
    public let market: FinancingMarket
    public let purchaseType: FinancingPurchaseType
    public let currency: String
    public let userSharePercent: Double
    public let terms: FinancingOfferTerms
    public let sourceDomain: String?

    public init(
        title: String,
        market: FinancingMarket,
        purchaseType: FinancingPurchaseType,
        currency: String,
        userSharePercent: Double = 100,
        terms: FinancingOfferTerms,
        sourceDomain: String? = nil
    ) {
        self.title = title
        self.market = market
        self.purchaseType = purchaseType
        self.currency = currency
        self.userSharePercent = userSharePercent
        self.terms = terms
        self.sourceDomain = sourceDomain
    }
}

public struct FinancingPlanResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let market: FinancingMarket
    public let purchaseType: FinancingPurchaseType
    public let currency: String
    public let status: FinancingPlanStatus
    public let userSharePercent: Double
    public let terms: FinancingOfferTerms
    public let sourceDomain: String?
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        title: String,
        market: FinancingMarket,
        purchaseType: FinancingPurchaseType,
        currency: String,
        status: FinancingPlanStatus,
        userSharePercent: Double,
        terms: FinancingOfferTerms,
        sourceDomain: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.title = title
        self.market = market
        self.purchaseType = purchaseType
        self.currency = currency
        self.status = status
        self.userSharePercent = userSharePercent
        self.terms = terms
        self.sourceDomain = sourceDomain
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct FinancingPlanRevisionRequest: Codable, Sendable, Equatable {
    public let terms: FinancingOfferTerms

    public init(terms: FinancingOfferTerms) {
        self.terms = terms
    }
}

public struct FinancingPlanStatusRequest: Codable, Sendable, Equatable {
    public let status: FinancingPlanStatus

    public init(status: FinancingPlanStatus) {
        self.status = status
    }
}

public struct FinancingExpenseMatchRequest: Codable, Sendable, Equatable {
    public let expenseId: String

    public init(expenseId: String) {
        self.expenseId = expenseId
    }
}

public struct FinancingExpenseMatchResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let planId: String
    public let installmentNumber: Int
    public let expenseId: String
    public let createdAt: String?

    public init(id: String, planId: String, installmentNumber: Int, expenseId: String, createdAt: String? = nil) {
        self.id = id
        self.planId = planId
        self.installmentNumber = installmentNumber
        self.expenseId = expenseId
        self.createdAt = createdAt
    }
}

public struct FinancingMatchCandidateResponse: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        "\(planId)-\(installmentNumber)-\(expenseId)"
    }

    public let planId: String
    public let planTitle: String
    public let installmentNumber: Int
    public let dueDate: String
    public let expenseId: String
    public let score: Double
    public let reasons: [String]

    public init(
        planId: String,
        planTitle: String,
        installmentNumber: Int,
        dueDate: String,
        expenseId: String,
        score: Double,
        reasons: [String]
    ) {
        self.planId = planId
        self.planTitle = planTitle
        self.installmentNumber = installmentNumber
        self.dueDate = dueDate
        self.expenseId = expenseId
        self.score = score
        self.reasons = reasons
    }
}

public struct FinancingURLImportRequest: Codable, Sendable, Equatable {
    public let url: String

    public init(url: String) {
        self.url = url
    }
}

public struct FinancingOfferDraft: Codable, Sendable, Equatable {
    public let name: String?
    public let purchaseAmount: Double?
    public let downPayment: Double?
    public let termMonths: Int?
    public let monthlyPayment: Double?
    public let nominalAnnualRate: Double?
    public let effectiveAnnualRate: Double?
    public let currency: String?
    public let confidence: Double

    public init(
        name: String? = nil,
        purchaseAmount: Double? = nil,
        downPayment: Double? = nil,
        termMonths: Int? = nil,
        monthlyPayment: Double? = nil,
        nominalAnnualRate: Double? = nil,
        effectiveAnnualRate: Double? = nil,
        currency: String? = nil,
        confidence: Double
    ) {
        self.name = name
        self.purchaseAmount = purchaseAmount
        self.downPayment = downPayment
        self.termMonths = termMonths
        self.monthlyPayment = monthlyPayment
        self.nominalAnnualRate = nominalAnnualRate
        self.effectiveAnnualRate = effectiveAnnualRate
        self.currency = currency
        self.confidence = confidence
    }
}

public struct FinancingImportResponse: Codable, Sendable, Equatable {
    public let recognized: Bool
    public let draft: FinancingOfferDraft?
    public let sourceDomain: String?
    public let warnings: [String]

    public init(recognized: Bool, draft: FinancingOfferDraft?, sourceDomain: String? = nil, warnings: [String] = []) {
        self.recognized = recognized
        self.draft = draft
        self.sourceDomain = sourceDomain
        self.warnings = warnings
    }
}
