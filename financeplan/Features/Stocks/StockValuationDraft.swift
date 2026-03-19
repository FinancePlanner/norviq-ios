import Foundation

struct StockValuationDraft: Sendable, Equatable {
  let bearLow: Double
  let bearHigh: Double
  let baseLow: Double
  let baseHigh: Double
  let bullLow: Double
  let bullHigh: Double
  let rationale: String?
  let targetDate: String?
}
