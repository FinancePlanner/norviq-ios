import Foundation

public enum WealthAutomationValidationError: Error, Equatable, Sendable {
    case invalidName
    case invalidCurrency
    case invalidHorizon
    case invalidGrowthRate
    case invalidAmount
    case invalidScreen
    case invalidCondition
    case invalidAllocation
    case duplicateAllocation
    case missingTrigger
}

// MARK: - Net worth forecasting

public enum ForecastCashFlowSource: String, Codable, CaseIterable, Sendable {
    case plannedBudget = "planned_budget"
    case trailingActuals = "trailing_actuals"
    case manual
}

public struct NetWorthForecastDefinition: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let portfolioListId: String
    public let name: String
    public let baseCurrency: String
    public let horizonMonths: Int
    public let includeCash: Bool
    public let includeCrypto: Bool
    public let annualIncomeGrowth: Double
    public let annualSpendingGrowth: Double
    public let inflationAssumption: Double
    public let monthlyIncomeOverride: Double?
    public let monthlySpendingOverride: Double?
    public let targetAmount: Double?
    public let pathCount: Int
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        portfolioListId: String,
        name: String,
        baseCurrency: String,
        horizonMonths: Int = 360,
        includeCash: Bool = true,
        includeCrypto: Bool = false,
        annualIncomeGrowth: Double = 0,
        annualSpendingGrowth: Double = 0.02,
        inflationAssumption: Double = 0.02,
        monthlyIncomeOverride: Double? = nil,
        monthlySpendingOverride: Double? = nil,
        targetAmount: Double? = nil,
        pathCount: Int = 10000,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.portfolioListId = portfolioListId
        self.name = name
        self.baseCurrency = baseCurrency
        self.horizonMonths = horizonMonths
        self.includeCash = includeCash
        self.includeCrypto = includeCrypto
        self.annualIncomeGrowth = annualIncomeGrowth
        self.annualSpendingGrowth = annualSpendingGrowth
        self.inflationAssumption = inflationAssumption
        self.monthlyIncomeOverride = monthlyIncomeOverride
        self.monthlySpendingOverride = monthlySpendingOverride
        self.targetAmount = targetAmount
        self.pathCount = pathCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WealthAutomationValidationError.invalidName
        }
        guard baseCurrency.count == 3 else { throw WealthAutomationValidationError.invalidCurrency }
        guard (1 ... 600).contains(horizonMonths), (100 ... 50000).contains(pathCount) else {
            throw WealthAutomationValidationError.invalidHorizon
        }
        guard (-1 ... 10).contains(annualIncomeGrowth), (-1 ... 10).contains(annualSpendingGrowth),
              (-1 ... 10).contains(inflationAssumption)
        else {
            throw WealthAutomationValidationError.invalidGrowthRate
        }
        guard monthlyIncomeOverride.map({ $0 >= 0 }) ?? true,
              monthlySpendingOverride.map({ $0 >= 0 }) ?? true,
              targetAmount.map({ $0 > 0 }) ?? true
        else {
            throw WealthAutomationValidationError.invalidAmount
        }
    }
}

public struct NetWorthForecastUpsertRequest: Codable, Equatable, Sendable {
    public let name: String
    public let baseCurrency: String
    public let horizonMonths: Int
    public let includeCash: Bool
    public let includeCrypto: Bool
    public let annualIncomeGrowth: Double
    public let annualSpendingGrowth: Double
    public let inflationAssumption: Double
    public let monthlyIncomeOverride: Double?
    public let monthlySpendingOverride: Double?
    public let targetAmount: Double?
    public let pathCount: Int

    public init(
        name: String,
        baseCurrency: String,
        horizonMonths: Int = 360,
        includeCash: Bool = true,
        includeCrypto: Bool = false,
        annualIncomeGrowth: Double = 0,
        annualSpendingGrowth: Double = 0.02,
        inflationAssumption: Double = 0.02,
        monthlyIncomeOverride: Double? = nil,
        monthlySpendingOverride: Double? = nil,
        targetAmount: Double? = nil,
        pathCount: Int = 10000
    ) {
        self.name = name
        self.baseCurrency = baseCurrency
        self.horizonMonths = horizonMonths
        self.includeCash = includeCash
        self.includeCrypto = includeCrypto
        self.annualIncomeGrowth = annualIncomeGrowth
        self.annualSpendingGrowth = annualSpendingGrowth
        self.inflationAssumption = inflationAssumption
        self.monthlyIncomeOverride = monthlyIncomeOverride
        self.monthlySpendingOverride = monthlySpendingOverride
        self.targetAmount = targetAmount
        self.pathCount = pathCount
    }
}

public struct NetWorthForecastDefaults: Codable, Equatable, Sendable {
    public let baseCurrency: String
    public let monthlyIncome: Double
    public let monthlySpending: Double
    public let monthlyNetFlow: Double
    public let cashFlowSource: ForecastCashFlowSource
    public let includedFinancing: Double
    public let warnings: [String]

    public init(
        baseCurrency: String,
        monthlyIncome: Double,
        monthlySpending: Double,
        cashFlowSource: ForecastCashFlowSource,
        includedFinancing: Double = 0,
        warnings: [String] = []
    ) {
        self.baseCurrency = baseCurrency
        self.monthlyIncome = monthlyIncome
        self.monthlySpending = monthlySpending
        monthlyNetFlow = monthlyIncome - monthlySpending
        self.cashFlowSource = cashFlowSource
        self.includedFinancing = includedFinancing
        self.warnings = warnings
    }
}

public struct ForecastProbabilityBand: Codable, Equatable, Sendable {
    public let percentile: Int
    public let value: Double

    public init(percentile: Int, value: Double) {
        self.percentile = percentile
        self.value = value
    }
}

public struct NetWorthForecastPoint: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let month: Int
    public let date: String
    public let monthlyIncome: Double
    public let monthlySpending: Double
    public let bands: [ForecastProbabilityBand]

    public init(
        id: String,
        month: Int,
        date: String,
        monthlyIncome: Double,
        monthlySpending: Double,
        bands: [ForecastProbabilityBand]
    ) {
        self.id = id
        self.month = month
        self.date = date
        self.monthlyIncome = monthlyIncome
        self.monthlySpending = monthlySpending
        self.bands = bands
    }
}

public enum NetWorthForecastRunStatus: String, Codable, Sendable {
    case queued
    case running
    case completed
    case failed
}

public struct NetWorthForecastRun: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let forecastId: String
    public let status: NetWorthForecastRunStatus
    public let startingValue: Double
    public let assumptions: NetWorthForecastDefaults
    public let timeline: [NetWorthForecastPoint]
    public let targetProbability: Double?
    public let seed: UInt64?
    public let failureReason: String?
    public let createdAt: String
    public let completedAt: String?

    public init(
        id: String,
        forecastId: String,
        status: NetWorthForecastRunStatus,
        startingValue: Double,
        assumptions: NetWorthForecastDefaults,
        timeline: [NetWorthForecastPoint] = [],
        targetProbability: Double? = nil,
        seed: UInt64? = nil,
        failureReason: String? = nil,
        createdAt: String,
        completedAt: String? = nil
    ) {
        self.id = id
        self.forecastId = forecastId
        self.status = status
        self.startingValue = startingValue
        self.assumptions = assumptions
        self.timeline = timeline
        self.targetProbability = targetProbability
        self.seed = seed
        self.failureReason = failureReason
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

// MARK: - Watchlist screening

public enum ScreenLogicalOperator: String, Codable, CaseIterable, Sendable {
    case all
    case any
}

public enum ScreenComparison: String, Codable, CaseIterable, Sendable {
    case greaterThan = "greater_than"
    case greaterThanOrEqual = "greater_than_or_equal"
    case lessThan = "less_than"
    case lessThanOrEqual = "less_than_or_equal"
    case equal
    case improving
    case deteriorating
}

public enum ScreenPeriod: String, Codable, CaseIterable, Sendable {
    case ttm
    case annual
    case quarterly
}

public enum ScreenMetricCategory: String, Codable, CaseIterable, Sendable {
    case quote
    case valuation
    case profitability
    case growth
    case leverage
    case liquidity
    case cashFlow = "cash_flow"
    case dividend
}

public struct ScreenMetricDescriptor: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let category: ScreenMetricCategory
    public let supportedPeriods: [ScreenPeriod]
    public let supportedComparisons: [ScreenComparison]
    public let unit: String
    public let favorableDirection: String?

    public init(
        id: String,
        label: String,
        category: ScreenMetricCategory,
        supportedPeriods: [ScreenPeriod],
        supportedComparisons: [ScreenComparison],
        unit: String,
        favorableDirection: String? = nil
    ) {
        self.id = id
        self.label = label
        self.category = category
        self.supportedPeriods = supportedPeriods
        self.supportedComparisons = supportedComparisons
        self.unit = unit
        self.favorableDirection = favorableDirection
    }
}

public struct WatchlistScreenCondition: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let metric: String
    public let comparison: ScreenComparison
    public let period: ScreenPeriod
    public let value: Double?

    public init(id: String, metric: String, comparison: ScreenComparison, period: ScreenPeriod, value: Double? = nil) {
        self.id = id
        self.metric = metric
        self.comparison = comparison
        self.period = period
        self.value = value
    }

    public func validate() throws {
        guard !metric.isEmpty else { throw WealthAutomationValidationError.invalidCondition }
        let isTrend = comparison == .improving || comparison == .deteriorating
        guard isTrend ? value == nil : value?.isFinite == true else {
            throw WealthAutomationValidationError.invalidCondition
        }
    }
}

public struct WatchlistScreenGroup: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let logicalOperator: ScreenLogicalOperator
    public let conditions: [WatchlistScreenCondition]

    public init(id: String, logicalOperator: ScreenLogicalOperator, conditions: [WatchlistScreenCondition]) {
        self.id = id
        self.logicalOperator = logicalOperator
        self.conditions = conditions
    }
}

public struct WatchlistScreen: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let watchlistListIds: [String]
    public let logicalOperator: ScreenLogicalOperator
    public let groups: [WatchlistScreenGroup]
    public let alertsEnabled: Bool
    public let lastEvaluatedAt: String?
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        name: String,
        watchlistListIds: [String],
        logicalOperator: ScreenLogicalOperator,
        groups: [WatchlistScreenGroup],
        alertsEnabled: Bool = false,
        lastEvaluatedAt: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.watchlistListIds = watchlistListIds
        self.logicalOperator = logicalOperator
        self.groups = groups
        self.alertsEnabled = alertsEnabled
        self.lastEvaluatedAt = lastEvaluatedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WealthAutomationValidationError.invalidName
        }
        guard !watchlistListIds.isEmpty, !groups.isEmpty, groups.count <= 10,
              groups.allSatisfy({ !$0.conditions.isEmpty && $0.conditions.count <= 20 })
        else {
            throw WealthAutomationValidationError.invalidScreen
        }
        for group in groups {
            for condition in group.conditions {
                try condition.validate()
            }
        }
    }
}

public struct WatchlistScreenUpsertRequest: Codable, Equatable, Sendable {
    public let name: String
    public let watchlistListIds: [String]
    public let logicalOperator: ScreenLogicalOperator
    public let groups: [WatchlistScreenGroup]
    public let alertsEnabled: Bool

    public init(
        name: String,
        watchlistListIds: [String],
        logicalOperator: ScreenLogicalOperator,
        groups: [WatchlistScreenGroup],
        alertsEnabled: Bool = false
    ) {
        self.name = name
        self.watchlistListIds = watchlistListIds
        self.logicalOperator = logicalOperator
        self.groups = groups
        self.alertsEnabled = alertsEnabled
    }
}

public struct ScreenConditionResult: Codable, Equatable, Sendable {
    public let conditionId: String
    public let matched: Bool
    public let value: Double?
    public let previousValue: Double?
    public let explanation: String

    public init(
        conditionId: String,
        matched: Bool,
        value: Double? = nil,
        previousValue: Double? = nil,
        explanation: String
    ) {
        self.conditionId = conditionId
        self.matched = matched
        self.value = value
        self.previousValue = previousValue
        self.explanation = explanation
    }
}

public struct WatchlistScreenMatch: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let symbol: String
    public let name: String?
    public let isNew: Bool
    public let conditionResults: [ScreenConditionResult]

    public init(
        id: String,
        symbol: String,
        name: String? = nil,
        isNew: Bool,
        conditionResults: [ScreenConditionResult]
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.isNew = isNew
        self.conditionResults = conditionResults
    }
}

public struct WatchlistScreenEvaluation: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let screenId: String
    public let evaluatedAt: String
    public let symbolCount: Int
    public let matches: [WatchlistScreenMatch]
    public let isAlertBaseline: Bool

    public init(
        id: String,
        screenId: String,
        evaluatedAt: String,
        symbolCount: Int,
        matches: [WatchlistScreenMatch],
        isAlertBaseline: Bool
    ) {
        self.id = id
        self.screenId = screenId
        self.evaluatedAt = evaluatedAt
        self.symbolCount = symbolCount
        self.matches = matches
        self.isAlertBaseline = isAlertBaseline
    }
}

// MARK: - Rebalancing

public enum RebalanceCadence: String, Codable, CaseIterable, Sendable {
    case disabled
    case monthly
    case quarterly
    case semiannual
    case annual
}

public enum RebalanceAssetKind: String, Codable, CaseIterable, Sendable {
    case symbol
    case cash
}

public struct RebalanceTarget: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: RebalanceAssetKind
    public let symbol: String?
    public let targetWeight: Double

    public init(id: String, kind: RebalanceAssetKind, symbol: String? = nil, targetWeight: Double) {
        self.id = id
        self.kind = kind
        self.symbol = symbol
        self.targetWeight = targetWeight
    }
}

public struct RebalancingPolicy: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let portfolioListId: String
    public let baseCurrency: String
    public let cadence: RebalanceCadence
    public let driftThreshold: Double?
    public let targets: [RebalanceTarget]
    public let enabled: Bool
    public let lastConfirmedAt: String?
    public let lastTriggeredAt: String?
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        portfolioListId: String,
        baseCurrency: String,
        cadence: RebalanceCadence,
        driftThreshold: Double? = nil,
        targets: [RebalanceTarget],
        enabled: Bool = true,
        lastConfirmedAt: String? = nil,
        lastTriggeredAt: String? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.portfolioListId = portfolioListId
        self.baseCurrency = baseCurrency.uppercased()
        self.cadence = cadence
        self.driftThreshold = driftThreshold
        self.targets = targets
        self.enabled = enabled
        self.lastConfirmedAt = lastConfirmedAt
        self.lastTriggeredAt = lastTriggeredAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func validate() throws {
        guard baseCurrency.count == 3, baseCurrency.allSatisfy(\.isLetter) else {
            throw WealthAutomationValidationError.invalidCurrency
        }
        guard cadence != .disabled || driftThreshold != nil else {
            throw WealthAutomationValidationError.missingTrigger
        }
        guard driftThreshold.map({ $0 > 0 && $0 <= 1 }) ?? true else {
            throw WealthAutomationValidationError.invalidAllocation
        }
        guard !targets.isEmpty, abs(targets.reduce(0) { $0 + $1.targetWeight } - 1) < 0.0001,
              targets.allSatisfy({ $0.targetWeight >= 0 && $0.targetWeight <= 1 })
        else {
            throw WealthAutomationValidationError.invalidAllocation
        }
        let keys = targets.map { $0.kind == .cash ? "cash" : "symbol:\($0.symbol?.uppercased() ?? "")" }
        guard Set(keys).count == keys.count,
              targets.allSatisfy({ $0.kind == .cash || !($0.symbol?.isEmpty ?? true) })
        else {
            throw WealthAutomationValidationError.duplicateAllocation
        }
    }
}

public struct RebalancingPolicyUpsertRequest: Codable, Equatable, Sendable {
    public let baseCurrency: String
    public let cadence: RebalanceCadence
    public let driftThreshold: Double?
    public let targets: [RebalanceTarget]
    public let enabled: Bool

    public init(
        baseCurrency: String,
        cadence: RebalanceCadence,
        driftThreshold: Double? = nil,
        targets: [RebalanceTarget],
        enabled: Bool = true
    ) {
        self.baseCurrency = baseCurrency.uppercased()
        self.cadence = cadence
        self.driftThreshold = driftThreshold
        self.targets = targets
        self.enabled = enabled
    }
}

public enum RebalanceAction: String, Codable, CaseIterable, Sendable {
    case buy
    case sell
    case hold
}

public struct RebalanceTradeDraft: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: RebalanceAssetKind
    public let symbol: String?
    public let action: RebalanceAction
    public let currentWeight: Double
    public let targetWeight: Double
    public let amount: Double
    public let approximateShares: Double?

    public init(
        id: String,
        kind: RebalanceAssetKind,
        symbol: String? = nil,
        action: RebalanceAction,
        currentWeight: Double,
        targetWeight: Double,
        amount: Double,
        approximateShares: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.symbol = symbol
        self.action = action
        self.currentWeight = currentWeight
        self.targetWeight = targetWeight
        self.amount = amount
        self.approximateShares = approximateShares
    }
}

public enum RebalanceTriggerReason: String, Codable, CaseIterable, Sendable {
    case cadence
    case drift
    case manual
}

public struct RebalancePreview: Codable, Equatable, Sendable {
    public let portfolioValue: Double
    public let currency: String
    public let maximumDrift: Double
    public let triggerReasons: [RebalanceTriggerReason]
    public let trades: [RebalanceTradeDraft]
    public let warnings: [String]

    public init(
        portfolioValue: Double,
        currency: String,
        maximumDrift: Double,
        triggerReasons: [RebalanceTriggerReason],
        trades: [RebalanceTradeDraft],
        warnings: [String] = []
    ) {
        self.portfolioValue = portfolioValue
        self.currency = currency
        self.maximumDrift = maximumDrift
        self.triggerReasons = triggerReasons
        self.trades = trades
        self.warnings = warnings
    }
}

public enum RebalanceEventStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case confirmed
    case dismissed
}

public struct RebalanceEvent: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let policyId: String
    public let status: RebalanceEventStatus
    public let preview: RebalancePreview
    public let createdAt: String
    public let confirmedAt: String?
    public let dismissedAt: String?

    public init(
        id: String,
        policyId: String,
        status: RebalanceEventStatus,
        preview: RebalancePreview,
        createdAt: String,
        confirmedAt: String? = nil,
        dismissedAt: String? = nil
    ) {
        self.id = id
        self.policyId = policyId
        self.status = status
        self.preview = preview
        self.createdAt = createdAt
        self.confirmedAt = confirmedAt
        self.dismissedAt = dismissedAt
    }
}

// MARK: - Notification inbox

public enum NotificationEventKind: String, Codable, CaseIterable, Sendable {
    case priceTarget = "price_target"
    case budget
    case earnings
    case tax
    case watchlistScreen = "watchlist_screen"
    case rebalancing
    case financialGoal = "financial_goal"
    case thesisWatch = "thesis_watch"
}

public struct NotificationInboxItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: NotificationEventKind
    public let title: String
    public let body: String
    public let deepLink: String?
    public let payload: [String: String]
    public let createdAt: String
    public let readAt: String?

    public init(
        id: String,
        kind: NotificationEventKind,
        title: String,
        body: String,
        deepLink: String? = nil,
        payload: [String: String] = [:],
        createdAt: String,
        readAt: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.deepLink = deepLink
        self.payload = payload
        self.createdAt = createdAt
        self.readAt = readAt
    }
}

public struct NotificationInboxPage: Codable, Equatable, Sendable {
    public let items: [NotificationInboxItem]
    public let unreadCount: Int
    public let nextCursor: String?

    public init(items: [NotificationInboxItem], unreadCount: Int, nextCursor: String? = nil) {
        self.items = items
        self.unreadCount = unreadCount
        self.nextCursor = nextCursor
    }
}

public struct NotificationReadRequest: Codable, Equatable, Sendable {
    public let read: Bool
    public init(read: Bool = true) {
        self.read = read
    }
}
