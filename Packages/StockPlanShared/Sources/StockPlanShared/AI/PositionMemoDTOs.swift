import Foundation

public struct PositionMemoCard: Codable, Sendable, Equatable {
    public let id: String
    public let symbol: String
    public let title: String
    public let verdict: String
    public let bookmarked: Bool

    public init(id: String, symbol: String, title: String, verdict: String, bookmarked: Bool) {
        self.id = id
        self.symbol = symbol
        self.title = title
        self.verdict = verdict
        self.bookmarked = bookmarked
    }
}

public struct PositionMemoMark: Codable, Sendable, Equatable {
    public let cost: Double?
    public let costCurrency: String?
    /// `stated` when the user typed a cost, `lots` when it came from saved holdings, `none` otherwise.
    public let costSource: String
    public let liveSymbol: String?
    public let livePrice: Double?
    public let liveCurrency: String?
    public let primarySymbol: String?
    public let primaryPrice: Double?
    public let primaryCurrency: String?
    public let fxPair: String?
    public let fxRate: Double?
    public let fxDate: String?
    /// Live price expressed in `costCurrency` when a conversion was possible.
    public let priceInCostCurrency: Double?
    public let drawdownPercent: Double?
    /// Signed. Down 34% is `-34`.
    public let statedPercent: Double?
    public let priceImpliedByStatedPercent: Double?
    /// Percent gain from the live (converted) price back to cost.
    public let breakevenPercent: Double?
    public let shares: Double?
    public let lotAveragePrice: Double?

    public init(
        cost: Double?,
        costCurrency: String?,
        costSource: String,
        liveSymbol: String?,
        livePrice: Double?,
        liveCurrency: String?,
        primarySymbol: String?,
        primaryPrice: Double?,
        primaryCurrency: String?,
        fxPair: String?,
        fxRate: Double?,
        fxDate: String?,
        priceInCostCurrency: Double?,
        drawdownPercent: Double?,
        statedPercent: Double?,
        priceImpliedByStatedPercent: Double?,
        breakevenPercent: Double?,
        shares: Double?,
        lotAveragePrice: Double?
    ) {
        self.cost = cost
        self.costCurrency = costCurrency
        self.costSource = costSource
        self.liveSymbol = liveSymbol
        self.livePrice = livePrice
        self.liveCurrency = liveCurrency
        self.primarySymbol = primarySymbol
        self.primaryPrice = primaryPrice
        self.primaryCurrency = primaryCurrency
        self.fxPair = fxPair
        self.fxRate = fxRate
        self.fxDate = fxDate
        self.priceInCostCurrency = priceInCostCurrency
        self.drawdownPercent = drawdownPercent
        self.statedPercent = statedPercent
        self.priceImpliedByStatedPercent = priceImpliedByStatedPercent
        self.breakevenPercent = breakevenPercent
        self.shares = shares
        self.lotAveragePrice = lotAveragePrice
    }
}

public struct PositionMemoSection: Codable, Sendable, Equatable {
    public let heading: String
    public let paragraphs: [String]

    public init(heading: String, paragraphs: [String]) {
        self.heading = heading
        self.paragraphs = paragraphs
    }
}

public struct PositionMemoSource: Codable, Sendable, Equatable {
    public let label: String
    public let symbol: String?
    public let asOf: String?
    public let url: String?

    public init(label: String, symbol: String?, asOf: String?, url: String?) {
        self.label = label
        self.symbol = symbol
        self.asOf = asOf
        self.url = url
    }
}

public struct PositionMemoListItem: Codable, Sendable, Equatable {
    public let id: String
    public let askedSymbol: String
    public let primarySymbol: String
    public let title: String
    public let verdict: String
    public let bookmarked: Bool
    public let createdAt: String

    public init(
        id: String,
        askedSymbol: String,
        primarySymbol: String,
        title: String,
        verdict: String,
        bookmarked: Bool,
        createdAt: String
    ) {
        self.id = id
        self.askedSymbol = askedSymbol
        self.primarySymbol = primarySymbol
        self.title = title
        self.verdict = verdict
        self.bookmarked = bookmarked
        self.createdAt = createdAt
    }
}

public struct PositionMemoDetail: Codable, Sendable, Equatable {
    public let id: String
    public let askedSymbol: String
    public let primarySymbol: String
    public let title: String
    public let mark: PositionMemoMark
    public let sections: [PositionMemoSection]
    public let verdict: String
    public let sources: [PositionMemoSource]
    public let footer: String
    public let bookmarked: Bool
    public let createdAt: String

    public init(
        id: String,
        askedSymbol: String,
        primarySymbol: String,
        title: String,
        mark: PositionMemoMark,
        sections: [PositionMemoSection],
        verdict: String,
        sources: [PositionMemoSource],
        footer: String,
        bookmarked: Bool,
        createdAt: String
    ) {
        self.id = id
        self.askedSymbol = askedSymbol
        self.primarySymbol = primarySymbol
        self.title = title
        self.mark = mark
        self.sections = sections
        self.verdict = verdict
        self.sources = sources
        self.footer = footer
        self.bookmarked = bookmarked
        self.createdAt = createdAt
    }
}

public struct PositionMemoBookmarkRequest: Codable, Sendable, Equatable {
    public let bookmarked: Bool

    public init(bookmarked: Bool) {
        self.bookmarked = bookmarked
    }
}

public enum PositionMemoCopy {
    public static let footer = "This is Q's view of your holding, not financial advice. Figures come from the sources listed and from your saved cost."
    public static let unavailableBusiness = "The income statement was not available, so this memo does not state revenue, margins, or earnings."
}
