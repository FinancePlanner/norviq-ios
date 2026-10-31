import Foundation

public enum ScenarioValidationError: Error, Equatable, Sendable {
    case invalidName
    case invalidCurrency
    case invalidAmount
    case invalidHorizon
    case invalidPathCount
    case invalidDegreesOfFreedom
    case tooManyComparisons
}

public struct FactorOverrides: Codable, Equatable, Sendable {
    public let equityBeta: Double?
    public let rateSensitivity: Double?
    public let volatility: Double?

    public init(equityBeta: Double? = nil, rateSensitivity: Double? = nil, volatility: Double? = nil) {
        self.equityBeta = equityBeta
        self.rateSensitivity = rateSensitivity
        self.volatility = volatility
    }
}

public struct HoldingRiskProfile: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let holdingId: String
    public let assetCategory: AssetCategory
    public let sector: String?
    public let region: String?
    public let benchmarkProxy: String?
    public let manualValue: Double?
    public let duration: Double?
    public let convexity: Double?
    public let factorOverrides: FactorOverrides?

    public init(
        id: String,
        holdingId: String,
        assetCategory: AssetCategory,
        sector: String? = nil,
        region: String? = nil,
        benchmarkProxy: String? = nil,
        manualValue: Double? = nil,
        duration: Double? = nil,
        convexity: Double? = nil,
        factorOverrides: FactorOverrides? = nil
    ) {
        self.id = id
        self.holdingId = holdingId
        self.assetCategory = assetCategory
        self.sector = sector
        self.region = region
        self.benchmarkProxy = benchmarkProxy
        self.manualValue = manualValue
        self.duration = duration
        self.convexity = convexity
        self.factorOverrides = factorOverrides
    }
}

public enum ScenarioDataWarningCode: String, Codable, Sendable {
    case stalePrice = "stale_price"
    case manualValuation = "manual_valuation"
    case proxyUsed = "proxy_used"
    case missingHistory = "missing_history"
    case staleFX = "stale_fx"
}

public struct ScenarioDataWarning: Codable, Equatable, Sendable {
    public let code: ScenarioDataWarningCode
    public let holdingId: String?
    public let message: String

    public init(code: ScenarioDataWarningCode, holdingId: String? = nil, message: String) {
        self.code = code
        self.holdingId = holdingId
        self.message = message
    }
}

public struct ScenarioSnapshotHolding: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let instrumentKey: String
    public let symbol: String
    public let quantity: Double
    public let price: Double
    public let currency: String
    public let valueInBaseCurrency: Double
    public let riskProfile: HoldingRiskProfile

    public init(
        id: String,
        instrumentKey: String,
        symbol: String,
        quantity: Double,
        price: Double,
        currency: String,
        valueInBaseCurrency: Double,
        riskProfile: HoldingRiskProfile
    ) {
        self.id = id
        self.instrumentKey = instrumentKey
        self.symbol = symbol
        self.quantity = quantity
        self.price = price
        self.currency = currency
        self.valueInBaseCurrency = valueInBaseCurrency
        self.riskProfile = riskProfile
    }
}

public struct PortfolioScenarioSnapshot: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let portfolioListId: String
    public let baseCurrency: String
    public let valuationTimestamp: String
    public let holdings: [ScenarioSnapshotHolding]
    public let fxRates: [String: Double]
    public let warnings: [ScenarioDataWarning]
    public let createdAt: String

    public init(
        id: String,
        portfolioListId: String,
        baseCurrency: String,
        valuationTimestamp: String,
        holdings: [ScenarioSnapshotHolding],
        fxRates: [String: Double],
        warnings: [ScenarioDataWarning] = [],
        createdAt: String
    ) {
        self.id = id
        self.portfolioListId = portfolioListId
        self.baseCurrency = baseCurrency
        self.valuationTimestamp = valuationTimestamp
        self.holdings = holdings
        self.fxRates = fxRates
        self.warnings = warnings
        self.createdAt = createdAt
    }
}

public enum ScenarioKind: String, Codable, CaseIterable,
    Sendable { case historical, custom, monteCarlo = "monte_carlo" }
public enum RecoveryModel: String, Codable, CaseIterable,
    Sendable { case none, linear, meanReverting = "mean_reverting" }
public enum MonteCarloDistribution: String, Codable, CaseIterable,
    Sendable { case blockBootstrap = "block_bootstrap", normal, studentT = "student_t" }

public struct HistoricalScenarioConfiguration: Codable, Equatable, Sendable {
    public let catalogId: String
    public init(catalogId: String) {
        self.catalogId = catalogId
    }
}

public struct PercentageShock: Codable, Equatable, Sendable {
    public let target: String
    public let percentage: Double
    public init(target: String, percentage: Double) {
        self.target = target; self.percentage = percentage
    }
}

public struct CustomScenarioConfiguration: Codable, Equatable, Sendable {
    public let holdingShocks: [PercentageShock]
    public let sectorShocks: [PercentageShock]
    public let regionShocks: [PercentageShock]
    public let currencyShocks: [PercentageShock]
    public let assetClassShocks: [PercentageShock]
    public let parallelRateShiftBps: Double
    public let volatilityMultiplier: Double
    public let horizonMonths: Int
    public let recovery: RecoveryModel

    public init(
        holdingShocks: [PercentageShock] = [],
        sectorShocks: [PercentageShock] = [],
        regionShocks: [PercentageShock] = [],
        currencyShocks: [PercentageShock] = [],
        assetClassShocks: [PercentageShock] = [],
        parallelRateShiftBps: Double = 0,
        volatilityMultiplier: Double = 1,
        horizonMonths: Int,
        recovery: RecoveryModel = .none
    ) {
        self.holdingShocks = holdingShocks; self.sectorShocks = sectorShocks
        self.regionShocks = regionShocks; self.currencyShocks = currencyShocks
        self.assetClassShocks = assetClassShocks; self.parallelRateShiftBps = parallelRateShiftBps
        self.volatilityMultiplier = volatilityMultiplier; self.horizonMonths = horizonMonths; self.recovery = recovery
    }
}

public struct MonteCarloConfiguration: Codable, Equatable, Sendable {
    public let distribution: MonteCarloDistribution
    public let pathCount: Int
    public let horizonMonths: Int
    public let degreesOfFreedom: Double?
    public let bootstrapBlockMonths: Int
    public let expectedReturns: [String: Double]
    public let volatilities: [String: Double]
    public let correlations: [String: Double]
    public let inflation: Double
    public let monthlyContribution: Double

    public init(
        distribution: MonteCarloDistribution = .blockBootstrap,
        pathCount: Int = 10000,
        horizonMonths: Int,
        degreesOfFreedom: Double? = nil,
        bootstrapBlockMonths: Int = 6,
        expectedReturns: [String: Double] = [:],
        volatilities: [String: Double] = [:],
        correlations: [String: Double] = [:],
        inflation: Double = 0.02,
        monthlyContribution: Double = 0
    ) {
        self.distribution = distribution; self.pathCount = pathCount; self.horizonMonths = horizonMonths
        self.degreesOfFreedom = degreesOfFreedom; self.bootstrapBlockMonths = bootstrapBlockMonths
        self.expectedReturns = expectedReturns; self.volatilities = volatilities; self.correlations = correlations
        self.inflation = inflation; self.monthlyContribution = monthlyContribution
    }
}

public enum ScenarioConfiguration: Codable, Equatable, Sendable {
    case historical(HistoricalScenarioConfiguration)
    case custom(CustomScenarioConfiguration)
    case monteCarlo(MonteCarloConfiguration)

    private enum CodingKeys: String, CodingKey { case type, historical, custom, monteCarlo = "monte_carlo" }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(ScenarioKind.self, forKey: .type) {
        case .historical: self = try .historical(container.decode(
                HistoricalScenarioConfiguration.self,
                forKey: .historical
            ))
        case .custom: self = try .custom(container.decode(CustomScenarioConfiguration.self, forKey: .custom))
        case .monteCarlo: self = try .monteCarlo(container.decode(MonteCarloConfiguration.self, forKey: .monteCarlo))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .historical(value): try container.encode(ScenarioKind.historical, forKey: .type); try container.encode(
                value,
                forKey: .historical
            )
        case let .custom(value): try container.encode(ScenarioKind.custom, forKey: .type); try container.encode(
                value,
                forKey: .custom
            )
        case let .monteCarlo(value): try container.encode(ScenarioKind.monteCarlo, forKey: .type); try container.encode(
                value,
                forKey: .monteCarlo
            )
        }
    }

    public func validate() throws {
        switch self {
        case .historical: break
        case let .custom(value): guard (1 ... 120).contains(value.horizonMonths)
            else { throw ScenarioValidationError.invalidHorizon }
        case let .monteCarlo(value):
            guard (1 ... 600).contains(value.horizonMonths) else { throw ScenarioValidationError.invalidHorizon }
            guard (1 ... 50000).contains(value.pathCount) else { throw ScenarioValidationError.invalidPathCount }
            if value.distribution == .studentT,
               (value.degreesOfFreedom ?? 0) <= 2
            {
                throw ScenarioValidationError.invalidDegreesOfFreedom
            }
        }
    }
}

public struct ScenarioDefinition: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let portfolioListId: String
    public let financialGoalId: String?
    public let configuration: ScenarioConfiguration
    public let isSaved: Bool
    public let createdAt: String
    public let updatedAt: String

    public init(
        id: String,
        name: String,
        portfolioListId: String,
        financialGoalId: String? = nil,
        configuration: ScenarioConfiguration,
        isSaved: Bool = true,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id; self.name = name; self.portfolioListId = portfolioListId
        self.financialGoalId = financialGoalId; self.configuration = configuration
        self.isSaved = isSaved; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

public enum ScenarioRunState: String, Codable, CaseIterable,
    Sendable { case queued, running, completed, failed, cancelled }

public struct ScenarioRun: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let scenarioId: String
    public let snapshotId: String
    public let state: ScenarioRunState
    public let progress: Double
    public let seed: UInt64
    public let engineVersion: String
    public let catalogVersion: String
    public let errorMessage: String?
    public let createdAt: String
    public let startedAt: String?
    public let completedAt: String?

    public init(
        id: String,
        scenarioId: String,
        snapshotId: String,
        state: ScenarioRunState,
        progress: Double,
        seed: UInt64,
        engineVersion: String,
        catalogVersion: String,
        errorMessage: String? = nil,
        createdAt: String,
        startedAt: String? = nil,
        completedAt: String? = nil
    ) {
        self.id = id; self.scenarioId = scenarioId; self.snapshotId = snapshotId; self.state = state
        self.progress = progress; self.seed = seed; self.engineVersion = engineVersion
        self.catalogVersion = catalogVersion; self.errorMessage = errorMessage
        self.createdAt = createdAt; self.startedAt = startedAt; self.completedAt = completedAt
    }
}

public struct ScenarioValuePoint: Codable, Equatable, Sendable {
    public let elapsedMonths: Int
    public let value: Double
    public init(elapsedMonths: Int, value: Double) {
        self.elapsedMonths = elapsedMonths; self.value = value
    }
}

public struct ScenarioPercentilePoint: Codable, Equatable, Sendable {
    public let elapsedMonths: Int
    public let p10: Double
    public let p25: Double
    public let p50: Double
    public let p75: Double
    public let p90: Double
    public init(elapsedMonths: Int, p10: Double, p25: Double, p50: Double, p75: Double, p90: Double) {
        self.elapsedMonths = elapsedMonths; self.p10 = p10; self.p25 = p25; self.p50 = p50; self.p75 = p75; self
            .p90 = p90
    }
}

public struct ScenarioContribution: Codable, Equatable, Sendable {
    public let key: String
    public let amount: Double
    public let percentagePoints: Double
    public init(key: String, amount: Double, percentagePoints: Double) {
        self.key = key; self.amount = amount; self.percentagePoints = percentagePoints
    }
}

public struct ScenarioResult: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let runId: String
    public let timeline: [ScenarioValuePoint]
    public let percentileBands: [ScenarioPercentilePoint]
    public let maximumDrawdown: Double
    public let goalProbability: Double?
    public let expectedShortfall: Double?
    public let holdingContributions: [ScenarioContribution]
    public let classContributions: [ScenarioContribution]
    public let assumptions: [String: Double]
    public let warnings: [ScenarioDataWarning]
    /// Portfolio value at the end of the stress window (base currency).
    public let endingValue: Double?
    /// Fractional change vs initial snapshot value (e.g. -0.22 for −22%).
    public let portfolioChangePercent: Double?
    /// Extra months needed to hit the linked goal after the shock (null if no goal / unreachable).
    public let goalDelayMonths: Double?
    /// Monthly contribution required to hit the original target date from the stressed value.
    public let requiredMonthlyContribution: Double?
    /// `requiredMonthlyContribution − current monthly contribution`.
    public let contributionDelta: Double?
    /// Months until value recovers the pre-shock level (null if never within horizon).
    public let recoveryMonths: Double?
    /// Spending reduction needed to free cash for the contribution delta (null if unknown).
    public let expenseImpactMonthly: Double?

    public init(
        id: String,
        runId: String,
        timeline: [ScenarioValuePoint],
        percentileBands: [ScenarioPercentilePoint] = [],
        maximumDrawdown: Double,
        goalProbability: Double? = nil,
        expectedShortfall: Double? = nil,
        holdingContributions: [ScenarioContribution] = [],
        classContributions: [ScenarioContribution] = [],
        assumptions: [String: Double] = [:],
        warnings: [ScenarioDataWarning] = [],
        endingValue: Double? = nil,
        portfolioChangePercent: Double? = nil,
        goalDelayMonths: Double? = nil,
        requiredMonthlyContribution: Double? = nil,
        contributionDelta: Double? = nil,
        recoveryMonths: Double? = nil,
        expenseImpactMonthly: Double? = nil
    ) {
        self.id = id; self.runId = runId; self.timeline = timeline; self.percentileBands = percentileBands
        self.maximumDrawdown = maximumDrawdown; self.goalProbability = goalProbability
        self.expectedShortfall = expectedShortfall; self.holdingContributions = holdingContributions
        self.classContributions = classContributions; self.assumptions = assumptions; self.warnings = warnings
        self.endingValue = endingValue; self.portfolioChangePercent = portfolioChangePercent
        self.goalDelayMonths = goalDelayMonths; self.requiredMonthlyContribution = requiredMonthlyContribution
        self.contributionDelta = contributionDelta; self.recoveryMonths = recoveryMonths
        self.expenseImpactMonthly = expenseImpactMonthly
    }
}

public struct ScenarioComparison: Codable, Equatable, Sendable {
    public let results: [ScenarioResult]
    public init(results: [ScenarioResult]) throws {
        guard (1 ... 4).contains(results.count) else { throw ScenarioValidationError.tooManyComparisons }
        self.results = results
    }
}

public struct HistoricalScenarioCatalogItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let startDate: String
    public let endDate: String
    public init(id: String, name: String, startDate: String, endDate: String) {
        self.id = id; self.name = name; self.startDate = startDate; self.endDate = endDate
    }
}

public struct ScenarioCatalog: Codable, Equatable, Sendable {
    public let version: String
    public let historicalScenarios: [HistoricalScenarioCatalogItem]
    public init(version: String, historicalScenarios: [HistoricalScenarioCatalogItem]) {
        self.version = version; self.historicalScenarios = historicalScenarios
    }
}
