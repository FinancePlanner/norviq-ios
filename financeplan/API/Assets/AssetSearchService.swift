import Foundation

struct AssetSearchResult: Identifiable, Equatable {
  let symbol: String
  let name: String
  let exchange: String?

  var id: String { symbol }
}

protocol AssetSearchServicing {
  func searchAssets(query: String) async throws -> [AssetSearchResult]
}

final class AssetSearchService: AssetSearchServicing {
  func searchAssets(query _: String) async throws -> [AssetSearchResult] {
    // to fill from endpoint later
    []
  }
}
