import Foundation
import StockPlanShared

// MARK: - Backend resolution

/// Resolutions accepted by the backend `crypto/history/:resolution/:symbol` route.
enum CryptoChartResolution: String, Codable {
    case oneMin = "1min"
    case fiveMin = "5min"
    case oneHour = "1hour"
    case light
    case full
}

// MARK: - User-facing range

/// User-selectable time windows, each mapping to a backend resolution and a lookback.
enum CryptoChartRange: String, CaseIterable, Identifiable {
    case hour
    case day
    case week
    case month
    case quarter
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hour: return "1H"
        case .day: return "1D"
        case .week: return "1W"
        case .month: return "1M"
        case .quarter: return "3M"
        case .year: return "1Y"
        }
    }

    var resolution: CryptoChartResolution {
        switch self {
        case .hour: return .oneMin
        case .day: return .fiveMin
        case .week: return .oneHour
        case .month, .quarter, .year: return .light
        }
    }

    /// Number of days to look back from "now" for this range.
    private var lookbackDays: Int {
        switch self {
        case .hour: return 1
        case .day: return 2
        case .week: return 7
        case .month: return 31
        case .quarter: return 93
        case .year: return 366
        }
    }

    /// `from` query value (yyyy-MM-dd) for this range, relative to `now`.
    func fromDateString(now: Date = Date()) -> String {
        let start = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: now) ?? now
        return CryptoChartDateParser.dayString(from: start)
    }

    /// `to` query value (yyyy-MM-dd).
    func toDateString(now: Date = Date()) -> String {
        CryptoChartDateParser.dayString(from: now)
    }
}

// MARK: - Plottable point

/// Presentation point with a parsed `Date`, derived from `CryptoHistoricalPoint`.
struct CryptoChartPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let close: Double

    init?(_ point: CryptoHistoricalPoint) {
        guard let parsed = CryptoChartDateParser.date(from: point.date) else { return nil }
        self.id = point.date
        self.date = parsed
        self.close = point.close
    }
}

// MARK: - Navigation route

/// Hashable route for pushing a coin detail screen via `navigationDestination`.
struct CryptoDetailRoute: Hashable {
    let symbol: String
    let name: String
}

// MARK: - Date parsing

/// Parses FMP date strings (intraday `yyyy-MM-dd HH:mm:ss` and EOD `yyyy-MM-dd`).
enum CryptoChartDateParser {
    private static let intraday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private static let day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func date(from string: String) -> Date? {
        intraday.date(from: string) ?? day.date(from: string)
    }

    static func dayString(from date: Date) -> String {
        day.string(from: date)
    }
}
