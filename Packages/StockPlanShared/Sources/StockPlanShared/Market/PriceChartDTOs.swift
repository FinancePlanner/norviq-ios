import Foundation

// MARK: - Price Chart Range

public enum PriceChartRange: String, Codable, Sendable, CaseIterable, Equatable {
    case oneHour = "1H"
    case oneDay = "1D"
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case oneYear = "1Y"
    case fiveYears = "5Y"

    public var title: String {
        rawValue
    }
}

// MARK: - Price Chart Point

public struct PriceChartPoint: Codable, Sendable, Equatable {
    public let date: String
    public let close: Double
    public let open: Double?
    public let high: Double?
    public let low: Double?
    public let volume: Int?

    public init(
        date: String,
        close: Double,
        open: Double? = nil,
        high: Double? = nil,
        low: Double? = nil,
        volume: Int? = nil
    ) {
        self.date = date
        self.close = close
        self.open = open
        self.high = high
        self.low = low
        self.volume = volume
    }
}

// MARK: - Price Chart Series

public struct PriceChartSeries: Codable, Sendable, Equatable {
    public let symbol: String
    public let currency: String
    public let range: String
    public let points: [PriceChartPoint]

    public init(
        symbol: String,
        currency: String,
        range: String,
        points: [PriceChartPoint]
    ) {
        self.symbol = symbol
        self.currency = currency
        self.range = range
        self.points = points
    }
}

// MARK: - Price Chart Comparison Response

public struct PriceChartComparisonResponse: Codable, Sendable, Equatable {
    public let series: [PriceChartSeries]
    public let range: String

    public init(series: [PriceChartSeries], range: String) {
        self.series = series
        self.range = range
    }
}
