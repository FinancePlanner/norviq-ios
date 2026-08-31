import Foundation

// Local DTOs mirroring GET /v1/market/returns/{symbol} (backend
// PeriodReturnsDTOs). App-local to avoid a shared-package tag bump.
// Values are percent points: 12.5 means +12.5%.

nonisolated struct StockPeriodReturnsResponse: Codable, Equatable, Sendable {
  let symbol: String
  let threeMonth: Double?
  let sixMonth: Double?
  let yearToDate: Double?
  let asOf: String?
}

nonisolated struct StockPeriodReturnsBatchResponse: Codable, Equatable, Sendable {
  let returns: [StockPeriodReturnsResponse]
}

enum PeriodReturnFormatting: Sendable {
  nonisolated static func percentText(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%+.1f%%", value)
  }

  nonisolated static func accessibilityLabel(period: String, value: Double?) -> String {
    let spoken: String
    switch period {
    case "3M": spoken = "3 month"
    case "6M": spoken = "6 month"
    case "YTD": spoken = "year to date"
    default: spoken = period
    }
    return "\(spoken) \(percentText(value))"
  }
}
