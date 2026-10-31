import Foundation

public enum ChartBuilderPeriodKind: String, Codable, CaseIterable, Sendable {
    case annual
    case quarter
    case ttm
}

/// One aligned x-axis entry. The axis is derived from the primary symbol's
/// reporting periods, oldest to newest; peer series are matched onto it by
/// fiscal year (and fiscal period for quarterly data).
public struct ChartBuilderPeriod: Codable, Sendable, Equatable {
    /// Display label, e.g. "FY2024", "Q3 2024", "TTM Q3 2024".
    public let label: String
    public let fiscalYear: String?
    /// "Q1"..."Q4" or "FY".
    public let fiscalPeriod: String?
    /// Primary symbol's period end date (yyyy-MM-dd).
    public let endDate: String

    public init(label: String, fiscalYear: String?, fiscalPeriod: String?, endDate: String) {
        self.label = label
        self.fiscalYear = fiscalYear
        self.fiscalPeriod = fiscalPeriod
        self.endDate = endDate
    }
}

public struct ChartBuilderGrowthPoint: Codable, Sendable, Equatable {
    public let periodLabel: String
    public let absolute: Double?
    public let percent: Double?

    public init(periodLabel: String, absolute: Double?, percent: Double?) {
        self.periodLabel = periodLabel
        self.absolute = absolute
        self.percent = percent
    }
}

/// Growth statistics for one series over the returned window.
/// Percent figures are nil when the base value is zero or negative.
public struct ChartBuilderGrowthStats: Codable, Sendable, Equatable {
    public let yoy: [ChartBuilderGrowthPoint]
    public let totalChange: Double?
    public let totalChangePercent: Double?
    public let cagr: Double?

    public init(
        yoy: [ChartBuilderGrowthPoint],
        totalChange: Double?,
        totalChangePercent: Double?,
        cagr: Double?
    ) {
        self.yoy = yoy
        self.totalChange = totalChange
        self.totalChangePercent = totalChangePercent
        self.cagr = cagr
    }
}

public struct ChartBuilderSeries: Codable, Sendable, Equatable {
    public let symbol: String
    public let metricKey: String
    /// Metric display label; clients compose "SYMBOL · label" when comparing.
    public let label: String
    public let format: ChartMetricFormat
    /// Reported currency for currency-format metrics.
    public let currency: String?
    /// Exactly `periods.count` entries; nil = missing or misaligned period.
    public let values: [Double?]
    public let growth: ChartBuilderGrowthStats?

    public init(
        symbol: String,
        metricKey: String,
        label: String,
        format: ChartMetricFormat,
        currency: String?,
        values: [Double?],
        growth: ChartBuilderGrowthStats?
    ) {
        self.symbol = symbol
        self.metricKey = metricKey
        self.label = label
        self.format = format
        self.currency = currency
        self.values = values
        self.growth = growth
    }
}

public struct ChartBuilderCompany: Codable, Sendable, Equatable {
    public let symbol: String
    public let name: String?
    public let currency: String?

    public init(symbol: String, name: String?, currency: String?) {
        self.symbol = symbol
        self.name = name
        self.currency = currency
    }
}

public struct ChartBuilderResponse: Codable, Sendable, Equatable {
    public let period: ChartBuilderPeriodKind
    public let periods: [ChartBuilderPeriod]
    public let series: [ChartBuilderSeries]
    public let companies: [ChartBuilderCompany]

    public init(
        period: ChartBuilderPeriodKind,
        periods: [ChartBuilderPeriod],
        series: [ChartBuilderSeries],
        companies: [ChartBuilderCompany]
    ) {
        self.period = period
        self.periods = periods
        self.series = series
        self.companies = companies
    }
}

public struct ChartBuilderMetricGroupDTO: Codable, Sendable, Equatable {
    public let key: ChartMetricGroup
    public let label: String
    public let metrics: [ChartMetricDescriptor]

    public init(key: ChartMetricGroup, label: String, metrics: [ChartMetricDescriptor]) {
        self.key = key
        self.label = label
        self.metrics = metrics
    }
}

public struct ChartBuilderMetricCatalogResponse: Codable, Sendable, Equatable {
    public let groups: [ChartBuilderMetricGroupDTO]

    public init(groups: [ChartBuilderMetricGroupDTO]) {
        self.groups = groups
    }

    /// Catalog assembled from `ChartBuilderMetricCatalog.all`, grouped in
    /// declaration order.
    public static func current() -> ChartBuilderMetricCatalogResponse {
        let groups = ChartMetricGroup.allCases.compactMap { group -> ChartBuilderMetricGroupDTO? in
            let metrics = ChartBuilderMetricCatalog.metrics(in: group)
            guard !metrics.isEmpty else { return nil }
            return ChartBuilderMetricGroupDTO(key: group, label: group.title, metrics: metrics)
        }
        return ChartBuilderMetricCatalogResponse(groups: groups)
    }
}
