import Foundation

public struct EarningsEvent: Identifiable, Codable, Equatable, Sendable {
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
