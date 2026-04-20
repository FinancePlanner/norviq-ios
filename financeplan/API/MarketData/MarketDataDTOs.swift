import Foundation
import StockPlanShared

// Price-chart DTOs are local compatibility models until the remote FinanceShared
// package publishes these market-chart contracts.
enum PriceChartRange: String, Codable, Sendable, CaseIterable, Equatable {
    case oneHour = "1H"
    case oneDay = "1D"
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case oneYear = "1Y"
    case fiveYears = "5Y"

    var title: String {
        rawValue
    }
}

struct PriceChartPoint: Codable, Sendable, Equatable {
    let date: String
    let close: Double
    let open: Double?
    let high: Double?
    let low: Double?
    let volume: Int?
}

struct PriceChartSeries: Codable, Sendable, Equatable {
    let symbol: String
    let currency: String
    let range: String
    let points: [PriceChartPoint]
}

struct PriceChartComparisonResponse: Codable, Sendable, Equatable {
    let series: [PriceChartSeries]
    let range: String
}
