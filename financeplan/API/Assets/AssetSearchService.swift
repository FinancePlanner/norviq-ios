import AnyAPI
import Foundation
import StockPlanShared

struct AssetSearchResult: Identifiable, Equatable {
  let symbol: String
  let name: String
  let exchange: String?

  var id: String { symbol }
}

protocol AssetSearchServicing {
  func searchAssets(query: String) async throws -> [AssetSearchResult]
}

private struct SearchAssetsEndpoint: Endpoint {
  typealias Response = [SearchResultResponse]

  let query: String
  let limit: Int

  var method: HTTPMethod { .get }
  var path: String { "/v1/assets/search" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    [
      "q": query,
      "limit": limit
    ]
  }
}

final class AssetSearchService: AssetSearchServicing {
  private let client: MarketDataHTTPClient

  init(client: MarketDataHTTPClient) {
    self.client = client
  }

  func searchAssets(query: String) async throws -> [AssetSearchResult] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }

    let response = try await client.call(SearchAssetsEndpoint(query: trimmed, limit: 20))
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
