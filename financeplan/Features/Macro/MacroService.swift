import Foundation
import StockPlanShared

public protocol MacroServicing: Sendable {
  func getCurrentInflation(country: String?) async throws -> InflationSnapshotResponse
  func getTopMovers(country: String?, focus: String?) async throws -> [TopMoverDTO]
  func getSeries(country: String?, series: String) async throws -> MacroSeriesResponse
  func getSupportedCountries() async throws -> [SupportedCountry]
}

public final class MacroHTTPService: MacroServicing {
  private let httpClient: MacroHTTPClient

  public init(httpClient: MacroHTTPClient) {
    self.httpClient = httpClient
  }

  public func getCurrentInflation(country: String?) async throws -> InflationSnapshotResponse {
    try await httpClient.getCurrentInflation(country: country)
  }

  public func getTopMovers(country: String?, focus: String?) async throws -> [TopMoverDTO] {
    try await httpClient.getTopMovers(country: country, focus: focus)
  }

  public func getSeries(country: String?, series: String) async throws -> MacroSeriesResponse {
    try await httpClient.getSeries(country: country, series: series)
  }

  public func getSupportedCountries() async throws -> [SupportedCountry] {
    try await httpClient.getSupportedCountries()
  }
}
