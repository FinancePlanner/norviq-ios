import Combine
import Foundation
import SwiftUI

struct StockInsightsResponse: Sendable, Equatable {
    let generatedAt: String
    let symbol: String
    let profile: StockInsightProfileDTO
    let peers: [StockInsightPeerDTO]
    let projectionScenarios: [StockInsightProjectionScenarioDTO]
  }
  nonisolated extension StockInsightsResponse: Codable {}

  struct StockInsightProfileDTO: Sendable, Equatable {
    let symbol: String
    let companyName: String
    let currentPrice: Double
    let marketCap: Double
    let sharesOutstanding: Double
    let metrics: [String: Double]
    let dcfBasePrice: Double?
    let dcfBearPrice: Double?
    let dcfBullPrice: Double?
  }
  nonisolated extension StockInsightProfileDTO: Codable {}

struct StockInsightPeerDTO: Codable, Equatable, Identifiable {
  var id: String { symbol }

  let symbol: String
  let companyName: String
  let currentPrice: Double
  let marketCap: Double
  let sharesOutstanding: Double
}

struct StockInsightProjectionScenarioDTO: Equatable, Sendable {
  let kind: String
  let years: [StockInsightProjectionYearDTO]
}

nonisolated extension StockInsightProjectionScenarioDTO: Codable {}

struct StockInsightProjectionYearDTO: Codable, Equatable {
  let year: Int
  let revenue: Double
  let revenueGrowth: Double
  let netIncome: Double
  let netIncomeGrowth: Double
  let netMargin: Double
  let eps: Double
  let peLowEstimate: Double
  let peHighEstimate: Double
  let sharePriceLow: Double
  let sharePriceHigh: Double
  let cagrLow: Double?
  let cagrHigh: Double?
}
