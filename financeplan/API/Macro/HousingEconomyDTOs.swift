import Foundation
import StockPlanShared

// MARK: - Local hub DTOs
// Prefer StockPlanShared.Macro.HousingEconomyDTOs once norviq-shared ships them
// (present on local main; remote pin 4.0.0 does not include this file yet).
// Codable via nonisolated extension — app target is MainActor-by-default.

/// Country housing snapshot. Null gauges mean lite coverage omitted that field.
struct HousingHubResponse: Sendable, Equatable {
  let country: String
  let currency: String
  let asOf: String
  let updatedAt: String
  let source: String
  /// Depth tags, e.g. `["hpi", "mortgage", "rent", "starts"]` or `["rent"]`.
  let coverage: [String]
  let hpiYoY: MacroIndicatorDTO?
  let mortgageRate: MacroIndicatorDTO?
  let rentYoY: MacroIndicatorDTO?
  let housingStarts: MacroIndicatorDTO?
  let monthsSupply: MacroIndicatorDTO?
  let notes: String?
}

nonisolated extension HousingHubResponse: Codable {}

/// Labor + GDP + recession-risk snapshot (3-country lite).
struct EconomyHubResponse: Sendable, Equatable {
  let country: String
  let currency: String
  let asOf: String
  let updatedAt: String
  let source: String
  let coverage: [String]
  let unemployment: MacroIndicatorDTO?
  let gdpGrowth: MacroIndicatorDTO?
  let payrolls: MacroIndicatorDTO?
  let initialClaims: MacroIndicatorDTO?
  let policyRate: MacroIndicatorDTO?
  /// Sahm-rule reading in percentage points (threshold typically 0.50).
  let sahmRule: MacroIndicatorDTO?
  /// True when official recession dating (e.g. NBER) is active; nil when unavailable.
  let officialRecession: Bool?
  /// `elevated` | `watch` | `low`
  let riskLabel: String?
  let yieldCurveSpread: Double?
  let notes: String?
}

nonisolated extension EconomyHubResponse: Codable {}

/// Country-aware central-bank / rates context.
struct PolicyWatchResponse: Sendable, Equatable {
  let country: String
  let asOf: String
  let updatedAt: String
  let source: String
  let institution: String
  let inflationGauge: MacroIndicatorDTO
  let inflationTarget: Double
  let distanceToTarget: Double
  let policyRate: MacroIndicatorDTO?
  let treasury2Y: MacroIndicatorDTO?
  let treasury10Y: MacroIndicatorDTO?
  let spread10Y2Y: Double?
  let real10Y: MacroIndicatorDTO?
  let breakeven10Y: MacroIndicatorDTO?
  let nextMeeting: FOMCMeetingDTO?
  let stance: String?
  let notes: String?
}

nonisolated extension PolicyWatchResponse: Codable {}
