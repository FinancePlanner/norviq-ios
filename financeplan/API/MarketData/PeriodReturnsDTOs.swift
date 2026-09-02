import Foundation

// Local DTOs mirroring GET /v1/market/returns/{symbol} (backend
// PeriodReturnsDTOs). App-local to avoid a shared-package tag bump.
// Values are percent points: 12.5 means +12.5%.

nonisolated struct StockPeriodReturnsResponse: Codable, Equatable, Sendable {
  let symbol: String
  let threeMonth: Double?
  let sixMonth: Double?
  let yearToDate: Double?
  let asOf: String?

  var hasUsableWindows: Bool {
    threeMonth != nil || sixMonth != nil || yearToDate != nil
  }
}

nonisolated struct StockPeriodReturnsBatchResponse: Codable, Equatable, Sendable {
  let returns: [StockPeriodReturnsResponse]
}

enum PeriodReturnFormatting: Sendable {
  nonisolated static func percentText(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%+.1f%%", value)
  }

  nonisolated static func accessibilityLabel(period: String, value: Double?) -> String {
    let spoken: String
    switch period {
    case "3M": spoken = "3 month"
    case "6M": spoken = "6 month"
    case "YTD": spoken = "year to date"
    default: spoken = period
    }
    return "\(spoken) \(percentText(value))"
  }
}

nonisolated enum PeriodReturnsFromChart: Sendable {
  private static let maxStartSlip: TimeInterval = 10 * 24 * 60 * 60

  nonisolated static func derive(
    symbol: String,
    points: [PriceChartPoint],
    now: Date = Date(),
    calendar: Calendar? = nil
  ) -> StockPeriodReturnsResponse {
    let calendar = calendar ?? utcCalendar()

    let dated = points.compactMap { point -> (date: Date, close: Double)? in
      guard let date = parseDate(point.date, calendar: calendar), point.close > 0 else { return nil }
      return (date, point.close)
    }
    .sorted { $0.date < $1.date }

    guard let latest = dated.last else {
      return StockPeriodReturnsResponse(
        symbol: symbol,
        threeMonth: nil,
        sixMonth: nil,
        yearToDate: nil,
        asOf: nil
      )
    }

    let threeMonthStart = calendar.date(byAdding: .month, value: -3, to: now)
    let sixMonthStart = calendar.date(byAdding: .month, value: -6, to: now)
    var yearStartComponents = calendar.dateComponents([.year], from: now)
    yearStartComponents.month = 1
    yearStartComponents.day = 1
    let yearStart = calendar.date(from: yearStartComponents)

    return StockPeriodReturnsResponse(
      symbol: symbol,
      threeMonth: percentReturn(from: threeMonthStart, latest: latest, in: dated),
      sixMonth: percentReturn(from: sixMonthStart, latest: latest, in: dated),
      yearToDate: percentReturn(from: yearStart, latest: latest, in: dated),
      asOf: dayString(from: latest.date, calendar: calendar)
    )
  }

  private nonisolated static func percentReturn(
    from start: Date?,
    latest: (date: Date, close: Double),
    in dated: [(date: Date, close: Double)]
  ) -> Double? {
    guard let start, latest.close > 0 else { return nil }
    guard let startClose = close(onOrNear: start, in: dated), startClose > 0 else { return nil }
    guard latest.date > start else { return nil }
    return (latest.close - startClose) / startClose * 100
  }

  private nonisolated static func close(
    onOrNear start: Date,
    in dated: [(date: Date, close: Double)]
  ) -> Double? {
    let candidates = [
      dated.last(where: { $0.date <= start }),
      dated.first(where: { $0.date >= start }),
    ]
    .compactMap { $0 }
    .map { (distance: abs($0.date.timeIntervalSince(start)), close: $0.close) }
    .filter { $0.distance <= maxStartSlip }

    return candidates.min(by: { $0.distance < $1.distance })?.close
  }

  private nonisolated static func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
  }

  private nonisolated static func parseDate(_ raw: String, calendar: Calendar) -> Date? {
    let day = raw.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? raw
    let parts = day.split(separator: "-")
    guard parts.count >= 3,
          let year = Int(parts[0]),
          let month = Int(parts[1]),
          let dayValue = Int(parts[2])
    else { return nil }
    return calendar.date(from: DateComponents(year: year, month: month, day: dayValue))
  }

  private nonisolated static func dayString(from date: Date, calendar: Calendar) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    let year = components.year ?? 0
    let month = components.month ?? 0
    let day = components.day ?? 0
    return String(format: "%04d-%02d-%02d", year, month, day)
  }
}
