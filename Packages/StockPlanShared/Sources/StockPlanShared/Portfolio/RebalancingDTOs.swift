import Foundation

public enum AllocationGroupingMode: String, Codable, Sendable, Equatable, CaseIterable {
    case holding
    case sector
    case custom
}

public enum AllocationTargetKind: String, Codable, Sendable, Equatable, CaseIterable {
    case security
    case cash
}

public enum RebalancingPriceQuality: String, Codable, Sendable, Equatable {
    case live
    case stale
    case incomplete
}

public enum RebalancingDriftSeverity: String, Codable, Sendable, Equatable {
    case balanced
    case warning
    case breached
    case unavailable
}

public enum RebalanceTradeSide: String, Codable, Sendable, Equatable {
    case buy
    case sell
}

public enum RebalancePlanStatus: String, Codable, Sendable, Equatable {
    case draft
    case exported
    case completed
    case cancelled
}

public enum RebalancingAlertStatus: String, Codable, Sendable, Equatable {
    case open
    case acknowledged
    case resolved
}

public struct AllocationTargetLeaf: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: AllocationTargetKind
    public let symbol: String?
    public let name: String
    public let targetBasisPoints: Int
    public let alertThresholdBasisPoints: Int?
    public let sortOrder: Int

    public init(
        id: String,
        kind: AllocationTargetKind,
        symbol: String? = nil,
        name: String,
        targetBasisPoints: Int,
        alertThresholdBasisPoints: Int? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.symbol = symbol
        self.name = name
        self.targetBasisPoints = targetBasisPoints
        self.alertThresholdBasisPoints = alertThresholdBasisPoints
        self.sortOrder = sortOrder
    }
}

public struct AllocationTargetBucket: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let targetBasisPoints: Int
    public let alertThresholdBasisPoints: Int?
    public let sectorKey: String?
    public let sortOrder: Int
    public let leaves: [AllocationTargetLeaf]

    public init(
        id: String,
        name: String,
        targetBasisPoints: Int,
        alertThresholdBasisPoints: Int? = nil,
        sectorKey: String? = nil,
        sortOrder: Int = 0,
        leaves: [AllocationTargetLeaf]
    ) {
        self.id = id
        self.name = name
        self.targetBasisPoints = targetBasisPoints
        self.alertThresholdBasisPoints = alertThresholdBasisPoints
        self.sectorKey = sectorKey
        self.sortOrder = sortOrder
        self.leaves = leaves
    }
}

public struct AllocationModel: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let portfolioId: String
    public let name: String
    public let groupingMode: AllocationGroupingMode
    public let isActive: Bool
    public let revision: Int
    public let baseCurrency: String
    public let defaultTargetThresholdBasisPoints: Int
    public let totalThresholdBasisPoints: Int
    public let fractionalSharesEnabled: Bool
    public let quantityIncrement: Double
    public let minimumTradeAmount: Double
    public let flatFee: Double
    public let variableFeeBasisPoints: Int
    public let buckets: [AllocationTargetBucket]
    public let createdAt: String
    public let updatedAt: String?

    public init(
        id: String,
        portfolioId: String,
        name: String,
        groupingMode: AllocationGroupingMode,
        isActive: Bool,
        revision: Int,
        baseCurrency: String,
        defaultTargetThresholdBasisPoints: Int = 500,
        totalThresholdBasisPoints: Int = 300,
        fractionalSharesEnabled: Bool = true,
        quantityIncrement: Double = 0.001,
        minimumTradeAmount: Double = 1,
        flatFee: Double = 0,
        variableFeeBasisPoints: Int = 0,
        buckets: [AllocationTargetBucket],
        createdAt: String,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.portfolioId = portfolioId
        self.name = name
        self.groupingMode = groupingMode
        self.isActive = isActive
        self.revision = revision
        self.baseCurrency = baseCurrency
        self.defaultTargetThresholdBasisPoints = defaultTargetThresholdBasisPoints
        self.totalThresholdBasisPoints = totalThresholdBasisPoints
        self.fractionalSharesEnabled = fractionalSharesEnabled
        self.quantityIncrement = quantityIncrement
        self.minimumTradeAmount = minimumTradeAmount
        self.flatFee = flatFee
        self.variableFeeBasisPoints = variableFeeBasisPoints
        self.buckets = buckets
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AllocationModelUpsertRequest: Codable, Sendable, Equatable {
    public let name: String
    public let groupingMode: AllocationGroupingMode
    public let expectedRevision: Int?
    public let activate: Bool
    public let defaultTargetThresholdBasisPoints: Int
    public let totalThresholdBasisPoints: Int
    public let fractionalSharesEnabled: Bool
    public let quantityIncrement: Double
    public let minimumTradeAmount: Double
    public let flatFee: Double
    public let variableFeeBasisPoints: Int
    public let buckets: [AllocationTargetBucket]

    public init(
        name: String,
        groupingMode: AllocationGroupingMode,
        expectedRevision: Int? = nil,
        activate: Bool = true,
        defaultTargetThresholdBasisPoints: Int = 500,
        totalThresholdBasisPoints: Int = 300,
        fractionalSharesEnabled: Bool = true,
        quantityIncrement: Double = 0.001,
        minimumTradeAmount: Double = 1,
        flatFee: Double = 0,
        variableFeeBasisPoints: Int = 0,
        buckets: [AllocationTargetBucket]
    ) {
        self.name = name
        self.groupingMode = groupingMode
        self.expectedRevision = expectedRevision
        self.activate = activate
        self.defaultTargetThresholdBasisPoints = defaultTargetThresholdBasisPoints
        self.totalThresholdBasisPoints = totalThresholdBasisPoints
        self.fractionalSharesEnabled = fractionalSharesEnabled
        self.quantityIncrement = quantityIncrement
        self.minimumTradeAmount = minimumTradeAmount
        self.flatFee = flatFee
        self.variableFeeBasisPoints = variableFeeBasisPoints
        self.buckets = buckets
    }
}

public struct RebalancingValuationWarning: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        "\(code):\(symbol ?? "portfolio")"
    }

    public let code: String
    public let symbol: String?
    public let message: String

    public init(code: String, symbol: String? = nil, message: String) {
        self.code = code
        self.symbol = symbol
        self.message = message
    }
}

public struct RebalancingAllocationRow: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let symbol: String?
    public let targetBasisPoints: Int
    public let currentBasisPoints: Int
    public let driftBasisPoints: Int
    public let currentValue: Double
    public let targetValue: Double
    public let driftValue: Double
    public let severity: RebalancingDriftSeverity
    public let children: [RebalancingAllocationRow]

    public init(
        id: String,
        label: String,
        symbol: String? = nil,
        targetBasisPoints: Int,
        currentBasisPoints: Int,
        driftBasisPoints: Int,
        currentValue: Double,
        targetValue: Double,
        driftValue: Double,
        severity: RebalancingDriftSeverity,
        children: [RebalancingAllocationRow] = []
    ) {
        self.id = id
        self.label = label
        self.symbol = symbol
        self.targetBasisPoints = targetBasisPoints
        self.currentBasisPoints = currentBasisPoints
        self.driftBasisPoints = driftBasisPoints
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.driftValue = driftValue
        self.severity = severity
        self.children = children
    }
}

public struct RebalancingOverview: Codable, Sendable, Equatable {
    public let portfolioId: String
    public let model: AllocationModel?
    public let baseCurrency: String
    public let totalValue: Double
    public let totalDriftBasisPoints: Int
    public let severity: RebalancingDriftSeverity
    public let priceQuality: RebalancingPriceQuality
    public let pricedAt: String?
    public let openAlertCount: Int
    public let rows: [RebalancingAllocationRow]
    public let warnings: [RebalancingValuationWarning]

    public init(
        portfolioId: String,
        model: AllocationModel?,
        baseCurrency: String,
        totalValue: Double,
        totalDriftBasisPoints: Int,
        severity: RebalancingDriftSeverity,
        priceQuality: RebalancingPriceQuality,
        pricedAt: String? = nil,
        openAlertCount: Int = 0,
        rows: [RebalancingAllocationRow],
        warnings: [RebalancingValuationWarning] = []
    ) {
        self.portfolioId = portfolioId
        self.model = model
        self.baseCurrency = baseCurrency
        self.totalValue = totalValue
        self.totalDriftBasisPoints = totalDriftBasisPoints
        self.severity = severity
        self.priceQuality = priceQuality
        self.pricedAt = pricedAt
        self.openAlertCount = openAlertCount
        self.rows = rows
        self.warnings = warnings
    }
}

public struct RebalanceTradeOverride: Codable, Sendable, Equatable {
    public let symbol: String
    public let amount: Double

    public init(symbol: String, amount: Double) {
        self.symbol = symbol
        self.amount = amount
    }
}

public struct RebalancingSimulationRequest: Codable, Sendable, Equatable {
    public let modelId: String
    public let modelRevision: Int
    public let cashFlow: Double
    public let overrides: [RebalanceTradeOverride]

    public init(modelId: String, modelRevision: Int, cashFlow: Double = 0, overrides: [RebalanceTradeOverride] = []) {
        self.modelId = modelId
        self.modelRevision = modelRevision
        self.cashFlow = cashFlow
        self.overrides = overrides
    }
}

public struct RebalanceTrade: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        "\(side.rawValue):\(symbol)"
    }

    public let symbol: String
    public let side: RebalanceTradeSide
    public let quantity: Double
    public let price: Double
    public let notional: Double
    public let estimatedFee: Double
    public let estimatedCostBasis: Double?
    public let estimatedRealizedGainLoss: Double?
    public let currency: String
    public let accountId: String?
    public let instrumentId: String?
    public let selectedLotIds: [String]?
    public let sourceOpportunityId: String?
    public let replacementForInstrumentId: String?

    public init(
        symbol: String,
        side: RebalanceTradeSide,
        quantity: Double,
        price: Double,
        notional: Double,
        estimatedFee: Double,
        estimatedCostBasis: Double? = nil,
        estimatedRealizedGainLoss: Double? = nil,
        currency: String,
        accountId: String? = nil,
        instrumentId: String? = nil,
        selectedLotIds: [String]? = nil,
        sourceOpportunityId: String? = nil,
        replacementForInstrumentId: String? = nil
    ) {
        self.symbol = symbol
        self.side = side
        self.quantity = quantity
        self.price = price
        self.notional = notional
        self.estimatedFee = estimatedFee
        self.estimatedCostBasis = estimatedCostBasis
        self.estimatedRealizedGainLoss = estimatedRealizedGainLoss
        self.currency = currency
        self.accountId = accountId
        self.instrumentId = instrumentId
        self.selectedLotIds = selectedLotIds
        self.sourceOpportunityId = sourceOpportunityId
        self.replacementForInstrumentId = replacementForInstrumentId
    }
}

public struct RebalancingSimulation: Codable, Sendable, Equatable {
    public let portfolioId: String
    public let modelId: String
    public let modelRevision: Int
    public let baseCurrency: String
    public let totalValueBefore: Double
    public let totalValueAfter: Double
    public let driftBeforeBasisPoints: Int
    public let driftAfterBasisPoints: Int
    public let estimatedFees: Double
    public let estimatedRealizedGainLoss: Double
    public let trades: [RebalanceTrade]
    public let before: [RebalancingAllocationRow]
    public let after: [RebalancingAllocationRow]
    public let warnings: [RebalancingValuationWarning]
    public let pricedAt: String?

    public init(
        portfolioId: String,
        modelId: String,
        modelRevision: Int,
        baseCurrency: String,
        totalValueBefore: Double,
        totalValueAfter: Double,
        driftBeforeBasisPoints: Int,
        driftAfterBasisPoints: Int,
        estimatedFees: Double,
        estimatedRealizedGainLoss: Double,
        trades: [RebalanceTrade],
        before: [RebalancingAllocationRow],
        after: [RebalancingAllocationRow],
        warnings: [RebalancingValuationWarning] = [],
        pricedAt: String? = nil
    ) {
        self.portfolioId = portfolioId
        self.modelId = modelId
        self.modelRevision = modelRevision
        self.baseCurrency = baseCurrency
        self.totalValueBefore = totalValueBefore
        self.totalValueAfter = totalValueAfter
        self.driftBeforeBasisPoints = driftBeforeBasisPoints
        self.driftAfterBasisPoints = driftAfterBasisPoints
        self.estimatedFees = estimatedFees
        self.estimatedRealizedGainLoss = estimatedRealizedGainLoss
        self.trades = trades
        self.before = before
        self.after = after
        self.warnings = warnings
        self.pricedAt = pricedAt
    }
}

public struct RebalancePlanCreateRequest: Codable, Sendable, Equatable {
    public let name: String?
    public let simulation: RebalancingSimulationRequest

    public init(name: String? = nil, simulation: RebalancingSimulationRequest) {
        self.name = name
        self.simulation = simulation
    }
}

public struct RebalancePlan: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let portfolioId: String
    public let modelId: String
    public let modelRevision: Int
    public let name: String?
    public let status: RebalancePlanStatus
    public let baseCurrency: String
    public let driftBeforeBasisPoints: Int
    public let driftAfterBasisPoints: Int
    public let totalValue: Double
    public let estimatedFees: Double
    public let estimatedRealizedGainLoss: Double
    public let trades: [RebalanceTrade]
    public let createdAt: String
    public let exportedAt: String?
    public let completedAt: String?
    public let cancelledAt: String?

    public init(
        id: String,
        portfolioId: String,
        modelId: String,
        modelRevision: Int,
        name: String? = nil,
        status: RebalancePlanStatus,
        baseCurrency: String,
        driftBeforeBasisPoints: Int,
        driftAfterBasisPoints: Int,
        totalValue: Double,
        estimatedFees: Double,
        estimatedRealizedGainLoss: Double,
        trades: [RebalanceTrade],
        createdAt: String,
        exportedAt: String? = nil,
        completedAt: String? = nil,
        cancelledAt: String? = nil
    ) {
        self.id = id
        self.portfolioId = portfolioId
        self.modelId = modelId
        self.modelRevision = modelRevision
        self.name = name
        self.status = status
        self.baseCurrency = baseCurrency
        self.driftBeforeBasisPoints = driftBeforeBasisPoints
        self.driftAfterBasisPoints = driftAfterBasisPoints
        self.totalValue = totalValue
        self.estimatedFees = estimatedFees
        self.estimatedRealizedGainLoss = estimatedRealizedGainLoss
        self.trades = trades
        self.createdAt = createdAt
        self.exportedAt = exportedAt
        self.completedAt = completedAt
        self.cancelledAt = cancelledAt
    }
}

public struct RebalancePlanCompletionRequest: Codable, Sendable, Equatable {
    public let note: String?

    public init(note: String? = nil) {
        self.note = note
    }
}

public struct RebalancingHistorySummary: Codable, Sendable, Equatable {
    public let completedCount: Int
    public let averageDriftBeforeBasisPoints: Int
    public let averageDriftAfterBasisPoints: Int
    public let averageDaysBetweenRebalances: Double?
    public let lastCompletedAt: String?

    public init(
        completedCount: Int,
        averageDriftBeforeBasisPoints: Int,
        averageDriftAfterBasisPoints: Int,
        averageDaysBetweenRebalances: Double? = nil,
        lastCompletedAt: String? = nil
    ) {
        self.completedCount = completedCount
        self.averageDriftBeforeBasisPoints = averageDriftBeforeBasisPoints
        self.averageDriftAfterBasisPoints = averageDriftAfterBasisPoints
        self.averageDaysBetweenRebalances = averageDaysBetweenRebalances
        self.lastCompletedAt = lastCompletedAt
    }
}

public struct RebalancingAlert: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let portfolioId: String
    public let modelId: String
    public let scopeId: String
    public let scopeName: String
    public let driftBasisPoints: Int
    public let thresholdBasisPoints: Int
    public let status: RebalancingAlertStatus
    public let triggeredAt: String
    public let acknowledgedAt: String?
    public let resolvedAt: String?

    public init(
        id: String,
        portfolioId: String,
        modelId: String,
        scopeId: String,
        scopeName: String,
        driftBasisPoints: Int,
        thresholdBasisPoints: Int,
        status: RebalancingAlertStatus,
        triggeredAt: String,
        acknowledgedAt: String? = nil,
        resolvedAt: String? = nil
    ) {
        self.id = id
        self.portfolioId = portfolioId
        self.modelId = modelId
        self.scopeId = scopeId
        self.scopeName = scopeName
        self.driftBasisPoints = driftBasisPoints
        self.thresholdBasisPoints = thresholdBasisPoints
        self.status = status
        self.triggeredAt = triggeredAt
        self.acknowledgedAt = acknowledgedAt
        self.resolvedAt = resolvedAt
    }
}

public struct RebalancingNotificationPreferences: Codable, Sendable, Equatable {
    public let portfolioId: String
    public let pushEnabled: Bool

    public init(portfolioId: String, pushEnabled: Bool) {
        self.portfolioId = portfolioId
        self.pushEnabled = pushEnabled
    }
}

public struct UpdateRebalancingNotificationPreferencesRequest: Codable, Sendable, Equatable {
    public let pushEnabled: Bool

    public init(pushEnabled: Bool) {
        self.pushEnabled = pushEnabled
    }
}

public struct AllocationModelBulkCopyRequest: Codable, Sendable, Equatable {
    public let destinationPortfolioIds: [String]
    public let activate: Bool

    public init(destinationPortfolioIds: [String], activate: Bool = true) {
        self.destinationPortfolioIds = destinationPortfolioIds
        self.activate = activate
    }
}

public struct AllocationModelBulkCopyResult: Codable, Sendable, Equatable {
    public let models: [AllocationModel]
    public let warnings: [RebalancingValuationWarning]

    public init(models: [AllocationModel], warnings: [RebalancingValuationWarning] = []) {
        self.models = models
        self.warnings = warnings
    }
}

public struct RebalancingDashboardSummary: Codable, Sendable, Equatable {
    public let openAlertCount: Int
    public let breachedPortfolioCount: Int
    public let portfolios: [RebalancingOverview]

    public init(openAlertCount: Int, breachedPortfolioCount: Int, portfolios: [RebalancingOverview]) {
        self.openAlertCount = openAlertCount
        self.breachedPortfolioCount = breachedPortfolioCount
        self.portfolios = portfolios
    }
}
