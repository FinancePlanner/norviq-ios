import Foundation

public struct NewsItemRequest: Codable, Sendable, Equatable {
    public let symbol: String
    public let headline: String
    public let source: String?
    public let url: String?
    public let summary: String?
    public let publishedAt: String?

    public init(
        symbol: String,
        headline: String,
        source: String?,
        url: String?,
        summary: String?,
        publishedAt: String?
    ) {
        self.symbol = symbol
        self.headline = headline
        self.source = source
        self.url = url
        self.summary = summary
        self.publishedAt = publishedAt
    }
}

public struct NewsItemResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let symbol: String
    public let headline: String
    public let source: String?
    public let url: String?
    public let imageUrl: String?
    public let summary: String?
    public let publishedAt: String
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        symbol: String,
        headline: String,
        source: String? = nil,
        url: String? = nil,
        imageUrl: String? = nil,
        summary: String? = nil,
        publishedAt: String,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.headline = headline
        self.source = source
        self.url = url
        self.imageUrl = imageUrl
        self.summary = summary
        self.publishedAt = publishedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct NewsSyncResponse: Codable, Sendable, Equatable {
    public let provider: String
    public let symbolsCount: Int
    public let fetchedCount: Int
    public let insertedCount: Int
    public let updatedCount: Int
    public let skippedCount: Int

    public init(
        provider: String,
        symbolsCount: Int,
        fetchedCount: Int,
        insertedCount: Int,
        updatedCount: Int,
        skippedCount: Int
    ) {
        self.provider = provider
        self.symbolsCount = symbolsCount
        self.fetchedCount = fetchedCount
        self.insertedCount = insertedCount
        self.updatedCount = updatedCount
        self.skippedCount = skippedCount
    }
}

public struct FinnhubNewsWebhookResponse: Codable, Sendable, Equatable {
    public let provider: String
    public let receivedCount: Int
    public let matchedSymbolsCount: Int
    public let matchedUsersCount: Int
    public let insertedCount: Int
    public let skippedCount: Int

    public init(
        provider: String,
        receivedCount: Int,
        matchedSymbolsCount: Int,
        matchedUsersCount: Int,
        insertedCount: Int,
        skippedCount: Int
    ) {
        self.provider = provider
        self.receivedCount = receivedCount
        self.matchedSymbolsCount = matchedSymbolsCount
        self.matchedUsersCount = matchedUsersCount
        self.insertedCount = insertedCount
        self.skippedCount = skippedCount
    }
}
