import Foundation

// These mirror StockPlanShared's PortfolioSimulation DTOs but are declared
// locally, the way ScenarioPlanningService declares its own. They were written
// while the shared package was pinned to a release that predated the simulation
// types, so the feature could ship without forcing a coordinated bump.
//
// The pin has since moved to 5.7.0, which does carry them, so these now shadow
// the shared declarations rather than standing in for them. That compiles - a
// module's own types win over imported ones - but it is not free: the two have
// drifted, and shared's PortfolioSimulationResult is built on
// RebalancingSimulation and RebalancingValuationWarning where this one uses its
// own SimulationDetail and SimulationWarning. Deleting this file therefore means
// migrating the simulator feature to those shapes, which is its own change.

nonisolated enum PortfolioSimulationMode: String, Codable, Sendable, CaseIterable {
  case fromScratch
  case cloneCurrentPortfolio
}

nonisolated struct PortfolioSimulationLeg: Codable, Sendable, Identifiable, Hashable {
  var id: String {
    symbol
  }

  let symbol: String
  let displayName: String?
  let targetBasisPoints: Int
  let sortOrder: Int
}

nonisolated struct PortfolioSimulationLegInput: Codable, Sendable, Hashable {
  let symbol: String
  let displayName: String?
  let targetBasisPoints: Int

  init(symbol: String, displayName: String? = nil, targetBasisPoints: Int) {
    self.symbol = symbol
    self.displayName = displayName
    self.targetBasisPoints = targetBasisPoints
  }
}

nonisolated struct PortfolioSimulation: Codable, Sendable, Identifiable {
  let id: String
  let name: String
  let mode: PortfolioSimulationMode
  let sourcePortfolioId: String?
  let baseCurrency: String
  let targetCapital: Double
  let fractionalSharesEnabled: Bool
  let revision: Int
  let legs: [PortfolioSimulationLeg]
  let shareEnabled: Bool
  let shareSlug: String?
  let createdAt: String
  let updatedAt: String?

  /// Whatever the legs do not claim is held as cash.
  var cashBasisPoints: Int {
    max(0, 10000 - legs.reduce(0) { $0 + $1.targetBasisPoints })
  }
}

nonisolated struct PortfolioSimulationUpsertRequest: Codable, Sendable {
  let name: String
  let mode: PortfolioSimulationMode
  let sourcePortfolioId: String?
  let baseCurrency: String
  let targetCapital: Double
  let fractionalSharesEnabled: Bool
  let legs: [PortfolioSimulationLegInput]
  let expectedRevision: Int?

  init(
    name: String,
    mode: PortfolioSimulationMode,
    sourcePortfolioId: String? = nil,
    baseCurrency: String,
    targetCapital: Double,
    fractionalSharesEnabled: Bool,
    legs: [PortfolioSimulationLegInput],
    expectedRevision: Int? = nil
  ) {
    self.name = name
    self.mode = mode
    self.sourcePortfolioId = sourcePortfolioId
    self.baseCurrency = baseCurrency
    self.targetCapital = targetCapital
    self.fractionalSharesEnabled = fractionalSharesEnabled
    self.legs = legs
    self.expectedRevision = expectedRevision
  }
}

nonisolated struct PortfolioSimulationComputeRequest: Codable, Sendable {
  let targetCapitalOverride: Double?

  init(targetCapitalOverride: Double? = nil) {
    self.targetCapitalOverride = targetCapitalOverride
  }
}

nonisolated struct PortfolioSimulationListResponse: Codable, Sendable {
  let items: [PortfolioSimulation]
  let nextCursor: String?
}

nonisolated struct SimulationTrade: Codable, Sendable, Identifiable {
  var id: String {
    "\(side):\(symbol)"
  }

  let symbol: String
  let side: String
  let quantity: Double
  let price: Double
  let notional: Double
  let estimatedFee: Double

  var isBuy: Bool {
    side == "buy"
  }
}

nonisolated struct SimulationAllocationRow: Codable, Sendable {
  let id: String
  let label: String
  let symbol: String?
  let targetBasisPoints: Int
  let currentBasisPoints: Int
}

nonisolated struct SimulationDetail: Codable, Sendable {
  let baseCurrency: String
  let totalValueBefore: Double
  let totalValueAfter: Double
  let estimatedFees: Double
  let trades: [SimulationTrade]
  let after: [SimulationAllocationRow]
}

nonisolated struct PortfolioSimulationDiffRow: Codable, Sendable, Identifiable {
  var id: String {
    symbol
  }

  let symbol: String
  let currentBasisPoints: Int
  let targetBasisPoints: Int
  let currentValue: Double
  let targetValue: Double

  var deltaBasisPoints: Int {
    targetBasisPoints - currentBasisPoints
  }
}

nonisolated struct SimulationWarning: Codable, Sendable, Identifiable {
  var id: String {
    "\(code):\(symbol ?? "portfolio")"
  }

  let code: String
  let symbol: String?
  let message: String
}

nonisolated struct PortfolioSimulationResult: Codable, Sendable {
  let simulationId: String
  let revision: Int
  let mode: PortfolioSimulationMode
  let generatedAt: String
  let simulation: SimulationDetail
  /// Capital required to reach the target allocation, fees included.
  let totalCashNeeded: Double
  /// Capital left unspent, which whole-share rounding makes non-zero in practice.
  let leftoverCash: Double
  let cashBasisPoints: Int
  let diff: [PortfolioSimulationDiffRow]
  let warnings: [SimulationWarning]
}
