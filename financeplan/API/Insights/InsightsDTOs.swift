import Foundation

// Local, consume-only DTOs mirroring the backend's TickerSentimentResponse
// (GET /v1/insights/tickers/{symbol}/sentiment). Not shared via norviq-shared.
// Codable is declared in a `nonisolated extension` so the synthesized
// conformance isn't main-actor-isolated (the app target is MainActor-by-default),
// matching the existing StockInsightsDTOs pattern.

struct TickerSentimentResponse: Sendable, Equatable {
    let symbol: String
    let windowDays: Int
    let aggregate: TickerSentimentAggregate
    let posts: [TickerSentimentPost]
}

nonisolated extension TickerSentimentResponse: Codable {}

struct TickerSentimentAggregate: Sendable, Equatable {
    let label: String
    let score: Double?
    let postCount: Int
}

nonisolated extension TickerSentimentAggregate: Codable {}

struct TickerSentimentPost: Sendable, Equatable, Identifiable {
    let author: String?
    let authorHandle: String?
    let text: String
    let url: String?
    let sentimentLabel: String
    let sentimentScore: Double?
    let confidence: Double?
    let postedAt: String

    var id: String { (url ?? "") + postedAt + text }
}

nonisolated extension TickerSentimentPost: Codable {}

// MARK: - Retail sentiment aggregates
//
// These back the free surfaces: badges on portfolio and watchlist rows, the
// portfolio roll-up, and the market trending board. They deliberately carry no
// post text — that stays on the Pro ticker endpoint above.

struct SentimentSourceCounts: Sendable, Equatable {
    let x: Int
    let reddit: Int
    let stocktwits: Int
    let news: Int
    let investing: Int
    let seekingAlpha: Int

    var total: Int { x + reddit + stocktwits + news + investing + seekingAlpha }
}

nonisolated extension SentimentSourceCounts: Codable {}

struct SentimentTheme: Sendable, Equatable, Identifiable {
    let label: String
    let stance: String
    let evidenceCount: Int

    var id: String { label }
}

nonisolated extension SentimentTheme: Codable {}

struct SentimentThemesPayload: Sendable, Equatable {
    let themes: [SentimentTheme]
    let summary: String?
    let contrarianFlag: Bool
}

nonisolated extension SentimentThemesPayload: Codable {}

struct SymbolSentiment: Sendable, Equatable, Identifiable {
    let symbol: String
    let asOfDate: String
    /// nil means no chatter was measured. Not the same as neutral, and never to
    /// be rendered as a zero.
    let score: Double?
    let label: String
    let confidence: Double?
    let postCount: Int
    let delta1d: Double?
    let volumeZ: Double?
    let sourceCounts: SentimentSourceCounts
    let themes: SentimentThemesPayload?

    var id: String { symbol }
    var hasReading: Bool { score != nil }
}

nonisolated extension SymbolSentiment: Codable {}

struct SymbolSentimentBatchResponse: Sendable, Equatable {
    let windowDays: Int
    let requested: Int
    let symbols: [String: SymbolSentiment]
}

nonisolated extension SymbolSentimentBatchResponse: Codable {}

struct SentimentHoldingContribution: Sendable, Equatable, Identifiable {
    let symbol: String
    let score: Double
    let label: String
    /// Share of the covered total, 0…1.
    let weight: Double
    let delta1d: Double?

    var id: String { symbol }
}

nonisolated extension SentimentHoldingContribution: Codable {}

struct PortfolioSentimentResponse: Sendable, Equatable {
    let scope: String
    let asOfDate: String?
    let score: Double?
    let label: String
    /// Fraction of positions carrying a reading. The score covers only that
    /// subset, so this must be shown with it.
    let coverage: Double
    let symbolsCovered: Int
    let symbolsTotal: Int
    let postCount: Int
    let mostBullish: SentimentHoldingContribution?
    let mostBearish: SentimentHoldingContribution?
    let biggestMovers: [SentimentHoldingContribution]
}

nonisolated extension PortfolioSentimentResponse: Codable {}

struct TrendingSentimentEntry: Sendable, Equatable, Identifiable {
    let symbol: String
    let score: Double?
    let label: String
    let postCount: Int
    let volumeZ: Double?
    let delta1d: Double?

    var id: String { symbol }
}

nonisolated extension TrendingSentimentEntry: Codable {}

struct MarketTrendingResponse: Sendable, Equatable {
    let asOfDate: String?
    let windowDays: Int
    let mostDiscussed: [TrendingSentimentEntry]
    let bullish: [TrendingSentimentEntry]
    let bearish: [TrendingSentimentEntry]
    let biggestSwings: [TrendingSentimentEntry]
}

nonisolated extension MarketTrendingResponse: Codable {}
