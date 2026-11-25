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

  /// "11 Nov 2026" (en), "11 nov. 2026" (pt-PT): day, abbreviated month, year,
  /// always in that order. The day is read in `calendar`'s time zone, the same
  /// one `isStale` counts days in, so the two never disagree.
  static func label(_ date: Date, locale: Locale, calendar: Calendar = .current) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = locale
    formatter.dateFormat = "d MMM yyyy"
    return MoneyFormatter.normalise(formatter.string(from: date))
  }
}
