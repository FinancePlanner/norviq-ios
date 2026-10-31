import Foundation

public enum UserActivityType: String, Codable, Sendable, CaseIterable {
    case stockAdded = "stock_added"
    case expenseRecorded = "expense_recorded"
    case stockUpdated = "stock_updated"
    case expenseUpdated = "expense_updated"
    case newsViewed = "news_viewed"
}

public struct UserActivityResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let userId: UUID
    public let type: UserActivityType
    public let title: String
    public let subtitle: String
    public let amount: Double?
    public let isGrowth: Bool
    public let symbol: String // SF Symbol name
    public let createdAt: Date

    public init(
        id: UUID,
        userId: UUID,
        type: UserActivityType,
        title: String,
        subtitle: String,
        amount: Double?,
        isGrowth: Bool,
        symbol: String,
        createdAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.amount = amount
        self.isGrowth = isGrowth
        self.symbol = symbol
        self.createdAt = createdAt
    }
}

public struct NewsViewRequest: Codable, Sendable, Equatable {
    public let newsId: UUID?
    public let symbol: String?
    public let headline: String
    public let url: String?

    public init(newsId: UUID? = nil, symbol: String? = nil, headline: String, url: String? = nil) {
        self.newsId = newsId
        self.symbol = symbol
        self.headline = headline
        self.url = url
    }
}
