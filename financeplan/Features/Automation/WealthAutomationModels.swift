import Foundation

/// These wire models mirror StockPlanShared 3.23.0. They remain local until the
/// coordinated shared-package tag is published, so this branch can build in isolation.
nonisolated struct AutomationListOption: Codable, Identifiable, Sendable {
  let id: UUID
  let name: String
  let isDefault: Bool
}

nonisolated struct ForecastDefinitionWire: Codable, Identifiable, Sendable {
  let id: String
  let portfolioListId: String
  let name: String
  let baseCurrency: String
  let horizonMonths: Int
  let includeCash: Bool
  let includeCrypto: Bool
  let annualIncomeGrowth: Double
  let annualSpendingGrowth: Double
  let inflationAssumption: Double
  let monthlyIncomeOverride: Double?
  let monthlySpendingOverride: Double?
  let targetAmount: Double?
  let pathCount: Int
}

nonisolated struct ForecastUpsertWire: Codable, Sendable {
  let name: String
  let baseCurrency: String
  let horizonMonths: Int
  let includeCash: Bool
  let includeCrypto: Bool
  let annualIncomeGrowth: Double
  let annualSpendingGrowth: Double
  let inflationAssumption: Double
  let monthlyIncomeOverride: Double?
  let monthlySpendingOverride: Double?
  let targetAmount: Double?
  let pathCount: Int
}

nonisolated struct ForecastDefaultsWire: Codable, Sendable {
  let baseCurrency: String
  let monthlyIncome: Double
  let monthlySpending: Double
  let monthlyNetFlow: Double
  let cashFlowSource: String
  let includedFinancing: Double
  let warnings: [String]
}

nonisolated struct ForecastBandWire: Codable, Sendable {
  let percentile: Int
  let value: Double
}

nonisolated struct ForecastPointWire: Codable, Identifiable, Sendable {
  let id: String
  let month: Int
  let date: String
  let monthlyIncome: Double
  let monthlySpending: Double
  let bands: [ForecastBandWire]

  func value(at percentile: Int) -> Double? {
    bands.first(where: { $0.percentile == percentile })?.value
  }
}

nonisolated struct ForecastRunWire: Codable, Identifiable, Sendable {
  let id: String
  let forecastId: String
  let status: String
  let startingValue: Double
  let assumptions: ForecastDefaultsWire
  let timeline: [ForecastPointWire]
  let targetProbability: Double?
  let failureReason: String?
  let createdAt: String
  let completedAt: String?
}

nonisolated struct ScreenMetricWire: Codable, Identifiable, Sendable {
  let id: String
  let label: String
  let category: String
  let supportedPeriods: [String]
  let supportedComparisons: [String]
  let unit: String
  let favorableDirection: String?
}

nonisolated struct ScreenConditionWire: Codable, Identifiable, Sendable {
  let id: String
  let metric: String
  let comparison: String
  let period: String
  let value: Double?
}

nonisolated struct ScreenGroupWire: Codable, Identifiable, Sendable {
  let id: String
  let logicalOperator: String
  let conditions: [ScreenConditionWire]
}

nonisolated struct WatchlistScreenWire: Codable, Identifiable, Sendable {
  let id: String
  let name: String
  let watchlistListIds: [String]
  let logicalOperator: String
  let groups: [ScreenGroupWire]
  let alertsEnabled: Bool
  let lastEvaluatedAt: String?
}

nonisolated struct WatchlistScreenUpsertWire: Codable, Sendable {
  let name: String
  let watchlistListIds: [String]
  let logicalOperator: String
  let groups: [ScreenGroupWire]
  let alertsEnabled: Bool
}

nonisolated struct ScreenMatchWire: Codable, Identifiable, Sendable {
  let id: String
  let symbol: String
  let name: String?
  let isNew: Bool
}

nonisolated struct ScreenEvaluationWire: Codable, Identifiable, Sendable {
  let id: String
  let screenId: String
  let evaluatedAt: String
  let symbolCount: Int
  let matches: [ScreenMatchWire]
  let isAlertBaseline: Bool
}

nonisolated struct RebalanceTargetWire: Codable, Identifiable, Sendable {
  let id: String
  let kind: String
  let symbol: String?
  let targetWeight: Double
}

nonisolated struct RebalancingPolicyWire: Codable, Identifiable, Sendable {
  let id: String
  let portfolioListId: String
  let enabled: Bool
  let cadence: String
  let driftThreshold: Double?
  let targets: [RebalanceTargetWire]
  let lastConfirmedAt: String?
}

nonisolated struct RebalancingPolicyUpsertWire: Codable, Sendable {
  let enabled: Bool
  let cadence: String
  let driftThreshold: Double?
  let targets: [RebalanceTargetWire]
}

nonisolated struct RebalanceTradeWire: Codable, Identifiable, Sendable {
  let id: String
  let kind: String
  let symbol: String?
  let action: String
  let currentWeight: Double
  let targetWeight: Double
  let amount: Double
  let approximateShares: Double?
}

nonisolated struct RebalancePreviewWire: Codable, Sendable {
  let portfolioValue: Double
  let currency: String
  let maximumDrift: Double
  let triggerReasons: [String]
  let trades: [RebalanceTradeWire]
  let warnings: [String]
}

nonisolated struct NotificationItemWire: Codable, Identifiable, Sendable {
  let id: String
  let kind: String
  let title: String
  let body: String
  let deepLink: String?
  let payload: [String: String]
  let readAt: String?
  let createdAt: String
}

nonisolated struct NotificationPageWire: Codable, Sendable {
  let items: [NotificationItemWire]
  let nextCursor: String?
  let unreadCount: Int
}

nonisolated struct NotificationReadWire: Codable, Sendable {
  let read: Bool
}

nonisolated struct EmptyAutomationBody: Codable, Sendable {}
