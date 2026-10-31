import Foundation

public enum BudgetTargetType: String, Codable, Sendable, CaseIterable {
    case fixed
    case percentageIncome
}

public enum BudgetAllocationKind: String, Codable, Sendable, CaseIterable {
    case expense
    case investmentContribution
}

public enum BudgetDriftLevel: String, Codable, Sendable, CaseIterable {
    case green
    case yellow
    case red
}

public enum ExpenseReceiptSource: String, Codable, Sendable, CaseIterable {
    case qr
    case ocr
}

public struct ExpenseReceiptMetadata: Codable, Sendable, Equatable {
    public let source: ExpenseReceiptSource
    public let merchant: String?
    public let taxIdentifier: String?
    public let issuedOn: String?
    public let currency: String?
    public let total: Double?
    /// Total VAT/tax amount reported on the receipt, when known. Optional so it
    /// decodes cleanly from receipt_metadata JSON written before this field
    /// existed (no migration needed — the column is a Codable blob).
    public let vatTotal: Double?

    public init(
        source: ExpenseReceiptSource,
        merchant: String? = nil,
        taxIdentifier: String? = nil,
        issuedOn: String? = nil,
        currency: String? = nil,
        total: Double? = nil,
        vatTotal: Double? = nil
    ) {
        self.source = source
        self.merchant = merchant
        self.taxIdentifier = taxIdentifier
        self.issuedOn = issuedOn
        self.currency = currency
        self.total = total
        self.vatTotal = vatTotal
    }
}

public struct BudgetAlertPolicy: Codable, Sendable, Equatable {
    public let categoryThreshold: Double
    public let totalThreshold: Double
    public let alertsEnabled: Bool
    public let alertOnUnbudgeted: Bool

    public init(
        categoryThreshold: Double = 15,
        totalThreshold: Double = 10,
        alertsEnabled: Bool = true,
        alertOnUnbudgeted: Bool = true
    ) {
        self.categoryThreshold = categoryThreshold
        self.totalThreshold = totalThreshold
        self.alertsEnabled = alertsEnabled
        self.alertOnUnbudgeted = alertOnUnbudgeted
    }
}

public struct BudgetCategoryDrift: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let categoryId: String?
    public let targetAmount: Double
    public let actualAmount: Double
    public let driftAmount: Double
    public let driftPercent: Double?
    public let threshold: Double
    public let level: BudgetDriftLevel
    public let allocationKind: BudgetAllocationKind
    public let reallocationEligible: Bool

    public init(
        id: String,
        title: String,
        categoryId: String? = nil,
        targetAmount: Double,
        actualAmount: Double,
        driftAmount: Double,
        driftPercent: Double? = nil,
        threshold: Double,
        level: BudgetDriftLevel,
        allocationKind: BudgetAllocationKind = .expense,
        reallocationEligible: Bool = false
    ) {
        self.id = id
        self.title = title
        self.categoryId = categoryId
        self.targetAmount = targetAmount
        self.actualAmount = actualAmount
        self.driftAmount = driftAmount
        self.driftPercent = driftPercent
        self.threshold = threshold
        self.level = level
        self.allocationKind = allocationKind
        self.reallocationEligible = reallocationEligible
    }
}

public struct BudgetDriftDashboard: Codable, Sendable, Equatable {
    public let snapshotId: String
    public let monthStart: String
    public let currencyCode: String
    public let revision: Int
    public let totalTarget: Double
    public let totalActual: Double
    public let totalDriftAmount: Double
    public let totalDriftPercent: Double?
    public let totalLevel: BudgetDriftLevel
    public let investmentContributionTarget: Double
    public let lostInvestmentCapital: Double
    public let categories: [BudgetCategoryDrift]

    public init(
        snapshotId: String,
        monthStart: String,
        currencyCode: String,
        revision: Int,
        totalTarget: Double,
        totalActual: Double,
        totalDriftAmount: Double,
        totalDriftPercent: Double? = nil,
        totalLevel: BudgetDriftLevel,
        investmentContributionTarget: Double,
        lostInvestmentCapital: Double,
        categories: [BudgetCategoryDrift]
    ) {
        self.snapshotId = snapshotId
        self.monthStart = monthStart
        self.currencyCode = currencyCode
        self.revision = revision
        self.totalTarget = totalTarget
        self.totalActual = totalActual
        self.totalDriftAmount = totalDriftAmount
        self.totalDriftPercent = totalDriftPercent
        self.totalLevel = totalLevel
        self.investmentContributionTarget = investmentContributionTarget
        self.lostInvestmentCapital = lostInvestmentCapital
        self.categories = categories
    }
}

public struct BudgetDisciplineMonth: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        monthStart
    }

    public let monthStart: String
    public let score: Double?
    public let compliant: Bool?

    public init(monthStart: String, score: Double?, compliant: Bool?) {
        self.monthStart = monthStart
        self.score = score
        self.compliant = compliant
    }
}

public struct BudgetDisciplineSummary: Codable, Sendable, Equatable {
    public let currentScore: Double?
    public let completedMonthStreak: Int
    public let compliantMonths: Int
    public let evaluatedMonths: Int
    public let months: [BudgetDisciplineMonth]

    public init(
        currentScore: Double?,
        completedMonthStreak: Int,
        compliantMonths: Int,
        evaluatedMonths: Int,
        months: [BudgetDisciplineMonth]
    ) {
        self.currentScore = currentScore
        self.completedMonthStreak = completedMonthStreak
        self.compliantMonths = compliantMonths
        self.evaluatedMonths = evaluatedMonths
        self.months = months
    }
}

public struct BudgetReallocationAdjustment: Codable, Sendable, Equatable {
    public let planItemId: String
    public let amount: Double

    public init(planItemId: String, amount: Double) {
        self.planItemId = planItemId
        self.amount = amount
    }
}

public struct BudgetReallocationPreviewRequest: Codable, Sendable, Equatable {
    public let snapshotId: String
    public let expectedRevision: Int
    public let adjustments: [BudgetReallocationAdjustment]
    public let financialGoalId: String?
    public let portfolioListId: String?

    public init(
        snapshotId: String,
        expectedRevision: Int,
        adjustments: [BudgetReallocationAdjustment],
        financialGoalId: String? = nil,
        portfolioListId: String? = nil
    ) {
        self.snapshotId = snapshotId
        self.expectedRevision = expectedRevision
        self.adjustments = adjustments
        self.financialGoalId = financialGoalId
        self.portfolioListId = portfolioListId
    }
}

public struct BudgetReallocationPreviewResponse: Codable, Sendable, Equatable {
    public let effectiveMonth: String
    public let freedCapital: Double
    public let annualImpact: Double
    public let investmentTargetBefore: Double
    public let investmentTargetAfter: Double
    public let warnings: [String]

    public init(
        effectiveMonth: String,
        freedCapital: Double,
        annualImpact: Double,
        investmentTargetBefore: Double,
        investmentTargetAfter: Double,
        warnings: [String] = []
    ) {
        self.effectiveMonth = effectiveMonth
        self.freedCapital = freedCapital
        self.annualImpact = annualImpact
        self.investmentTargetBefore = investmentTargetBefore
        self.investmentTargetAfter = investmentTargetAfter
        self.warnings = warnings
    }
}

public struct BudgetReallocationCommitRequest: Codable, Sendable, Equatable {
    public let requestId: String
    public let preview: BudgetReallocationPreviewRequest

    public init(requestId: String, preview: BudgetReallocationPreviewRequest) {
        self.requestId = requestId
        self.preview = preview
    }
}

public struct BudgetReallocationEventResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let requestId: String
    public let sourceSnapshotId: String
    public let targetSnapshotId: String
    public let effectiveMonth: String
    public let freedCapital: Double
    public let financialGoalId: String?
    public let portfolioListId: String?
    public let adjustments: [BudgetReallocationAdjustment]
    public let createdAt: String?

    public init(
        id: String,
        requestId: String,
        sourceSnapshotId: String,
        targetSnapshotId: String,
        effectiveMonth: String,
        freedCapital: Double,
        financialGoalId: String? = nil,
        portfolioListId: String? = nil,
        adjustments: [BudgetReallocationAdjustment],
        createdAt: String? = nil
    ) {
        self.id = id
        self.requestId = requestId
        self.sourceSnapshotId = sourceSnapshotId
        self.targetSnapshotId = targetSnapshotId
        self.effectiveMonth = effectiveMonth
        self.freedCapital = freedCapital
        self.financialGoalId = financialGoalId
        self.portfolioListId = portfolioListId
        self.adjustments = adjustments
        self.createdAt = createdAt
    }
}

public struct BudgetBulkPlanItemUpdate: Codable, Sendable, Equatable {
    public let id: String
    public let plannedAmount: Double
    public let targetType: BudgetTargetType
    public let incomePercentage: Double?
    public let thresholdOverride: Double?
    public let reallocationEligible: Bool

    public init(
        id: String,
        plannedAmount: Double,
        targetType: BudgetTargetType = .fixed,
        incomePercentage: Double? = nil,
        thresholdOverride: Double? = nil,
        reallocationEligible: Bool = false
    ) {
        self.id = id
        self.plannedAmount = plannedAmount
        self.targetType = targetType
        self.incomePercentage = incomePercentage
        self.thresholdOverride = thresholdOverride
        self.reallocationEligible = reallocationEligible
    }
}

public struct BudgetBulkPlanItemUpdateRequest: Codable, Sendable, Equatable {
    public let expectedRevision: Int
    public let items: [BudgetBulkPlanItemUpdate]

    public init(expectedRevision: Int, items: [BudgetBulkPlanItemUpdate]) {
        self.expectedRevision = expectedRevision
        self.items = items
    }
}

public struct BudgetTemplateItem: Codable, Sendable, Equatable {
    public let title: String
    public let plannedAmount: Double
    public let pillar: BudgetPillar
    public let categoryId: String?
    public let targetType: BudgetTargetType
    public let incomePercentage: Double?
    public let thresholdOverride: Double?
    public let allocationKind: BudgetAllocationKind
    public let reallocationEligible: Bool

    public init(
        title: String,
        plannedAmount: Double,
        pillar: BudgetPillar,
        categoryId: String? = nil,
        targetType: BudgetTargetType = .fixed,
        incomePercentage: Double? = nil,
        thresholdOverride: Double? = nil,
        allocationKind: BudgetAllocationKind = .expense,
        reallocationEligible: Bool = false
    ) {
        self.title = title
        self.plannedAmount = plannedAmount
        self.pillar = pillar
        self.categoryId = categoryId
        self.targetType = targetType
        self.incomePercentage = incomePercentage
        self.thresholdOverride = thresholdOverride
        self.allocationKind = allocationKind
        self.reallocationEligible = reallocationEligible
    }
}

public struct BudgetTemplateRequest: Codable, Sendable, Equatable {
    public let name: String
    public let items: [BudgetTemplateItem]

    public init(name: String, items: [BudgetTemplateItem]) {
        self.name = name
        self.items = items
    }
}

public struct BudgetTemplateResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let items: [BudgetTemplateItem]
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        name: String,
        items: [BudgetTemplateItem],
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct BudgetTemplateApplyRequest: Codable, Sendable, Equatable {
    public let snapshotId: String
    public let expectedRevision: Int
    public let replaceExisting: Bool

    public init(snapshotId: String, expectedRevision: Int, replaceExisting: Bool = false) {
        self.snapshotId = snapshotId
        self.expectedRevision = expectedRevision
        self.replaceExisting = replaceExisting
    }
}
