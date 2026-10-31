import Foundation

public struct EarningsQueryRequest: Codable, Sendable, Equatable {
    public let from: String?
    public let to: String?
    public let symbol: String?
    public let international: Bool?

    public init(from: String? = nil, to: String? = nil, symbol: String? = nil, international: Bool? = nil) {
        self.from = from
        self.to = to
        self.symbol = symbol
        self.international = international
    }
}

public struct EarningsItemResponse: Codable, Sendable, Equatable {
    public let date: String?
    public let epsActual: Double?
    public let epsEstimate: Double?
    public let hour: String?
    public let quarter: Int?
    public let revenueActual: Double?
    public let revenueEstimate: Double?
    public let symbol: String?
    public let year: Int?

    public init(
        date: String? = nil,
        epsActual: Double? = nil,
        epsEstimate: Double? = nil,
        hour: String? = nil,
        quarter: Int? = nil,
        revenueActual: Double? = nil,
        revenueEstimate: Double? = nil,
        symbol: String? = nil,
        year: Int? = nil
    ) {
        self.date = date
        self.epsActual = epsActual
        self.epsEstimate = epsEstimate
        self.hour = hour
        self.quarter = quarter
        self.revenueActual = revenueActual
        self.revenueEstimate = revenueEstimate
        self.symbol = symbol
        self.year = year
    }
}
