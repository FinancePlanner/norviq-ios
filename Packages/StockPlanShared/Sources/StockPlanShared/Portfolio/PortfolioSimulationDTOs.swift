import Foundation

/// How a simulation was seeded.
public enum PortfolioSimulationMode: String, Codable, Sendable, Equatable, CaseIterable {
    /// No starting holdings. The user is pricing a portfolio they do not own yet.
    case fromScratch
    /// Seeded from a real portfolio's current holdings, so the result reads as a diff.
    case cloneCurrentPortfolio
}

public struct PortfolioSimulationLeg: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        symbol
    }

    public let symbol: String
    public let displayName: String?
    public let targetBasisPoints: Int
    public let sortOrder: Int

    public init(symbol: String, displayName: String? = nil, targetBasisPoints: Int, sortOrder: Int = 0) {
        self.symbol = symbol
        self.displayName = displayName
        self.targetBasisPoints = targetBasisPoints
        self.sortOrder = sortOrder
    }
}

public struct PortfolioSimulationLegInput: Codable, Sendable, Equatable {
    public let symbol: String
    public let displayName: String?
    public let targetBasisPoints: Int

    public init(symbol: String, displayName: String? = nil, targetBasisPoints: Int) {
        self.symbol = symbol
        self.displayName = displayName
        self.targetBasisPoints = targetBasisPoints
    }
}

public struct PortfolioSimulation: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let mode: PortfolioSimulationMode
    public let sourcePortfolioId: String?
    public let baseCurrency: String
    public let targetCapital: Double
    public let fractionalSharesEnabled: Bool
    public let quantityIncrement: Double
    public let minimumTradeAmount: Double
    public let flatFee: Double
    public let variableFeeBasisPoints: Int
    public let revision: Int
    public let legs: [PortfolioSimulationLeg]
    public let shareEnabled: Bool
    public let shareShowCapital: Bool
    public let shareSlug: String?
    public let createdAt: String
    public let updatedAt: String?

    /// Whatever the legs do not claim is held as cash. Never negative: leg totals
    /// above 10000 are rejected before a simulation is ever persisted.
    public var cashBasisPoints: Int {
        max(0, 10000 - legs.reduce(0) { $0 + $1.targetBasisPoints })
    }

    public init(
        id: String,
        name: String,
        mode: PortfolioSimulationMode,
        sourcePortfolioId: String? = nil,
        baseCurrency: String,
        targetCapital: Double,
        fractionalSharesEnabled: Bool = false,
        quantityIncrement: Double = 0.001,
        minimumTradeAmount: Double = 1,
        flatFee: Double = 0,
        variableFeeBasisPoints: Int = 0,
        revision: Int,
        legs: [PortfolioSimulationLeg],
        shareEnabled: Bool = false,
        shareShowCapital: Bool = true,
        shareSlug: String? = nil,
        createdAt: String,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.sourcePortfolioId = sourcePortfolioId
        self.baseCurrency = baseCurrency
        self.targetCapital = targetCapital
        self.fractionalSharesEnabled = fractionalSharesEnabled
        self.quantityIncrement = quantityIncrement
        self.minimumTradeAmount = minimumTradeAmount
        self.flatFee = flatFee
        self.variableFeeBasisPoints = variableFeeBasisPoints
        self.revision = revision
        self.legs = legs
        self.shareEnabled = shareEnabled
        self.shareShowCapital = shareShowCapital
        self.shareSlug = shareSlug
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct PortfolioSimulationUpsertRequest: Codable, Sendable, Equatable {
    public let name: String
    public let mode: PortfolioSimulationMode
    public let sourcePortfolioId: String?
    public let baseCurrency: String
    public let targetCapital: Double
    public let fractionalSharesEnabled: Bool
    public let quantityIncrement: Double?
    public let minimumTradeAmount: Double?
    public let flatFee: Double?
    public let variableFeeBasisPoints: Int?
    public let legs: [PortfolioSimulationLegInput]
    /// Optimistic concurrency, mirroring `AllocationModelUpsertRequest`.
    public let expectedRevision: Int?

    public init(
        name: String,
        mode: PortfolioSimulationMode,
        sourcePortfolioId: String? = nil,
        baseCurrency: String,
        targetCapital: Double,
        fractionalSharesEnabled: Bool = false,
        quantityIncrement: Double? = nil,
        minimumTradeAmount: Double? = nil,
        flatFee: Double? = nil,
        variableFeeBasisPoints: Int? = nil,
        legs: [PortfolioSimulationLegInput],
        expectedRevision: Int? = nil
    ) {
        self.name = name
        self.mode = mode
        self.sourcePortfolioId = sourcePortfolioId
        self.baseCurrency = baseCurrency
        self.targetCapital = targetCapital
        self.fractionalSharesEnabled = fractionalSharesEnabled
        self.quantityIncrement = quantityIncrement
        self.minimumTradeAmount = minimumTradeAmount
        self.flatFee = flatFee
        self.variableFeeBasisPoints = variableFeeBasisPoints
        self.legs = legs
        self.expectedRevision = expectedRevision
    }
}

/// Computing a saved simulation needs nothing but an optional capital override,
/// which is what lets a client scrub the capital slider without writing a row.
public struct PortfolioSimulationComputeRequest: Codable, Sendable, Equatable {
    public let targetCapitalOverride: Double?

    public init(targetCapitalOverride: Double? = nil) {
        self.targetCapitalOverride = targetCapitalOverride
    }
}

public struct PortfolioSimulationListResponse: Codable, Sendable, Equatable {
    public let items: [PortfolioSimulation]
    public let nextCursor: String?

    public init(items: [PortfolioSimulation], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

/// One position's move between the current portfolio and the simulated target.
public struct PortfolioSimulationDiffRow: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        symbol
    }

    public let symbol: String
    public let currentBasisPoints: Int
    public let targetBasisPoints: Int
    public let currentValue: Double
    public let targetValue: Double

    public init(
        symbol: String,
        currentBasisPoints: Int,
        targetBasisPoints: Int,
        currentValue: Double,
        targetValue: Double
    ) {
        self.symbol = symbol
        self.currentBasisPoints = currentBasisPoints
        self.targetBasisPoints = targetBasisPoints
        self.currentValue = currentValue
        self.targetValue = targetValue
    }
}

/// Wraps `RebalancingSimulation` rather than redefining it: iOS and web already
/// render that type, so reusing it is most of the client work avoided.
public struct PortfolioSimulationResult: Codable, Sendable, Equatable {
    public let simulationId: String
    public let revision: Int
    public let mode: PortfolioSimulationMode
    public let generatedAt: String
    public let simulation: RebalancingSimulation
    /// Capital the user must supply to reach the target allocation, fees included.
    public let totalCashNeeded: Double
    /// Capital left unspent, which whole-share rounding makes non-zero in practice.
    public let leftoverCash: Double
    public let cashBasisPoints: Int
    public let diff: [PortfolioSimulationDiffRow]
    public let warnings: [RebalancingValuationWarning]

    public init(
        simulationId: String,
        revision: Int,
        mode: PortfolioSimulationMode,
        generatedAt: String,
        simulation: RebalancingSimulation,
        totalCashNeeded: Double,
        leftoverCash: Double,
        cashBasisPoints: Int,
        diff: [PortfolioSimulationDiffRow] = [],
        warnings: [RebalancingValuationWarning] = []
    ) {
        self.simulationId = simulationId
        self.revision = revision
        self.mode = mode
        self.generatedAt = generatedAt
        self.simulation = simulation
        self.totalCashNeeded = totalCashNeeded
        self.leftoverCash = leftoverCash
        self.cashBasisPoints = cashBasisPoints
        self.diff = diff
        self.warnings = warnings
    }
}
