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

public struct BrokerSyncResponse: Codable, Sendable, Equatable {
    public let runId: String
    public let status: String
    public let inserted: Int
    public let updated: Int
    public let removed: Int

    public init(
        runId: String,
        status: String,
        inserted: Int = 0,
        updated: Int = 0,
        removed: Int = 0
    ) {
        self.runId = runId
        self.status = status
        self.inserted = inserted
        self.updated = updated
        self.removed = removed
    }
}

public struct BrokerConnectStartRequest: Codable, Sendable, Equatable {
    public let redirectURI: String
    public let portfolioListId: String?

    public init(redirectURI: String, portfolioListId: String? = nil) {
        self.redirectURI = redirectURI
        self.portfolioListId = portfolioListId
    }
}

public struct BrokerConnectStartResponse: Codable, Sendable, Equatable {
    public let flowId: String
    public let authorizationURL: String
    public let expiresIn: Int

    public init(flowId: String, authorizationURL: String, expiresIn: Int) {
        self.flowId = flowId
        self.authorizationURL = authorizationURL
        self.expiresIn = expiresIn
    }
}

/// IBKR Norviq Web Service (SOD) credentials — per-user token (`t`) + query ID (`q`).
public struct BrokerConnectCredentialsRequest: Codable, Sendable, Equatable {
    public let token: String
    public let queryId: String
    public let portfolioListId: String?

    public init(token: String, queryId: String, portfolioListId: String? = nil) {
        self.token = token
        self.queryId = queryId
        self.portfolioListId = portfolioListId
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
