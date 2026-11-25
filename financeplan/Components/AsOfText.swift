import SwiftUI

/// "As of 11 Nov 2026", or "Prices as of 11 Nov 2026" in the warning colour
/// when the data is more than four calendar days old.
struct AsOfText: View {
  let date: Date
  let now: Date
  let calendar: Calendar

  init(_ date: Date, now: Date = .now, calendar: Calendar = .current) {
    self.date = date
    self.now = now
    self.calendar = calendar
  }

  var body: some View {
    let label = AsOf.label(date, locale: MoneyFormatter.defaultLocale, calendar: calendar)
    if AsOf.isStale(date, now: now, calendar: calendar) {
      Text(verbatim: String(localized: "Prices as of \(label)"))
        .typography(.caption)
        .foregroundStyle(AppTheme.Colors.warning)
    } else {
      Text(verbatim: String(localized: "As of \(label)"))
        .typography(.caption)
        .foregroundStyle(AppTheme.Colors.secondaryText)
    }
  }
}
