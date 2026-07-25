import Foundation

// Local DTOs mirroring GET /v1/dashboard/why-moved (backend WhyMovedDTOs).
// App-local to avoid a shared-package tag bump; nonisolated because the app
// target defaults to MainActor isolation.

nonisolated struct WhyMovedResponse: Codable, Equatable, Sendable {
  let asOf: String
  let portfolioChangePercent: Double?
  let portfolioChangeValue: Double?
  let movers: [WhyMovedMover]
  let context: WhyMovedContext
  let aiSummary: WhyMovedAISummary?
  /// Nil when no mover carried sentiment, so the card can omit the claim
  /// instead of rendering an empty one.
  let sentimentSource: WhyMovedSentimentSource?
}

nonisolated struct WhyMovedSentimentSource: Codable, Equatable, Sendable {
  let postsAnalyzed: Int
  let symbolsCovered: Int
  let windowDays: Int
  let lastPostAt: String?
}

nonisolated struct WhyMovedMover: Codable, Equatable, Sendable, Identifiable {
  var id: String { symbol }
  let symbol: String
  let changePercent: Double
  let contribution: Double?
  let weightPercent: Double?
  let sentiment: WhyMovedSentiment?
}

nonisolated struct WhyMovedSentiment: Codable, Equatable, Sendable {
  let label: String
  let score: Double?
  let postCount: Int
}

nonisolated struct WhyMovedContext: Codable, Equatable, Sendable {
  let indices: [WhyMovedIndex]
  let topics: [WhyMovedTopic]
}

nonisolated struct WhyMovedIndex: Codable, Equatable, Sendable, Identifiable {
  var id: String { symbol }
  let symbol: String
  let label: String
  let changePercent: Double
}

nonisolated struct WhyMovedTopic: Codable, Equatable, Sendable, Identifiable {
  var id: String { topic }
  let topic: String
  let count: Int
}

nonisolated struct WhyMovedAISummary: Codable, Equatable, Sendable {
  let text: String
  let generatedAt: String
}
