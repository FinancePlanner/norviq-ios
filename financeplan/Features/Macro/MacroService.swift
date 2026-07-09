import Foundation
import StockPlanShared

protocol MacroServicing: Sendable {
  func getCurrentInflation(country: String?) async throws -> InflationSnapshotResponse
  func getTopMovers(country: String?, focus: String?) async throws -> [TopMoverDTO]
  func getSeries(country: String?, series: String) async throws -> MacroSeriesResponse
  func getSupportedCountries() async throws -> [SupportedCountry]
}

final class MacroHTTPService: MacroServicing {
  private let httpClient: MacroHTTPClient

  init(httpClient: MacroHTTPClient) {
    self.httpClient = httpClient
  }

  func getCurrentInflation(country: String?) async throws -> InflationSnapshotResponse {
    try await httpClient.getCurrentInflation(country: country)
  }

  func getTopMovers(country: String?, focus: String?) async throws -> [TopMoverDTO] {
    try await httpClient.getTopMovers(country: country, focus: focus)
  }

  func getSeries(country: String?, series: String) async throws -> MacroSeriesResponse {
    try await httpClient.getSeries(country: country, series: series)
  }

  func getSupportedCountries() async throws -> [SupportedCountry] {
    try await httpClient.getSupportedCountries()
  }
}
