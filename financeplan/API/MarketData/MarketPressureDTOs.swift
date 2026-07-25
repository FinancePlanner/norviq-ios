import Foundation

// Local DTOs mirroring GET /v1/market/pressure/{symbol} (backend
// MarketPressureDTOs). App-local to avoid a shared-package tag bump.

nonisolated struct MarketPressureResponse: Codable, Equatable, Sendable {
  let symbol: String
  let asOf: String
  /// 0–100; 50 balanced, above 50 leans buying.
  let temperature: Double
  let label: String
  let volume: MarketPressureVolume
  let insider: MarketPressureInsider?
  let history: [MarketPressureHistoryPoint]
}

nonisolated struct MarketPressureVolume: Codable, Equatable, Sendable {
  let today: Double
  let average30d: Double
  let relative: Double
  let changePct: Double
}

nonisolated struct MarketPressureInsider: Codable, Equatable, Sendable {
  let windowDays: Int
  let buyCount: Int
  let sellCount: Int
  let netShares: Double
  let lastActivityAt: String?
  let notable: [MarketPressureInsiderTrade]
}

nonisolated struct MarketPressureInsiderTrade: Codable, Equatable, Sendable, Identifiable {
  var id: String { "\(name)-\(date)-\(shares)" }
  let name: String
  let role: String?
  let side: String
  let shares: Double
  let date: String
}

nonisolated struct MarketPressureHistoryPoint: Codable, Equatable, Sendable, Identifiable {
  var id: String { date }
  let date: String
  let relativeVolume: Double
}
