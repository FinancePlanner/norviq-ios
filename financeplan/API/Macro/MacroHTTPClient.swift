import AnyAPI
import Foundation
import StockPlanShared

/// Lightweight HTTP client for macro endpoints.
/// Follows the pattern of MarketDataHTTPClient.
final class MacroHTTPClient: BaseHTTPClient, @unchecked Sendable {
  func getCurrentInflation(country: String? = nil) async throws -> InflationSnapshotResponse {
    let endpoint = GetInflationCurrentEndpoint(country: country)
    return try await perform(endpoint)
  }

  func getTopMovers(country: String? = nil, focus: String? = "utilities,food,shelter") async throws -> [TopMoverDTO] {
    let endpoint = GetTopMoversEndpoint(country: country, focus: focus)
    return try await perform(endpoint)
  }

  func getSeries(country: String? = nil, series: String, from: String? = nil, to: String? = nil) async throws -> MacroSeriesResponse {
    let endpoint = GetInflationSeriesEndpoint(country: country, series: series, from: from, to: to)
    return try await perform(endpoint)
  }

  func getSupportedCountries() async throws -> [SupportedCountry] {
    let endpoint = GetSupportedCountriesEndpoint()
    return try await perform(endpoint)
  }
}
