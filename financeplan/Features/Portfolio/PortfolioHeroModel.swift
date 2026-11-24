import Foundation
import StockPlanShared

/// What the portfolio hero may honestly say (spec § 2.0 A1, A2, A5; § 5.5).
///
/// - The value is in the currency the data names, never the phone's.
/// - Holdings in more than one currency are shown as per-currency subtotals,
///   not summed: there is no conversion rate to add them with.
/// - A change is computed from the fetched series, first point to last, and
///   always carries its range ("1 month"), never "vs previous close".
/// - A series whose last point is more than four calendar days old shows no
///   change and no line, only "Prices as of {date}".
/// - Fewer than three points shows no line: two points make a slope, not a
///   trend.
struct PortfolioHeroModel: Equatable {
  enum Direction: Equatable {
    case up
    case down
    case flat
  }

  /// Nil when holdings are in more than one currency; see `subtotalTexts`.
  let valueText: String?
  /// One finished money string per currency, sorted by code. Empty unless mixed.
  let subtotalTexts: [String]
  /// "+$3,432.05 (+7.6%)". Nil when the series can't support a change.
  let deltaText: String?
  /// "1 month", "since 26 Oct 2026". Nil whenever `deltaText` is nil.
  let basisText: String?
  let direction: Direction
  /// "Prices as of 11 Nov 2026" when the series is stale.
  let asOfText: String?
  /// Why there is no line, when the series is fresh but too short or empty.
  let historyCaption: String?
  /// The series to draw: empty when stale or shorter than three points.
  let points: [ChartDataPoint]
  /// The currency of `valueText` and `points`, for axis labels and pills.
  let currencyCode: String?

  /// A series whose last point is older than this many calendar days is stale.
  static let staleAfterDays = 4
  /// Fewer points than this is "too little history" for a line or a change.
  static let minimumTrendPoints = 3

  static func make(
    performance: PortfolioPerformanceResponse?,
    holdingsByCurrency: [String: Double],
    range: PortfolioScreen.TimeRange,
    now: Date,
    locale: Locale,
    liveTotal: Double? = nil
  ) -> PortfolioHeroModel {
    let baseCurrency = MoneyFormatter.resolvedCode(performance?.baseCurrency)
    let series = parse(performance?.points ?? [])
    let holdings = holdingsByCurrency
      .reduce(into: [String: Double]()) { result, entry in
        guard let code = MoneyFormatter.resolvedCode(entry.key), entry.value != 0 else { return }
        result[code, default: 0] += entry.value
      }

    let isStale = series.last.map { isOlderThanStaleLimit($0.date, now: now) } ?? false
    let hasTrend = !isStale && series.count >= minimumTrendPoints

    // Value and its currency.
    var valueText: String?
    var subtotalTexts: [String] = []
    var currencyCode: String?
    if holdings.count > 1 {
      subtotalTexts = holdings.keys.sorted().map { code in
        MoneyFormatter.string(holdings[code] ?? 0, currencyCode: code, locale: locale)
      }
      currencyCode = baseCurrency
    } else if hasTrend, let last = series.last {
      currencyCode = baseCurrency
      valueText = MoneyFormatter.string(last.value, currencyCode: currencyCode, locale: locale)
    } else if let liveTotal {
      currencyCode = holdings.keys.first ?? baseCurrency
      valueText = MoneyFormatter.string(liveTotal, currencyCode: currencyCode, locale: locale)
    } else if let (code, total) = holdings.first.map({ ($0.key, $0.value) }) {
      currencyCode = code
      valueText = MoneyFormatter.string(total, currencyCode: code, locale: locale)
    } else if let last = series.last {
      // Only the stored series is left: show it, with its date under it.
      currencyCode = baseCurrency
      valueText = MoneyFormatter.string(last.value, currencyCode: currencyCode, locale: locale)
    } else {
      currencyCode = baseCurrency
    }

    // Change across the fetched range.
    var deltaText: String?
    var basisText: String?
    var direction = Direction.flat
    if hasTrend, let first = series.first, let last = series.last {
      let change = last.value - first.value
      direction = change > 0 ? .up : (change < 0 ? .down : .flat)
      let amount = MoneyFormatter.signed(change, currencyCode: baseCurrency, locale: locale)
      if first.value > 0 {
        let percent = MoneyFormatter.percentSigned(change / first.value, locale: locale)
        deltaText = "\(amount) (\(percent))"
      } else {
        deltaText = amount
      }
      basisText = basis(for: range, firstDate: first.date, locale: locale)
    }

    let asOfText: String? = isStale
      ? series.last.map { String(localized: "Prices as of \(dayText($0.date, locale: locale))") }
      : nil

    let historyCaption: String?
    if isStale || hasTrend || performance == nil {
      // Nil performance means it has not loaded (or failed): say nothing yet.
      historyCaption = nil
    } else if series.isEmpty {
      historyCaption = String(localized: "No history yet. Your first snapshot is taken tonight.")
    } else {
      historyCaption = String(localized: "Too little history for a trend yet.")
    }

    return PortfolioHeroModel(
      valueText: valueText,
      subtotalTexts: subtotalTexts,
      deltaText: deltaText,
      basisText: basisText,
      direction: direction,
      asOfText: asOfText,
      historyCaption: historyCaption,
      points: hasTrend ? series.map { ChartDataPoint(date: $0.date, value: $0.value) } : [],
      currencyCode: currencyCode
    )
  }

  /// The range Home asks the backend for, so its change label is known
  /// rather than inferred from the server's default.
  static let homeRange = PortfolioScreen.TimeRange.month

  /// Home's hero: the stored series for `homeRange`, falling back to the
  /// reports' live holdings total when the series is stale or empty. The
  /// reports carry no currency, so that total is labelled with the series'
  /// base currency.
  static func forHome(
    performance: PortfolioPerformanceResponse?,
    reportTotal: Double?,
    now: Date,
    locale: Locale
  ) -> PortfolioHeroModel {
    make(
      performance: performance,
      holdingsByCurrency: [:],
      range: homeRange,
      now: now,
      locale: locale,
      liveTotal: reportTotal
    )
  }

  /// Market value per currency, from the backend's per-symbol P/L. Holdings
  /// with no price (nil or 0) are left out: their value is unknown, not zero.
  static func holdingsByCurrency(_ pnls: [PnlBySymbol]) -> [String: Double] {
    pnls.reduce(into: [String: Double]()) { result, pnl in
      guard let price = pnl.currentPrice, price > 0,
            let code = MoneyFormatter.resolvedCode(pnl.currency) else { return }
      let shares = pnl.shares ?? 0
      let value = pnl.marketValue ?? (shares * price)
      result[code, default: 0] += value
    }
  }

  /// The words after a range change. Matches web `rangeBasis` (B2).
  static func basis(for range: PortfolioScreen.TimeRange, firstDate: Date, locale: Locale) -> String {
    switch range {
    case .week: String(localized: "1 week")
    case .month: String(localized: "1 month")
    case .threeMonths: String(localized: "3 months")
    case .year: String(localized: "1 year")
    case .day, .all: String(localized: "since \(dayText(firstDate, locale: locale))")
    }
  }

  // MARK: - Dates

  private struct Point {
    let date: Date
    let value: Double
  }

  private static var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
  }

  private static func parse(_ points: [PerformancePoint]) -> [Point] {
    let formatter = DateFormatter()
    formatter.calendar = utcCalendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = utcCalendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return points
      .compactMap { point in
        // Accept a full timestamp too; the day is the first ten characters.
        guard let date = formatter.date(from: String(point.date.prefix(10))) else { return nil }
        return Point(date: date, value: point.value)
      }
      .sorted { $0.date < $1.date }
  }

  private static func isOlderThanStaleLimit(_ date: Date, now: Date) -> Bool {
    let calendar = utcCalendar
    let days = calendar.dateComponents(
      [.day],
      from: calendar.startOfDay(for: date),
      to: calendar.startOfDay(for: now)
    ).day ?? 0
    return days > staleAfterDays
  }

  /// "11 Nov 2026" (en), "11/11/2026" never: a fixed day-month-year order.
  static func dayText(_ date: Date, locale: Locale) -> String {
    let formatter = DateFormatter()
    formatter.calendar = utcCalendar
    formatter.timeZone = utcCalendar.timeZone
    formatter.locale = locale
    formatter.dateFormat = "d MMM yyyy"
    return formatter.string(from: date)
  }
}
