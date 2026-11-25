import Foundation

/// The one chart-range vocabulary shown to the user (DS 2.0): `1D 1W 1M 3M YTD 1Y 5Y ALL`.
///
/// Each API keeps its own wire values. A chart offers only the ranges its data
/// supports, and converts a choice with the failable mappings below.
enum ChartRange: String, CaseIterable, Identifiable, Sendable {
    case oneDay = "1D"
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case ytd = "YTD"
    case oneYear = "1Y"
    case fiveYears = "5Y"
    case all = "ALL"

    var id: Self { self }
    var title: String { rawValue }

    /// YTD stays hidden until the portfolio API serves it.
    static let portfolio: [ChartRange] = [.oneWeek, .oneMonth, .threeMonths, .oneYear, .all]
    /// `PriceChartRange` has no YTD or ALL.
    static let asset: [ChartRange] = [.oneDay, .oneWeek, .oneMonth, .threeMonths, .oneYear, .fiveYears]
    static let crypto: [ChartRange] = [.oneDay, .oneWeek, .oneMonth, .threeMonths, .ytd, .oneYear, .all]
}

// MARK: - Display range -> wire range

extension PortfolioScreen.TimeRange {
    init?(_ range: ChartRange) {
        switch range {
        case .oneDay: self = .day
        case .oneWeek: self = .week
        case .oneMonth: self = .month
        case .threeMonths: self = .threeMonths
        case .oneYear: self = .year
        case .all: self = .all
        case .ytd, .fiveYears: return nil
        }
    }
}

extension PriceChartRange {
    init?(_ range: ChartRange) {
        switch range {
        case .oneDay: self = .oneDay
        case .oneWeek: self = .oneWeek
        case .oneMonth: self = .oneMonth
        case .threeMonths: self = .threeMonths
        case .oneYear: self = .oneYear
        case .fiveYears: self = .fiveYears
        case .ytd, .all: return nil
        }
    }
}

extension CryptoChartRange {
    init?(_ range: ChartRange) {
        switch range {
        case .oneDay: self = .day
        case .oneWeek: self = .week
        case .oneMonth: self = .month
        case .threeMonths: self = .quarter
        case .ytd: self = .ytd
        case .oneYear: self = .year
        case .all: self = .allTime
        case .fiveYears: return nil
        }
    }
}

// MARK: - Wire range -> display range

extension ChartRange {
    init?(_ range: PortfolioScreen.TimeRange) {
        switch range {
        case .day: self = .oneDay
        case .week: self = .oneWeek
        case .month: self = .oneMonth
        case .threeMonths: self = .threeMonths
        case .year: self = .oneYear
        case .all: self = .all
        }
    }

    /// `1H` is outside the DS 2.0 vocabulary, so it has no display range.
    init?(_ range: PriceChartRange) {
        switch range {
        case .oneHour: return nil
        case .oneDay: self = .oneDay
        case .oneWeek: self = .oneWeek
        case .oneMonth: self = .oneMonth
        case .threeMonths: self = .threeMonths
        case .oneYear: self = .oneYear
        case .fiveYears: self = .fiveYears
        }
    }

    init?(_ range: CryptoChartRange) {
        switch range {
        case .hour: return nil
        case .day: self = .oneDay
        case .week: self = .oneWeek
        case .month: self = .oneMonth
        case .quarter: self = .threeMonths
        case .ytd: self = .ytd
        case .year: self = .oneYear
        case .allTime: self = .all
        }
    }
}
