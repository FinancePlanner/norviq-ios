import Foundation

/// When a series is too old to carry a change, and how its date reads.
///
/// One rule for every screen: a last point more than four calendar days old
/// hides the change and shows "Prices as of {date}" instead.
nonisolated enum AsOf {
  /// A series whose last point is older than this many calendar days is stale.
  static let staleAfterDays = 4

  /// Calendar days from `last` to `now` (each taken at start of day) beyond the limit.
  static func isStale(_ last: Date, now: Date, calendar: Calendar = .current) -> Bool {
    let days = calendar.dateComponents(
      [.day],
      from: calendar.startOfDay(for: last),
      to: calendar.startOfDay(for: now)
    ).day ?? 0
    return days > staleAfterDays
  }

  /// "11 Nov 2026" (en), in the locale's own order and month names.
  static func label(_ date: Date, locale: Locale) -> String {
    var style = Date.FormatStyle(date: .abbreviated)
    style.locale = locale
    return MoneyFormatter.normalise(date.formatted(style))
  }
}
