import Foundation

struct PortfolioListDTORequest: Codable, Sendable, Equatable {
  let name: String
}

struct PortfolioListDTOResponse: Codable, Sendable, Equatable, Identifiable {
  let id: String
  let name: String
  let isDefault: Bool
  let createdAt: String?
  let updatedAt: String?
}

struct WatchlistListDTORequest: Codable, Sendable, Equatable {
  let name: String
}

struct WatchlistListDTOResponse: Codable, Sendable, Equatable, Identifiable {
  let id: String
  let name: String
  let isDefault: Bool
  let createdAt: String?
  let updatedAt: String?
}
