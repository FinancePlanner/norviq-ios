import Foundation
import StockPlanShared

struct AssetSearchResult: Identifiable, Hashable {
  let symbol: String
  let name: String
  let exchange: String?

  var id: String { symbol }
}

protocol AssetSearchServicing: Sendable {
  func searchAssets(query: String) async throws -> [AssetSearchResult]
}

final class AssetSearchService: AssetSearchServicing, @unchecked Sendable {
  private let client: MarketDataHTTPClient

  init(client: MarketDataHTTPClient) {
    self.client = client
  }

  func searchAssets(query: String) async throws -> [AssetSearchResult] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }

    let response = try await client.searchAssets(query: trimmed, limit: 20)
    return response.map { item in
      let normalizedExchange = item.exchange.trimmingCharacters(in: .whitespacesAndNewlines)
      return AssetSearchResult(
        symbol: item.symbol,
        name: item.name,
        exchange: normalizedExchange.isEmpty ? nil : normalizedExchange
      )
    }
  }
}
