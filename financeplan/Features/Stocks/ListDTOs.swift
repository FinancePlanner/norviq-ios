import Foundation

import Foundation

struct PortfolioListDTORequest: Sendable, Equatable {
    let name: String
}

nonisolated extension PortfolioListDTORequest: Codable {}

struct PortfolioListDTOResponse: Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let isDefault: Bool
    let createdAt: String?
    let updatedAt: String?
}

nonisolated extension PortfolioListDTOResponse: Codable {}

struct WatchlistListDTORequest: Sendable, Equatable {
    let name: String
}

nonisolated extension WatchlistListDTORequest: Codable {}

struct WatchlistListDTOResponse: Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let isDefault: Bool
    let createdAt: String?
    let updatedAt: String?
}

nonisolated extension WatchlistListDTOResponse: Codable {}


