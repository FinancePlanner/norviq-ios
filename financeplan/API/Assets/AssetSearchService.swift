import Foundation
import StockPlanShared

struct AssetSearchResult: Identifiable, Hashable {
  let symbol: String
  let name: String
  let exchange: String?
  var threeMonth: Double?
  var sixMonth: Double?
  var yearToDate: Double?

  var id: String { symbol }

  var hasPeriodReturns: Bool {
    threeMonth != nil || sixMonth != nil || yearToDate != nil
  }
}

protocol AssetSearchServicing: Sendable {
  func searchAssets(query: String, includeReturns: Bool) async throws -> [AssetSearchResult]
}

final class AssetSearchService: AssetSearchServicing, @unchecked Sendable {
  private let client: MarketDataHTTPClient

  init(client: MarketDataHTTPClient) {
    self.client = client
  }

  func searchAssets(query: String, includeReturns: Bool = true) async throws -> [AssetSearchResult] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }

    let response = try await client.searchAssets(query: trimmed, limit: 20)
    var results = response.map { item in
      let normalizedExchange = item.exchange.trimmingCharacters(in: .whitespacesAndNewlines)
      return AssetSearchResult(
        symbol: item.symbol,
        name: item.name,
        exchange: normalizedExchange.isEmpty ? nil : normalizedExchange
      )
    }
    let symbols = results.map(\.symbol)
    guard includeReturns, !symbols.isEmpty else { return results }
    do {
      let batch = try await client.fetchPeriodReturnsBatch(symbols: symbols)
      let bySymbol = Dictionary(
        uniqueKeysWithValues: batch.returns.map { ($0.symbol.uppercased(), $0) }
      )
      for index in results.indices {
        guard let item = bySymbol[results[index].symbol.uppercased()] else { continue }
        results[index].threeMonth = item.threeMonth
        results[index].sixMonth = item.sixMonth
        results[index].yearToDate = item.yearToDate
      }
    } catch {
      // Search rows still render without percents.
    }
    return results
  }
}
