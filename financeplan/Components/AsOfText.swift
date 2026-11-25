import SwiftUI

/// "As of 11 Nov 2026", or "Prices as of 11 Nov 2026" in the warning colour
/// when the data is more than four calendar days old.
struct AsOfText: View {
  let date: Date
  let now: Date

  init(_ date: Date, now: Date = .now) {
    self.date = date
    self.now = now
  }

  var body: some View {
    let label = AsOf.label(date, locale: MoneyFormatter.defaultLocale)
    if AsOf.isStale(date, now: now) {
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
