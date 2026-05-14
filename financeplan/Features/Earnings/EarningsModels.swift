import Foundation

public struct EarningsEvent: Identifiable, Equatable, Sendable {
    public var id: String { "\(symbol)-\(date)" }
    public let symbol: String
    public let date: String // YYYY-MM-DD
    public let epsActual: Double?
    public let epsEstimated: Double?
    public let revenueActual: Double?
    public let revenueEstimated: Double?
    public let lastUpdated: String?
    public let surprisePercent: Double?
    public let hasTranscript: Bool?

    public init(
        symbol: String,
        date: String,
        epsActual: Double? = nil,
        epsEstimated: Double? = nil,
        revenueActual: Double? = nil,
        revenueEstimated: Double? = nil,
        lastUpdated: String? = nil,
        surprisePercent: Double? = nil,
        hasTranscript: Bool? = nil
    ) {
        self.symbol = symbol
        self.date = date
        self.epsActual = epsActual
        self.epsEstimated = epsEstimated
        self.revenueActual = revenueActual
        self.revenueEstimated = revenueEstimated
        self.lastUpdated = lastUpdated
        self.surprisePercent = surprisePercent
        self.hasTranscript = hasTranscript
    }
}

nonisolated extension EarningsEvent: Codable {}

public struct EarningsTranscript: Identifiable, Equatable, Sendable {
    public var id: String { "\(symbol)-\(date)-\(year)-\(quarter)" }
    public let symbol: String
    public let date: String
    public let year: Int
    public let quarter: Int
    public let period: String?
    public let content: String
    public let provider: String

    public init(
        symbol: String,
        date: String,
        year: Int,
        quarter: Int,
        period: String? = nil,
        content: String,
        provider: String
    ) {
        self.symbol = symbol
        self.date = date
        self.year = year
        self.quarter = quarter
        self.period = period
        self.content = content
        self.provider = provider
    }
}

nonisolated extension EarningsTranscript: Codable {}
