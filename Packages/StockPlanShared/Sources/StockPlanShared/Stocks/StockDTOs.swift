import Foundation

public enum AssetCategory: String, Codable, Sendable, CaseIterable {
    case stock
    case etf
    case mutualFund = "mutual_fund"
    case crypto
    case cash
    case bond
    case realEstate = "real_estate"
    case commodity
}

public struct PortfolioListRequest: Codable, Sendable, Equatable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public struct PortfolioListResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let isDefault: Bool
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        name: String,
        isDefault: Bool,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct WatchlistListRequest: Codable, Sendable, Equatable {
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public struct WatchlistListResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let isDefault: Bool
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        name: String,
        isDefault: Bool,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct StockRequest: Codable, Sendable, Equatable {
    public let symbol: String
    public let shares: Double
    public let buyPrice: Double
    public let buyDate: String
    public let notes: String?
    public let category: AssetCategory
    public let portfolioListId: String?

    public init(
        symbol: String,
        shares: Double,
        buyPrice: Double,
        buyDate: String,
        notes: String?,
        category: AssetCategory = .stock,
        portfolioListId: String? = nil
    ) {
        self.symbol = symbol
        self.shares = shares
        self.buyPrice = buyPrice
        self.buyDate = buyDate
        self.notes = notes
        self.category = category
        self.portfolioListId = portfolioListId
    }
}

public struct SellStockRequest: Codable, Sendable, Equatable {
    public let sharesToSell: Double
    public let sellPrice: Double
    public let sellDate: String

    public init(sharesToSell: Double, sellPrice: Double, sellDate: String) {
        self.sharesToSell = sharesToSell
        self.sellPrice = sellPrice
        self.sellDate = sellDate
    }
}

public struct StockResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let symbol: String
    public let shares: Double
    public let buyPrice: Double
    public let buyDate: String
    public let notes: String?
    public let category: AssetCategory
    public let portfolioListId: String?
    public let createdAt: String // ISO8601 timestamp for pagination

    public init(
        id: String, symbol: String, shares: Double, buyPrice: Double, buyDate: String,
        notes: String?, category: AssetCategory = .stock, portfolioListId: String? = nil,
        createdAt: String
    ) {
        self.id = id
        self.symbol = symbol
        self.shares = shares
        self.buyPrice = buyPrice
        self.buyDate = buyDate
        self.notes = notes
        self.category = category
        self.portfolioListId = portfolioListId
        self.createdAt = createdAt
    }
}

public enum WatchlistStatus: String, Codable, Sendable, CaseIterable {
    case active
    case researching
    case waiting
    case ready
    case archived
    /// The pilot this item was mirrored from has sold it. Set only by pilot follows.
    case exited

    /// Lenient: a status this build does not know decodes as `.active`, so a
    /// server that adds a status never breaks decoding a whole watchlist.
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = WatchlistStatus(rawValue: raw) ?? .active
    }
}

public struct WatchlistItemRequest: Codable, Sendable, Equatable {
    public let symbol: String
    public let note: String?
    public let status: WatchlistStatus?
    public let nextReviewAt: String?
    public let watchlistListId: String?

    public init(
        symbol: String,
        note: String? = nil,
        status: WatchlistStatus? = nil,
        nextReviewAt: String? = nil,
        watchlistListId: String? = nil
    ) {
        self.symbol = symbol
        self.note = note
        self.status = status
        self.nextReviewAt = nextReviewAt
        self.watchlistListId = watchlistListId
    }
}

public struct WatchlistItemUpdateRequest: Codable, Sendable, Equatable {
    public let note: String?
    public let status: WatchlistStatus?
    public let lastReviewedAt: String?
    public let nextReviewAt: String?
    public let watchlistListId: String?

    public init(
        note: String? = nil,
        status: WatchlistStatus? = nil,
        lastReviewedAt: String? = nil,
        nextReviewAt: String? = nil,
        watchlistListId: String? = nil
    ) {
        self.note = note
        self.status = status
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewAt = nextReviewAt
        self.watchlistListId = watchlistListId
    }
}

public struct WatchlistItemResponse: Codable, Sendable, Equatable {
    public let id: String
    public let symbol: String
    public let note: String?
    public let status: WatchlistStatus
    public let createdAt: String?
    public let updatedAt: String?
    public let lastReviewedAt: String?
    public let nextReviewAt: String?
    public let watchlistListId: String?

    public init(
        id: String,
        symbol: String,
        note: String?,
        status: WatchlistStatus,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        lastReviewedAt: String? = nil,
        nextReviewAt: String? = nil,
        watchlistListId: String? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.note = note
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewAt = nextReviewAt
        self.watchlistListId = watchlistListId
    }
}

public struct ResearchNoteRequest: Codable, Sendable, Equatable {
    public let symbol: String
    public let title: String?
    public let thesis: String
    public let risks: String?
    public let catalysts: String?
    public let referenceLinks: [String]?

    public init(
        symbol: String,
        title: String?,
        thesis: String,
        risks: String?,
        catalysts: String?,
        referenceLinks: [String]?
    ) {
        self.symbol = symbol
        self.title = title
        self.thesis = thesis
        self.risks = risks
        self.catalysts = catalysts
        self.referenceLinks = referenceLinks
    }
}

public struct ResearchNoteResponse: Codable, Sendable, Equatable {
    public let id: String
    public let symbol: String
    public let title: String?
    public let thesis: String
    public let risks: String?
    public let catalysts: String?
    public let referenceLinks: [String]?

    public init(
        id: String,
        symbol: String,
        title: String?,
        thesis: String,
        risks: String?,
        catalysts: String?,
        referenceLinks: [String]?
    ) {
        self.id = id
        self.symbol = symbol
        self.title = title
        self.thesis = thesis
        self.risks = risks
        self.catalysts = catalysts
        self.referenceLinks = referenceLinks
    }
}

public struct PriceRange: Codable, Sendable, Equatable {
    public let low: Double
    public let high: Double

    public init(low: Double, high: Double) {
        self.low = low
        self.high = high
    }
}

public struct StockValuationRequest: Codable, Sendable, Equatable {
    public let symbol: String
    public let bearCase: PriceRange
    public let baseCase: PriceRange
    public let bullCase: PriceRange
    public let rationale: String?
    public let targetDate: String?

    public init(
        symbol: String,
        bearCase: PriceRange,
        baseCase: PriceRange,
        bullCase: PriceRange,
        rationale: String?,
        targetDate: String?
    ) {
        self.symbol = symbol
        self.bearCase = bearCase
        self.baseCase = baseCase
        self.bullCase = bullCase
        self.rationale = rationale
        self.targetDate = targetDate
    }
}

public struct ScenarioTargetResponse: Codable, Sendable, Equatable {
    public let id: String
    public let symbol: String
    public let scenario: String
    public let targetPrice: Double
    public let targetDate: String?
    public let rationale: String?

    public init(
        id: String,
        symbol: String,
        scenario: String,
        targetPrice: Double,
        targetDate: String?,
        rationale: String?
    ) {
        self.id = id
        self.symbol = symbol
        self.scenario = scenario
        self.targetPrice = targetPrice
        self.targetDate = targetDate
        self.rationale = rationale
    }
}

public typealias TargetResponse = ScenarioTargetResponse

public struct TargetRequest: Codable, Sendable, Equatable {
    public let symbol: String
    public let scenario: String
    public let targetPrice: Double
    public let targetDate: String?
    public let rationale: String?

    public init(
        symbol: String,
        scenario: String,
        targetPrice: Double,
        targetDate: String? = nil,
        rationale: String? = nil
    ) {
        self.symbol = symbol
        self.scenario = scenario
        self.targetPrice = targetPrice
        self.targetDate = targetDate
        self.rationale = rationale
    }
}

public struct StockHistory: Codable, Sendable, Equatable {
    public let date: String
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Int

    public init(date: String, open: Double, high: Double, low: Double, close: Double, volume: Int) {
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
}

public struct StockNews: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        url
    }

    public let title: String
    public let url: String
    public let date: String
    public let imageURL: String?
    public let source: String?
    public let summary: String?
    public let newsId: String?
    public let symbol: String?

    public init(
        title: String,
        url: String,
        date: String,
        imageURL: String? = nil,
        source: String? = nil,
        summary: String? = nil,
        newsId: String? = nil,
        symbol: String? = nil
    ) {
        self.title = title
        self.url = url
        self.date = date
        self.imageURL = imageURL
        self.source = source
        self.summary = summary
        self.newsId = newsId
        self.symbol = symbol
    }
}

// MARK: - Bulk Import

public struct BulkStockRequest: Codable, Sendable, Equatable {
    public let stocks: [StockRequest]

    public init(stocks: [StockRequest]) {
        self.stocks = stocks
    }
}

public struct BulkStockResultItem: Codable, Sendable, Equatable {
    public let index: Int
    public let stock: StockResponse?
    public let error: String?

    public init(index: Int, stock: StockResponse? = nil, error: String? = nil) {
        self.index = index
        self.stock = stock
        self.error = error
    }
}

public struct BulkStockResponse: Codable, Sendable, Equatable {
    public let created: Int
    public let failed: Int
    public let results: [BulkStockResultItem]

    public init(created: Int, failed: Int, results: [BulkStockResultItem]) {
        self.created = created
        self.failed = failed
        self.results = results
    }
}

public struct StockValuationDraft: Codable, Sendable, Equatable {
    public let bearLow: Double
    public let bearHigh: Double
    public let baseLow: Double
    public let baseHigh: Double
    public let bullLow: Double
    public let bullHigh: Double
    public let rationale: String?
    public let targetDate: String?

    public init(
        bearLow: Double,
        bearHigh: Double,
        baseLow: Double,
        baseHigh: Double,
        bullLow: Double,
        bullHigh: Double,
        rationale: String? = nil,
        targetDate: String? = nil
    ) {
        self.bearLow = bearLow
        self.bearHigh = bearHigh
        self.baseLow = baseLow
        self.baseHigh = baseHigh
        self.bullLow = bullLow
        self.bullHigh = bullHigh
        self.rationale = rationale
        self.targetDate = targetDate
    }
}
