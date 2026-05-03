import Foundation

struct PortfolioListDTORequest: Sendable, Equatable {
  let name: String
}

nonisolated extension PortfolioListDTORequest: Codable {}

struct PortfolioListDTOResponse: Codable, Sendable, Equatable, Identifiable {
  let id: String
  let name: String
  let isDefault: Bool
  let createdAt: String?
  let updatedAt: String?
}

struct WatchlistListDTORequest: Sendable, Equatable {
  let name: String
}

nonisolated extension WatchlistListDTORequest: Codable {}

struct WatchlistListDTOResponse: Codable, Sendable, Equatable, Identifiable {
  let id: String
  let name: String
  let isDefault: Bool
  let createdAt: String?
  let updatedAt: String?
}


