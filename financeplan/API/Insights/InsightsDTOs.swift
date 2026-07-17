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
