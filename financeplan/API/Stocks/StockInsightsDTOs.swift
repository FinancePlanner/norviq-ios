import Combine
import Foundation
import SwiftUI

struct StockInsightsResponse: Codable, Equatable {
  let generatedAt: String
  let symbol: String
  let profile: StockInsightProfileDTO
  let peers: [StockInsightPeerDTO]
  let projectionScenarios: [StockInsightProjectionScenarioDTO]
}

struct StockInsightProfileDTO: Codable, Equatable {
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

struct StockInsightPeerDTO: Codable, Equatable, Identifiable {
  var id: String { symbol }

  let symbol: String
  let companyName: String
  let currentPrice: Double
  let marketCap: Double
  let sharesOutstanding: Double
}

struct StockInsightProjectionScenarioDTO: Codable, Equatable {
  let kind: String
  let years: [StockInsightProjectionYearDTO]
}

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
