import Foundation

// MARK: - Pillar Enum

public struct BudgetPillar: RawRepresentable, Codable, Sendable, CaseIterable, Hashable, ExpressibleByStringLiteral {
    public let rawValue: String

    public static let fundamentals = BudgetPillar(uncheckedRawValue: "fundamentals")
    public static let futureYou = BudgetPillar(uncheckedRawValue: "futureYou")
    public static let fun = BudgetPillar(uncheckedRawValue: "fun")

    public static var allCases: [BudgetPillar] {
        [fundamentals, futureYou, fun]
    }

    public var isStandard: Bool {
        Self.allCases.contains(self)
    }

    public init?(rawValue: String) {
        let canonical = Self.canonicalKey(from: rawValue)
        guard !canonical.isEmpty else { return nil }
        self.rawValue = canonical
    }

    public init(stringLiteral value: StringLiteralType) {
        self = BudgetPillar(rawValue: value) ?? BudgetPillar(uncheckedRawValue: "fundamentals")
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let pillar = BudgetPillar(rawValue: value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid pillar value.")
        }
        self = pillar
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func canonicalKey(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let normalized: String
        if trimmed.range(of: "[^A-Za-z0-9]", options: .regularExpression) == nil {
            let first = String(trimmed.prefix(1)).lowercased()
            let rest = String(trimmed.dropFirst())
            normalized = first + rest
        } else {
            let cleaned = trimmed
                .replacingOccurrences(of: "[^A-Za-z0-9]+", with: " ", options: .regularExpression)
                .split(separator: " ")
                .map(String.init)

            guard let firstWord = cleaned.first else { return "" }
            normalized = ([firstWord.lowercased()] + cleaned.dropFirst().map {
                $0.prefix(1).uppercased() + $0.dropFirst().lowercased()
            }).joined()
        }

        switch normalized.lowercased() {
        case "fundamentals":
            return "fundamentals"
        case "futureyou":
            return "futureYou"
        case "fun":
            return "fun"
        default:
            return normalized
        }
    }

    private init(uncheckedRawValue: String) {
        self.rawValue = uncheckedRawValue
    }
}

public enum ExpenseSplitMode: String, Codable, Sendable, CaseIterable {
    case personal
    case shared
}

public enum RecurringFrequency: String, Codable, Sendable, CaseIterable {
    case weekly
    case monthly
}

// MARK: - Expense Category

public struct ExpenseCategoryRequest: Codable, Sendable, Equatable {
    public let name: String
    public let pillar: BudgetPillar?

    public init(name: String, pillar: BudgetPillar? = nil) {
        self.name = name
        self.pillar = pillar
    }
}

public struct ExpenseCategoryResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let pillar: BudgetPillar?
    public let isDefault: Bool

    public init(id: String, name: String, pillar: BudgetPillar? = nil, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.pillar = pillar
        self.isDefault = isDefault
    }
}

// MARK: - Recurring Template

public struct RecurringTemplateRequest: Codable, Sendable, Equatable {
    public let title: String
    public let amount: Double
    public let pillar: BudgetPillar
    public let categoryId: String?
    public let frequency: RecurringFrequency
    public let splitMode: ExpenseSplitMode
    public let userSharePercent: Double

    public init(
        title: String,
        amount: Double,
        pillar: BudgetPillar,
        categoryId: String? = nil,
        frequency: RecurringFrequency = .monthly,
        splitMode: ExpenseSplitMode = .personal,
        userSharePercent: Double = 100
    ) {
        self.title = title
        self.amount = amount
        self.pillar = pillar
        self.categoryId = categoryId
        self.frequency = frequency
        self.splitMode = splitMode
        self.userSharePercent = userSharePercent
    }
}

public struct RecurringTemplateResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let amount: Double
    public let pillar: BudgetPillar
    public let categoryId: String?
    public let frequency: RecurringFrequency
    public let splitMode: ExpenseSplitMode
    public let userSharePercent: Double
    public let createdAt: String?

    public init(
        id: String,
        title: String,
        amount: Double,
        pillar: BudgetPillar,
        categoryId: String? = nil,
        frequency: RecurringFrequency = .monthly,
        splitMode: ExpenseSplitMode = .personal,
        userSharePercent: Double = 100,
        createdAt: String? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.pillar = pillar
        self.categoryId = categoryId
        self.frequency = frequency
        self.splitMode = splitMode
        self.userSharePercent = userSharePercent
        self.createdAt = createdAt
    }
}

public struct HouseholdPartnerProfileResponse: Codable, Sendable, Equatable {
    public let displayName: String?

    /// The household's default share of a shared item, as a percentage the user
    /// keeps (so 40 means the partner covers 60%).
    ///
    /// `nil` means no default has been set, which is deliberately distinct from
    /// `100`: clients seed a new shared item from this value and fall back to
    /// 100 only when it is absent.
    public let defaultUserSharePercent: Double?

    public init(displayName: String? = nil, defaultUserSharePercent: Double? = nil) {
        self.displayName = displayName
        self.defaultUserSharePercent = defaultUserSharePercent
    }
}

public struct HouseholdPartnerProfileRequest: Codable, Sendable, Equatable {
    public let displayName: String?

    /// See `HouseholdPartnerProfileResponse.defaultUserSharePercent`. Sending
    /// `nil` clears the default rather than setting it to zero.
    public let defaultUserSharePercent: Double?

    public init(displayName: String? = nil, defaultUserSharePercent: Double? = nil) {
        self.displayName = displayName
        self.defaultUserSharePercent = defaultUserSharePercent
    }
}

// MARK: - Budget Snapshot

public struct BudgetSnapshotRequest: Codable, Sendable, Equatable {
    public let monthStart: String // YYYY-MM-DD
    public let netSalary: Double
    public let targetShares: [String: Double] // String key representation of BudgetPillar
    public let currencyCode: String?
    public let categoryDriftThreshold: Double?
    public let totalDriftThreshold: Double?
    public let alertsEnabled: Bool?
    public let alertOnUnbudgeted: Bool?

    public init(
        monthStart: String,
        netSalary: Double,
        targetShares: [String: Double],
        currencyCode: String? = nil,
        categoryDriftThreshold: Double? = nil,
        totalDriftThreshold: Double? = nil,
        alertsEnabled: Bool? = nil,
        alertOnUnbudgeted: Bool? = nil
    ) {
        self.monthStart = monthStart
        self.netSalary = netSalary
        self.targetShares = targetShares
        self.currencyCode = currencyCode
        self.categoryDriftThreshold = categoryDriftThreshold
        self.totalDriftThreshold = totalDriftThreshold
        self.alertsEnabled = alertsEnabled
        self.alertOnUnbudgeted = alertOnUnbudgeted
    }
}

public struct BudgetSnapshotResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let monthStart: String // YYYY-MM-DD
    public let netSalary: Double
    public let targetShares: [String: Double]
    public let currencyCode: String
    public let categoryDriftThreshold: Double
    public let totalDriftThreshold: Double
    public let alertsEnabled: Bool
    public let alertOnUnbudgeted: Bool
    public let revision: Int
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        monthStart: String,
        netSalary: Double,
        targetShares: [String: Double],
        currencyCode: String = "USD",
        categoryDriftThreshold: Double = 15,
        totalDriftThreshold: Double = 10,
        alertsEnabled: Bool = true,
        alertOnUnbudgeted: Bool = true,
        revision: Int = 0,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.monthStart = monthStart
        self.netSalary = netSalary
        self.targetShares = targetShares
        self.currencyCode = currencyCode
        self.categoryDriftThreshold = categoryDriftThreshold
        self.totalDriftThreshold = totalDriftThreshold
        self.alertsEnabled = alertsEnabled
        self.alertOnUnbudgeted = alertOnUnbudgeted
        self.revision = revision
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, monthStart, netSalary, targetShares, currencyCode, categoryDriftThreshold
        case totalDriftThreshold, alertsEnabled, alertOnUnbudgeted, revision, createdAt, updatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        monthStart = try container.decode(String.self, forKey: .monthStart)
        netSalary = try container.decode(Double.self, forKey: .netSalary)
        targetShares = try container.decode([String: Double].self, forKey: .targetShares)
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? "USD"
        categoryDriftThreshold = try container.decodeIfPresent(Double.self, forKey: .categoryDriftThreshold) ?? 15
        totalDriftThreshold = try container.decodeIfPresent(Double.self, forKey: .totalDriftThreshold) ?? 10
        alertsEnabled = try container.decodeIfPresent(Bool.self, forKey: .alertsEnabled) ?? true
        alertOnUnbudgeted = try container.decodeIfPresent(Bool.self, forKey: .alertOnUnbudgeted) ?? true
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

// MARK: - Budget Plan Item

public struct BudgetPlanItemRequest: Codable, Sendable, Equatable {
    public let snapshotId: String
    public let title: String
    public let plannedAmount: Double
    public let pillar: BudgetPillar
    public let categoryId: String?
    public let splitMode: ExpenseSplitMode
    public let userSharePercent: Double
    public let targetType: BudgetTargetType
    public let incomePercentage: Double?
    public let thresholdOverride: Double?
    public let allocationKind: BudgetAllocationKind
    public let reallocationEligible: Bool
    public let destinationFinancialGoalId: String?
    public let destinationPortfolioListId: String?

    public init(
        snapshotId: String,
        title: String,
        plannedAmount: Double,
        pillar: BudgetPillar,
        categoryId: String? = nil,
        splitMode: ExpenseSplitMode = .personal,
        userSharePercent: Double = 100,
        targetType: BudgetTargetType = .fixed,
        incomePercentage: Double? = nil,
        thresholdOverride: Double? = nil,
        allocationKind: BudgetAllocationKind = .expense,
        reallocationEligible: Bool = false,
        destinationFinancialGoalId: String? = nil,
        destinationPortfolioListId: String? = nil
    ) {
        self.snapshotId = snapshotId
        self.title = title
        self.plannedAmount = plannedAmount
        self.pillar = pillar
        self.categoryId = categoryId
        self.splitMode = splitMode
        self.userSharePercent = userSharePercent
        self.targetType = targetType
        self.incomePercentage = incomePercentage
        self.thresholdOverride = thresholdOverride
        self.allocationKind = allocationKind
        self.reallocationEligible = reallocationEligible
        self.destinationFinancialGoalId = destinationFinancialGoalId
        self.destinationPortfolioListId = destinationPortfolioListId
    }

    enum CodingKeys: String, CodingKey {
        case snapshotId
        case title
        case plannedAmount
        case pillar
        case categoryId
        case splitMode
        case userSharePercent
        case targetType
        case incomePercentage
        case thresholdOverride
        case allocationKind
        case reallocationEligible
        case destinationFinancialGoalId
        case destinationPortfolioListId
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        snapshotId = try container.decode(String.self, forKey: .snapshotId)
        title = try container.decode(String.self, forKey: .title)
        plannedAmount = try container.decode(Double.self, forKey: .plannedAmount)
        pillar = try container.decode(BudgetPillar.self, forKey: .pillar)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        splitMode = try container.decodeIfPresent(ExpenseSplitMode.self, forKey: .splitMode) ?? .personal
        userSharePercent = try container.decodeIfPresent(Double.self, forKey: .userSharePercent) ?? 100
        targetType = try container.decodeIfPresent(BudgetTargetType.self, forKey: .targetType) ?? .fixed
        incomePercentage = try container.decodeIfPresent(Double.self, forKey: .incomePercentage)
        thresholdOverride = try container.decodeIfPresent(Double.self, forKey: .thresholdOverride)
        allocationKind = try container.decodeIfPresent(BudgetAllocationKind.self, forKey: .allocationKind) ?? .expense
        reallocationEligible = try container.decodeIfPresent(Bool.self, forKey: .reallocationEligible) ?? false
        destinationFinancialGoalId = try container.decodeIfPresent(String.self, forKey: .destinationFinancialGoalId)
        destinationPortfolioListId = try container.decodeIfPresent(String.self, forKey: .destinationPortfolioListId)
    }
}

public struct BudgetPlanItemResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let snapshotId: String
    public let title: String
    public let plannedAmount: Double
    public let pillar: BudgetPillar
    public let categoryId: String?
    public let splitMode: ExpenseSplitMode
    public let userSharePercent: Double
    public let targetType: BudgetTargetType
    public let incomePercentage: Double?
    public let thresholdOverride: Double?
    public let allocationKind: BudgetAllocationKind
    public let reallocationEligible: Bool
    public let destinationFinancialGoalId: String?
    public let destinationPortfolioListId: String?
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        snapshotId: String,
        title: String,
        plannedAmount: Double,
        pillar: BudgetPillar,
        categoryId: String? = nil,
        splitMode: ExpenseSplitMode = .personal,
        userSharePercent: Double = 100,
        targetType: BudgetTargetType = .fixed,
        incomePercentage: Double? = nil,
        thresholdOverride: Double? = nil,
        allocationKind: BudgetAllocationKind = .expense,
        reallocationEligible: Bool = false,
        destinationFinancialGoalId: String? = nil,
        destinationPortfolioListId: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.snapshotId = snapshotId
        self.title = title
        self.plannedAmount = plannedAmount
        self.pillar = pillar
        self.categoryId = categoryId
        self.splitMode = splitMode
        self.userSharePercent = userSharePercent
        self.targetType = targetType
        self.incomePercentage = incomePercentage
        self.thresholdOverride = thresholdOverride
        self.allocationKind = allocationKind
        self.reallocationEligible = reallocationEligible
        self.destinationFinancialGoalId = destinationFinancialGoalId
        self.destinationPortfolioListId = destinationPortfolioListId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, snapshotId, title, plannedAmount, pillar, categoryId, splitMode, userSharePercent
        case targetType, incomePercentage, thresholdOverride, allocationKind, reallocationEligible
        case destinationFinancialGoalId, destinationPortfolioListId, createdAt, updatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        snapshotId = try container.decode(String.self, forKey: .snapshotId)
        title = try container.decode(String.self, forKey: .title)
        plannedAmount = try container.decode(Double.self, forKey: .plannedAmount)
        pillar = try container.decode(BudgetPillar.self, forKey: .pillar)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        splitMode = try container.decodeIfPresent(ExpenseSplitMode.self, forKey: .splitMode) ?? .personal
        userSharePercent = try container.decodeIfPresent(Double.self, forKey: .userSharePercent) ?? 100
        targetType = try container.decodeIfPresent(BudgetTargetType.self, forKey: .targetType) ?? .fixed
        incomePercentage = try container.decodeIfPresent(Double.self, forKey: .incomePercentage)
        thresholdOverride = try container.decodeIfPresent(Double.self, forKey: .thresholdOverride)
        allocationKind = try container.decodeIfPresent(BudgetAllocationKind.self, forKey: .allocationKind) ?? .expense
        reallocationEligible = try container.decodeIfPresent(Bool.self, forKey: .reallocationEligible) ?? false
        destinationFinancialGoalId = try container.decodeIfPresent(String.self, forKey: .destinationFinancialGoalId)
        destinationPortfolioListId = try container.decodeIfPresent(String.self, forKey: .destinationPortfolioListId)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

// MARK: - Expense

public struct ExpenseRequest: Codable, Sendable, Equatable {
    public let title: String
    public let amount: Double
    public let pillar: BudgetPillar
    public let occurredOn: String // YYYY-MM-DD
    public let linkedPlanItemId: String?
    public let categoryId: String?
    public let splitMode: ExpenseSplitMode
    public let userSharePercent: Double
    public let foreignAmount: Double?
    public let foreignCurrency: String?
    public let exchangeRate: Double?
    public let notes: String?
    public let receiptMetadata: ExpenseReceiptMetadata?

    public init(
        title: String,
        amount: Double,
        pillar: BudgetPillar,
        occurredOn: String,
        linkedPlanItemId: String? = nil,
        categoryId: String? = nil,
        splitMode: ExpenseSplitMode = .personal,
        userSharePercent: Double = 100,
        foreignAmount: Double? = nil,
        foreignCurrency: String? = nil,
        exchangeRate: Double? = nil,
        notes: String? = nil,
        receiptMetadata: ExpenseReceiptMetadata? = nil
    ) {
        self.title = title
        self.amount = amount
        self.pillar = pillar
        self.occurredOn = occurredOn
        self.linkedPlanItemId = linkedPlanItemId
        self.categoryId = categoryId
        self.splitMode = splitMode
        self.userSharePercent = userSharePercent
        self.foreignAmount = foreignAmount
        self.foreignCurrency = foreignCurrency
        self.exchangeRate = exchangeRate
        self.notes = notes
        self.receiptMetadata = receiptMetadata
    }

    enum CodingKeys: String, CodingKey {
        case title
        case amount
        case pillar
        case occurredOn
        case linkedPlanItemId
        case categoryId
        case splitMode
        case userSharePercent
        case foreignAmount
        case foreignCurrency
        case exchangeRate
        case notes
        case receiptMetadata
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        amount = try container.decode(Double.self, forKey: .amount)
        pillar = try container.decode(BudgetPillar.self, forKey: .pillar)
        occurredOn = try container.decode(String.self, forKey: .occurredOn)
        linkedPlanItemId = try container.decodeIfPresent(String.self, forKey: .linkedPlanItemId)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        splitMode = try container.decodeIfPresent(ExpenseSplitMode.self, forKey: .splitMode) ?? .personal
        userSharePercent = try container.decodeIfPresent(Double.self, forKey: .userSharePercent) ?? 100
        foreignAmount = try container.decodeIfPresent(Double.self, forKey: .foreignAmount)
        foreignCurrency = try container.decodeIfPresent(String.self, forKey: .foreignCurrency)
        exchangeRate = try container.decodeIfPresent(Double.self, forKey: .exchangeRate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        receiptMetadata = try container.decodeIfPresent(ExpenseReceiptMetadata.self, forKey: .receiptMetadata)
    }
}

public struct ExpenseResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let amount: Double
    public let pillar: BudgetPillar
    public let occurredOn: String // YYYY-MM-DD
    public let linkedPlanItemId: String?
    public let categoryId: String?
    public let splitMode: ExpenseSplitMode
    public let userSharePercent: Double
    public let foreignAmount: Double?
    public let foreignCurrency: String?
    public let exchangeRate: Double?
    public let notes: String?
    public let receiptMetadata: ExpenseReceiptMetadata?
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        title: String,
        amount: Double,
        pillar: BudgetPillar,
        occurredOn: String,
        linkedPlanItemId: String? = nil,
        categoryId: String? = nil,
        splitMode: ExpenseSplitMode = .personal,
        userSharePercent: Double = 100,
        foreignAmount: Double? = nil,
        foreignCurrency: String? = nil,
        exchangeRate: Double? = nil,
        notes: String? = nil,
        receiptMetadata: ExpenseReceiptMetadata? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.pillar = pillar
        self.occurredOn = occurredOn
        self.linkedPlanItemId = linkedPlanItemId
        self.categoryId = categoryId
        self.splitMode = splitMode
        self.userSharePercent = userSharePercent
        self.foreignAmount = foreignAmount
        self.foreignCurrency = foreignCurrency
        self.exchangeRate = exchangeRate
        self.notes = notes
        self.receiptMetadata = receiptMetadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Reports

public struct PillarPlanningSummaryResponse: Codable, Sendable, Equatable {
    public let pillar: BudgetPillar
    public let targetAmount: Double
    public let plannedAmount: Double
    public let actualAmount: Double
    public let unplannedActualAmount: Double

    public init(
        pillar: BudgetPillar, targetAmount: Double, plannedAmount: Double, actualAmount: Double,
        unplannedActualAmount: Double
    ) {
        self.pillar = pillar
        self.targetAmount = targetAmount
        self.plannedAmount = plannedAmount
        self.actualAmount = actualAmount
        self.unplannedActualAmount = unplannedActualAmount
    }
}

public struct BudgetMonthSummaryResponse: Codable, Sendable, Equatable {
    public let monthStart: String // YYYY-MM-DD
    public let planned: Double
    public let actual: Double
    public let salary: Double
    public let myPlanned: Double
    public let partnerPlanned: Double
    public let myActual: Double
    public let partnerActual: Double
    public let pillarActuals: [String: Double]
    public let pillarPlans: [String: Double]
    public let myPillarActuals: [String: Double]
    public let partnerPillarActuals: [String: Double]
    public let myPillarPlans: [String: Double]
    public let partnerPillarPlans: [String: Double]

    public init(
        monthStart: String,
        planned: Double,
        actual: Double,
        salary: Double,
        myPlanned: Double = 0,
        partnerPlanned: Double = 0,
        myActual: Double = 0,
        partnerActual: Double = 0,
        pillarActuals: [String: Double],
        pillarPlans: [String: Double],
        myPillarActuals: [String: Double] = [:],
        partnerPillarActuals: [String: Double] = [:],
        myPillarPlans: [String: Double] = [:],
        partnerPillarPlans: [String: Double] = [:]
    ) {
        self.monthStart = monthStart
        self.planned = planned
        self.actual = actual
        self.salary = salary
        self.myPlanned = myPlanned
        self.partnerPlanned = partnerPlanned
        self.myActual = myActual
        self.partnerActual = partnerActual
        self.pillarActuals = pillarActuals
        self.pillarPlans = pillarPlans
        self.myPillarActuals = myPillarActuals
        self.partnerPillarActuals = partnerPillarActuals
        self.myPillarPlans = myPillarPlans
        self.partnerPillarPlans = partnerPillarPlans
    }
}

public struct BudgetYearSummaryResponse: Codable, Sendable, Equatable {
    public let year: Int
    public let planned: Double
    public let actual: Double
    public let salary: Double
    public let myPlanned: Double
    public let partnerPlanned: Double
    public let myActual: Double
    public let partnerActual: Double

    public init(
        year: Int,
        planned: Double,
        actual: Double,
        salary: Double,
        myPlanned: Double = 0,
        partnerPlanned: Double = 0,
        myActual: Double = 0,
        partnerActual: Double = 0
    ) {
        self.year = year
        self.planned = planned
        self.actual = actual
        self.salary = salary
        self.myPlanned = myPlanned
        self.partnerPlanned = partnerPlanned
        self.myActual = myActual
        self.partnerActual = partnerActual
    }
}

public struct ReportsCashFlowPointResponse: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        monthStart
    }

    public let monthStart: String
    public let income: Double
    public let expenses: Double
    public let net: Double
    public let savingsRate: Double

    public init(
        monthStart: String,
        income: Double,
        expenses: Double,
        net: Double,
        savingsRate: Double
    ) {
        self.monthStart = monthStart
        self.income = income
        self.expenses = expenses
        self.net = net
        self.savingsRate = savingsRate
    }
}

public struct ReportsOverviewResponse: Codable, Sendable, Equatable {
    public let generatedAt: String
    public let portfolioStatistics: ImportedStocksStatisticsDTO
    public let monthlySummaries: [BudgetMonthSummaryResponse]
    public let yearlySummaries: [BudgetYearSummaryResponse]
    public let latestMonthSummary: BudgetMonthSummaryResponse?
    public let latestPillarSummaries: [PillarPlanningSummaryResponse]
    public let cashFlow: [ReportsCashFlowPointResponse]

    public init(
        generatedAt: String,
        portfolioStatistics: ImportedStocksStatisticsDTO,
        monthlySummaries: [BudgetMonthSummaryResponse],
        yearlySummaries: [BudgetYearSummaryResponse],
        latestMonthSummary: BudgetMonthSummaryResponse?,
        latestPillarSummaries: [PillarPlanningSummaryResponse],
        cashFlow: [ReportsCashFlowPointResponse]
    ) {
        self.generatedAt = generatedAt
        self.portfolioStatistics = portfolioStatistics
        self.monthlySummaries = monthlySummaries
        self.yearlySummaries = yearlySummaries
        self.latestMonthSummary = latestMonthSummary
        self.latestPillarSummaries = latestPillarSummaries
        self.cashFlow = cashFlow
    }
}

public enum ReportSuggestionSeverity: String, Codable, Sendable, CaseIterable {
    case low
    case medium
    case high
}

public enum ReportSuggestionCategory: String, Codable, Sendable, CaseIterable {
    case overspend
    case unplannedSpend
    case savingsTrend
}

public struct ReportSuggestionResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let message: String
    public let severity: ReportSuggestionSeverity
    public let category: ReportSuggestionCategory
    public let monthStart: String
    public let recommendedSavings: Double
    public let detailPayload: [String: String]

    public init(
        id: String,
        title: String,
        message: String,
        severity: ReportSuggestionSeverity,
        category: ReportSuggestionCategory,
        monthStart: String,
        recommendedSavings: Double,
        detailPayload: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.severity = severity
        self.category = category
        self.monthStart = monthStart
        self.recommendedSavings = recommendedSavings
        self.detailPayload = detailPayload
    }
}

public struct ReportSuggestionsResponse: Codable, Sendable, Equatable {
    public let generatedAt: String
    public let suggestions: [ReportSuggestionResponse]

    public init(generatedAt: String, suggestions: [ReportSuggestionResponse]) {
        self.generatedAt = generatedAt
        self.suggestions = suggestions
    }
}
