import Foundation

/// The unit menu next to a big-number field: share counts and market caps run
/// to billions and trillions, which nobody should type out in full.
enum TerminalUnit: String, CaseIterable, Identifiable {
  case none, thousand, million, billion, trillion

  var id: String {
    rawValue
  }

  var multiplier: Double {
    switch self {
    case .none: 1
    case .thousand: 1_000
    case .million: 1_000_000
    case .billion: 1_000_000_000
    case .trillion: 1_000_000_000_000
    }
  }

  /// Menu label. The same suffixes as the web table's compact numbers (10T, 1.25B).
  var symbol: String {
    switch self {
    case .none: "—"
    case .thousand: "K"
    case .million: "M"
    case .billion: "B"
    case .trillion: "T"
    }
  }
}

/// What the user typed into one number field, plus its unit.
struct TerminalNumberInput: Equatable {
  enum Reading: Equatable {
    case empty
    case invalid
    /// `MoneyInputParser` drops a minus sign, so "-100" would read as 100.
    /// It is reported here instead of being flipped.
    case negative
    case value(Double)
  }

  var text: String
  var unit: TerminalUnit

  init(text: String = "", unit: TerminalUnit = .none) {
    self.text = text
    self.unit = unit
  }

  /// Prefills a field from a stored number. With `usesUnits`, it picks the
  /// largest unit whose text reads back to exactly `value`. That way, opening
  /// a row and saving it never nudges a number.
  init(value: Double?, usesUnits: Bool = true, locale: Locale = .current) {
    guard let value, value.isFinite else {
      self.init()
      return
    }
    let candidates: [TerminalUnit] = usesUnits ? TerminalUnit.allCases.reversed() : [.none]
    for unit in candidates where unit == .none || abs(value) >= unit.multiplier {
      let candidate = TerminalNumberInput(text: Self.format(value / unit.multiplier, locale: locale), unit: unit)
      if case let .value(read) = candidate.reading(locale: locale), read == value {
        self = candidate
        return
      }
    }
    self.init(text: Self.format(value, locale: locale), unit: .none)
  }

  func reading(locale: Locale = .current) -> Reading {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return .empty }
    if trimmed.contains("-") || trimmed.contains("\u{2212}") {
      return .negative
    }
    guard let parsed = MoneyInputParser.parse(trimmed, locale: locale), parsed.isFinite else { return .invalid }
    return .value(parsed * unit.multiplier)
  }

  func value(locale: Locale = .current) -> Double? {
    if case let .value(value) = reading(locale: locale) {
      return value
    }
    return nil
  }

  private static func format(_ value: Double, locale: Locale) -> String {
    value.formatted(.number.precision(.fractionLength(0...6)).grouping(.never).locale(locale))
  }
}
