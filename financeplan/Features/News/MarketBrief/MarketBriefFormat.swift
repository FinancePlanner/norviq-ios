import Foundation
import StockPlanShared

/// Dates and source names for the brief card. Pure, so it is unit-tested.
nonisolated enum MarketBriefFormat {
  /// Trading dates are Lisbon calendar days.
  static let tradingTimeZone = TimeZone(identifier: "Europe/Lisbon") ?? .gmt

  /// `2026-10-15` → a date at Lisbon midnight, or nil when malformed.
  static func tradingDate(_ raw: String?) -> Date? {
    guard let raw, MarketBriefDeepLink.isTradingDate(raw) else { return nil }
    let parts = raw.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = tradingTimeZone
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
  }

  /// "Thu, 15 Oct" in the brief's language.
  static func tradingDateLabel(_ raw: String?, language: String) -> String? {
    guard let date = tradingDate(raw) else { return nil }
    var style = Date.FormatStyle(timeZone: tradingTimeZone)
      .weekday(.abbreviated)
      .day()
      .month(.abbreviated)
    style.locale = Locale(identifier: language)
    return date.formatted(style)
  }

  /// ISO 8601, with or without fractional seconds.
  static func generatedAt(_ raw: String?) -> Date? {
    guard let raw, !raw.isEmpty else { return nil }
    if let date = try? Date(raw, strategy: .iso8601) { return date }
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: raw)
  }

  /// "08:16" in the reader's time zone and the brief's language.
  static func generatedTimeLabel(_ raw: String?, language: String, timeZone: TimeZone = .current) -> String? {
    guard let date = generatedAt(raw) else { return nil }
    var style = Date.FormatStyle(timeZone: timeZone).hour().minute()
    style.locale = Locale(identifier: language)
    return date.formatted(style)
  }

  /// `https://www.reuters.com/markets/…` → `reuters.com`. Attribution only;
  /// the card never links out.
  static func sourceHost(_ raw: String?) -> String? {
    guard let raw, let host = URL(string: raw)?.host(), !host.isEmpty else { return nil }
    let lowered = host.lowercased()
    return lowered.hasPrefix("www.") ? String(lowered.dropFirst(4)) : lowered
  }
}
