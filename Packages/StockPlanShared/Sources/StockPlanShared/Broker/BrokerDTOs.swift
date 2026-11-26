import Foundation

public struct BrokerConnectionResponse: Codable, Sendable, Equatable {
    public let id: String
    public let provider: String
    public let status: String
    public let displayName: String?
    public let statusDetail: String?
    public let connectedAt: Date?
    public let lastSyncedAt: Date?
    public let portfolioListId: String?

    public init(
        id: String,
        provider: String,
        status: String,
        displayName: String? = nil,
        statusDetail: String? = nil,
        connectedAt: Date? = nil,
        lastSyncedAt: Date? = nil,
        portfolioListId: String? = nil
    ) {
        self.id = id
        self.provider = provider
        self.status = status
        self.displayName = displayName
        self.statusDetail = statusDetail
        self.connectedAt = connectedAt
        self.lastSyncedAt = lastSyncedAt
        self.portfolioListId = portfolioListId
    }
}

public struct BrokerHoldingResponse: Codable, Sendable, Equatable {
    public let symbol: String
    public let quantity: Double
    public let currency: String

    public init(symbol: String, quantity: Double, currency: String) {
        self.symbol = symbol
        self.quantity = quantity
        self.currency = currency
    }
}

public struct BrokerSyncStatusResponse: Codable, Sendable, Equatable {
    public let status: String
    public let lastSyncedAt: Date?
    public let isStale: Bool
    public let statusDetail: String?

    public init(
        status: String,
        lastSyncedAt: Date? = nil,
        isStale: Bool,
        statusDetail: String? = nil
    ) {
        self.status = status
        self.lastSyncedAt = lastSyncedAt
        self.isStale = isStale
        self.statusDetail = statusDetail
    }
}
