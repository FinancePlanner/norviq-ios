import Foundation
import StockPlanShared

protocol MacroServicing: Sendable {
  func getCurrentInflation(country: String?) async throws -> InflationSnapshotResponse
  func getTopMovers(country: String?, focus: String?) async throws -> [TopMoverDTO]
  func getSeries(country: String?, series: String, limit: Int?) async throws -> MacroSeriesResponse
  func getSupportedCountries() async throws -> [SupportedCountry]
  func getFedWatch() async throws -> FedWatchResponse
  func getItems(country: String?) async throws -> MacroItemsResponse
  func getItemSeries(itemId: String, country: String?, limit: Int?) async throws -> MacroItemSeriesResponse
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

  func getSeries(country: String?, series: String, limit: Int? = nil) async throws -> MacroSeriesResponse {
    try await httpClient.getSeries(country: country, series: series, limit: limit)
  }

  func getSupportedCountries() async throws -> [SupportedCountry] {
    try await httpClient.getSupportedCountries()
  }

  func getFedWatch() async throws -> FedWatchResponse {
    try await httpClient.getFedWatch()
  }

  func getItems(country: String?) async throws -> MacroItemsResponse {
    try await httpClient.getItems(country: country)
  }

  func getItemSeries(itemId: String, country: String?, limit: Int? = nil) async throws -> MacroItemSeriesResponse {
    try await httpClient.getItemSeries(itemId: itemId, country: country, limit: limit)
  }
}
