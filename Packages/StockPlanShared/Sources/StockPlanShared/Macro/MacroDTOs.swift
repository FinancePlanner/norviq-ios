import Foundation

// MARK: - Inflation Snapshot (primary response for /v1/macro/inflation/current)

public struct InflationSnapshotResponse: Codable, Sendable, Equatable {
    public let country: String // "US", "BR", "PT", "EA"
    public let currency: String // "USD", "BRL", "EUR"
    public let asOf: String
    public let updatedAt: String
    public let source: String
    public let headline: InflationGaugeDTO
    public let gauges: [InflationGaugeDTO]
    public let components: [InflationComponentDTO]
    public let topMovers: [TopMoverDTO]
    public let notes: String?
    public let nextPrintCountdown: NextPrintDTO?

    public init(
        country: String,
        currency: String,
        asOf: String,
        updatedAt: String,
        source: String,
        headline: InflationGaugeDTO,
        gauges: [InflationGaugeDTO],
        components: [InflationComponentDTO],
        topMovers: [TopMoverDTO],
        notes: String? = nil,
        nextPrintCountdown: NextPrintDTO? = nil
    ) {
        self.country = country
        self.currency = currency
        self.asOf = asOf
        self.updatedAt = updatedAt
        self.source = source
        self.headline = headline
        self.gauges = gauges
        self.components = components
        self.topMovers = topMovers
        self.notes = notes
        self.nextPrintCountdown = nextPrintCountdown
    }
}

// MARK: - Gauge

public struct InflationGaugeDTO: Codable, Sendable, Equatable {
    public let name: String
    public let nowValue: Double
    public let officialValue: Double?
    public let officialAsOf: String?
    public let gap: Double?
    public let unit: String // "percent"

    // Nowflation-specific
    public let colVariant: Double? // Cost-of-Living variant
    public let cumulativeSinceBase: Double?
    public let basePeriod: String?

    public init(
        name: String,
        nowValue: Double,
        officialValue: Double? = nil,
        officialAsOf: String? = nil,
        gap: Double? = nil,
        unit: String = "percent",
        colVariant: Double? = nil,
        cumulativeSinceBase: Double? = nil,
        basePeriod: String? = nil
    ) {
        self.name = name
        self.nowValue = nowValue
        self.officialValue = officialValue
        self.officialAsOf = officialAsOf
        self.gap = gap
        self.unit = unit
        self.colVariant = colVariant
        self.cumulativeSinceBase = cumulativeSinceBase
        self.basePeriod = basePeriod
    }
}

// MARK: - Component Breakdown

public struct InflationComponentDTO: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        category
    }

    public let category: String
    public let ourYoY: Double
    public let blsYoY: Double?
    public let cpiWeight: Double?
    public let contributionBps: Double? // optional impact in basis points

    public init(
        category: String,
        ourYoY: Double,
        blsYoY: Double? = nil,
        cpiWeight: Double? = nil,
        contributionBps: Double? = nil
    ) {
        self.category = category
        self.ourYoY = ourYoY
        self.blsYoY = blsYoY
        self.cpiWeight = cpiWeight
        self.contributionBps = contributionBps
    }
}

// MARK: - Top Movers (Utilities, Food, Shelter emphasis)

public struct TopMoverDTO: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        category
    }

    public let category: String
    public let changeYoY: Double
    public let changeMoM: Double?
    public let weight: Double?
    public let direction: String? // "up" | "down" | "flat"

    public init(
        category: String,
        changeYoY: Double,
        changeMoM: Double? = nil,
        weight: Double? = nil,
        direction: String? = nil
    ) {
        self.category = category
        self.changeYoY = changeYoY
        self.changeMoM = changeMoM
        self.weight = weight
        self.direction = direction
    }
}

// MARK: - Next Print / Forecast Info

public struct NextPrintDTO: Codable, Sendable, Equatable {
    public let date: String?
    public let daysRemaining: Int?
    public let forecastNowflation: Double?
    public let streetConsensus: Double?
    public let lastOfficial: Double?

    public init(
        date: String? = nil,
        daysRemaining: Int? = nil,
        forecastNowflation: Double? = nil,
        streetConsensus: Double? = nil,
        lastOfficial: Double? = nil
    ) {
        self.date = date
        self.daysRemaining = daysRemaining
        self.forecastNowflation = forecastNowflation
        self.streetConsensus = streetConsensus
        self.lastOfficial = lastOfficial
    }
}

// MARK: - Historical Series (for charts)

public struct MacroSeriesPoint: Codable, Sendable, Equatable {
    public let date: String
    public let value: Double
    public let series: String // "nowflation_cpi", "official_cpi", "pce", etc.

    public init(date: String, value: Double, series: String) {
        self.date = date
        self.value = value
        self.series = series
    }
}

public struct MacroSeriesResponse: Codable, Sendable, Equatable {
    public let series: String
    public let points: [MacroSeriesPoint]
    public let country: String?
    public let unit: String?

    public init(series: String, points: [MacroSeriesPoint], country: String? = nil, unit: String? = nil) {
        self.series = series
        self.points = points
        self.country = country
        self.unit = unit
    }
}

// MARK: - Supported Countries

public struct SupportedCountry: Codable, Sendable, Equatable {
    public let code: String
    public let name: String
    public let currency: String
    public let dataSource: String
    public let hasDailyData: Bool

    public init(code: String, name: String, currency: String, dataSource: String, hasDailyData: Bool) {
        self.code = code
        self.name = name
        self.currency = currency
        self.dataSource = dataSource
        self.hasDailyData = hasDailyData
    }
}
