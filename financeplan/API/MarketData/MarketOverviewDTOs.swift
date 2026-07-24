import Foundation

// Local DTOs mirroring GET /v1/market/overview (backend MarketOverviewDTOs).
// Kept app-local (StockInsightsDTOs pattern) to avoid a shared-package tag
// bump; synthesized Codable must be nonisolated under the app target's
// default MainActor isolation.

nonisolated struct MarketOverviewResponse: Codable, Equatable, Sendable {
  let indices: [MarketIndexQuote]
  let gainers: [MarketMover]
  let losers: [MarketMover]
  let heatmap: [MarketHeatmapTile]
  let asOf: String
}

nonisolated struct MarketIndexQuote: Codable, Equatable, Sendable, Identifiable {
  var id: String { symbol }
  let symbol: String
  let label: String
  let price: Double
  let changePct: Double
  /// True when the quote is an ETF proxy for the index (free data tier).
  let isProxy: Bool
}

nonisolated struct MarketMover: Codable, Equatable, Sendable, Identifiable {
  var id: String { symbol }
  let symbol: String
  let name: String
  let price: Double
  let changePct: Double
}

nonisolated struct MarketHeatmapTile: Codable, Equatable, Sendable, Identifiable {
  var id: String { symbol }
  let symbol: String
  let name: String
  let sector: String
  let marketCap: Double
  let changePct: Double
}
