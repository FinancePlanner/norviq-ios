import Foundation

// MARK: - AI Insight Kind

/// Which insight card the client is requesting.
public enum AIInsightKind: String, Codable, Sendable, Equatable, CaseIterable {
    case expenses
    case portfolio
    case summary
}

// MARK: - Insight Highlight

/// A single labelled metric surfaced on an insight card.
public struct AIInsightHighlight: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        label
    }

    public let label: String
    public let value: String
    /// Optional direction indicator: "up", "down", or "flat".
    public let trend: String?

    public init(label: String, value: String, trend: String? = nil) {
        self.label = label
        self.value = value
        self.trend = trend
    }
}

// MARK: - Insight Card

/// An educational, plain-language insight card generated from the user's own data.
public struct AIInsightCardResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let kind: AIInsightKind
    public let title: String
    public let body: String
    public let highlights: [AIInsightHighlight]
    public let disclaimer: String
    public let generatedAt: Date

    /// Server-controlled disclaimer text. Never sourced from the model.
    public static let standardDisclaimer =
        "This is educational information about your own data, not financial advice."

    public init(
        id: UUID = UUID(),
        kind: AIInsightKind,
        title: String,
        body: String,
        highlights: [AIInsightHighlight],
        disclaimer: String = AIInsightCardResponse.standardDisclaimer,
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.highlights = highlights
        self.disclaimer = disclaimer
        self.generatedAt = generatedAt
    }
}
