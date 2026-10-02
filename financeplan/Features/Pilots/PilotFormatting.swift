import Foundation
import StockPlanShared

struct PilotValuePoint: Identifiable, Equatable {
  let date: Date
  let value: Double
  var id: Date { date }
}

/// Display text for pilots. Pure, so the copy is pinned by tests. Functions
/// that format take a locale (and a time zone for instants) so tests do not
/// depend on the simulator's settings.
enum PilotFormatting {
  // MARK: - Dates

  /// Strict `yyyy-MM-dd` at UTC midnight. (A `DateFormatter` is lenient and
  /// would also accept "2026/09/14".)
  private static let dayParser = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()

  /// Disclosure and snapshot days are UTC calendar days (`yyyy-MM-dd`).
  static func day(_ raw: String) -> Date? {
    try? Date(raw, strategy: dayParser)
  }

  static func instant(_ raw: String) -> Date? {
    try? Date(raw, strategy: .iso8601)
  }

  /// A reported day such as "Sep 14, 2026". Formatted in UTC so it is never
  /// shown a day early west of Greenwich.
  static func dayText(_ raw: String, locale: Locale = .current) -> String {
    guard let date = day(raw) else { return raw }
    return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, timeZone: .gmt))
  }

  static func instantText(_ raw: String, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
    guard let date = instant(raw) else { return raw }
    return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, timeZone: timeZone))
  }

  // MARK: - Numbers

  static func weight(_ value: Double, locale: Locale = .current) -> String {
    value.formatted(.percent.precision(.fractionLength(1)).locale(locale))
  }

  static func money(_ value: Double, currency: String, wholeUnits: Bool = false, locale: Locale = .current) -> String {
    let style = FloatingPointFormatStyle<Double>.Currency(code: currency, locale: locale)
    return wholeUnits ? value.formatted(style.precision(.fractionLength(0))) : value.formatted(style)
  }

  static func signedPercent(_ fraction: Double, locale: Locale = .current) -> String {
    let magnitude = abs(fraction).formatted(.percent.precision(.fractionLength(1)).locale(locale))
    return fraction < 0 ? "-\(magnitude)" : "+\(magnitude)"
  }

  /// Latest simulated value against the starting capital, as a fraction.
  static func performance(start: Double?, latest: Double?) -> Double? {
    guard let start, start > 0, let latest else { return nil }
    return latest / start - 1
  }

  static func valuePoints(_ snapshots: [PilotFollowSnapshotResponse]) -> [PilotValuePoint] {
    snapshots
      .compactMap { snapshot in day(snapshot.date).map { PilotValuePoint(date: $0, value: snapshot.value) } }
      .sorted { $0.date < $1.date }
  }

  // MARK: - Pilots

  static func kindLabel(_ pilot: PilotSummary) -> String {
    switch pilot.kind {
    case .politician:
      switch pilot.chamber?.lowercased() {
      case "senate": return String(localized: "Senator")
      case "house": return String(localized: "Representative")
      default: return String(localized: "Member of Congress")
      }
    case .fund:
      return String(localized: "13F fund")
    }
  }

  static func subtitle(for pilot: PilotSummary) -> String {
    let holdings: String
    switch pilot.holdingsCount {
    case 0: holdings = String(localized: "No trades seen yet")
    case 1: holdings = String(localized: "1 holding")
    default: holdings = String(localized: "\(pilot.holdingsCount) holdings")
    }
    return "\(kindLabel(pilot)) · \(holdings)"
  }

  static func skippedPutsNote(_ count: Int) -> String? {
    switch count {
    case ...0: return nil
    case 1: return String(localized: "1 put trade wasn't mirrored: a simulated portfolio can't go short.")
    default: return String(localized: "\(count) put trades weren't mirrored: a simulated portfolio can't go short.")
    }
  }

  static func isSkippedPut(_ item: PilotDisclosureItem) -> Bool {
    item.instrument == "put"
  }

  static func disclosureTitle(_ item: PilotDisclosureItem) -> String {
    let verb: String
    switch item.side {
    case "buy": verb = String(localized: "Bought")
    case "sell": verb = String(localized: "Sold part of")
    case "sell_full": verb = String(localized: "Sold all")
    case "hold": verb = String(localized: "Holds")
    default: verb = item.side.replacingOccurrences(of: "_", with: " ").capitalized
    }
    switch item.instrument {
    case "call": return "\(verb) \(item.symbol) " + String(localized: "calls")
    case "put": return "\(verb) \(item.symbol) " + String(localized: "puts")
    default: return "\(verb) \(item.symbol)"
    }
  }

  static func amountRange(min: Double?, max: Double?, locale: Locale = .current) -> String? {
    let format = { (value: Double) in money(value, currency: "USD", wholeUnits: true, locale: locale) }
    if let min, let max {
      return max > min ? "\(format(min))–\(format(max))" : format(min)
    }
    if let min { return String(localized: "Over \(format(min))") }
    if let max { return String(localized: "Up to \(format(max))") }
    return nil
  }

  static func disclosureDetail(_ item: PilotDisclosureItem, locale: Locale = .current) -> String? {
    var parts: [String] = []
    if let amount = amountRange(min: item.amountMin, max: item.amountMax, locale: locale) { parts.append(amount) }
    if let traded = item.transactionDate { parts.append(String(localized: "traded \(dayText(traded, locale: locale))")) }
    if let disclosed = item.disclosureDate { parts.append(String(localized: "disclosed \(dayText(disclosed, locale: locale))")) }
    if let period = item.period { parts.append(String(localized: "13F period \(period)")) }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  // MARK: - Follows

  static func followSubtitle(_ follow: PilotFollowResponse, locale: Locale = .current) -> String {
    switch follow.targetKind {
    case .portfolio:
      guard let capital = follow.startingCapital else { return String(localized: "Simulated portfolio") }
      let amount = money(capital, currency: follow.currency, wholeUnits: true, locale: locale)
      return String(localized: "Simulated portfolio · started with \(amount)")
    case .watchlist:
      return String(localized: "Watchlist feed")
    }
  }

  static func eventTitle(_ event: PilotFollowEventResponse, locale: Locale = .current) -> String {
    let quantity = event.quantity.map { $0.formatted(.number.precision(.fractionLength(0...4)).locale(locale)) }
    switch event.kind {
    case "buy":
      return quantity.map { String(localized: "Bought \($0) \(event.symbol)") } ?? String(localized: "Bought \(event.symbol)")
    case "sell":
      return quantity.map { String(localized: "Sold \($0) \(event.symbol)") } ?? String(localized: "Sold \(event.symbol)")
    case "watch_added":
      return String(localized: "Added \(event.symbol) to the watchlist")
    case "watch_exited":
      return String(localized: "Marked \(event.symbol) as exited")
    case "skipped_unpriced":
      return String(localized: "Skipped \(event.symbol): no price available")
    case "skipped_limit":
      return String(localized: "Skipped \(event.symbol): watchlist is full")
    default:
      return "\(event.kind.replacingOccurrences(of: "_", with: " ").capitalized) \(event.symbol)"
    }
  }

  static func eventDetail(
    _ event: PilotFollowEventResponse,
    currency: String,
    locale: Locale = .current,
    timeZone: TimeZone = .current
  ) -> String {
    let day = instantText(event.pricedAt, locale: locale, timeZone: timeZone)
    guard let price = event.price else { return day }
    return String(localized: "at \(money(price, currency: currency, locale: locale)) · \(day)")
  }

  static func eventSymbolName(_ kind: String) -> String {
    switch kind {
    case "buy": return "plus.circle.fill"
    case "sell": return "minus.circle.fill"
    case "watch_added": return "eye"
    case "watch_exited": return "eye.slash"
    case "skipped_unpriced", "skipped_limit": return "exclamationmark.triangle"
    default: return "circle"
    }
  }
}
