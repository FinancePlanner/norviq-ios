import Foundation

enum MoneyInputParser {
  /// Reads a number the way the person typing it meant it.
  ///
  /// A lone separator is ambiguous on digit count alone: "4,123" is a price
  /// with three decimals to someone on a Portuguese keypad and four thousand
  /// to someone on a US one. The locale settles it — a separator that matches
  /// the locale's decimal mark is a decimal mark, whatever follows it.
  static func parse(_ raw: String, locale: Locale = .current) -> Double? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let filtered = trimmed.filter { $0.isNumber || $0 == "," || $0 == "." }
    guard !filtered.isEmpty else { return nil }
    guard filtered.contains(where: \.isNumber) else { return nil }

    let characters = Array(filtered)
    let separatorIndexes = characters.indices.filter { characters[$0] == "," || characters[$0] == "." }

    if separatorIndexes.isEmpty {
      return Double(filtered)
    }

    let decimalMark = locale.decimalSeparator.flatMap(\.first)
    let groupingMark = locale.groupingSeparator.flatMap(\.first)
    let distinctSeparators = Set(separatorIndexes.map { characters[$0] })

    // One separator, used once: the only genuinely ambiguous case.
    if distinctSeparators.count == 1, separatorIndexes.count == 1 {
      let separator = characters[separatorIndexes[0]]
      let leadingDigits = separatorIndexes[0]
      let trailingDigits = characters.count - separatorIndexes[0] - 1

      let isGrouping: Bool = if separator == decimalMark {
        false // The locale's own decimal mark is never grouping.
      } else if separator == groupingMark {
        leadingDigits > 0 && trailingDigits == 3
      } else {
        leadingDigits > 0 && trailingDigits == 3
      }

      if isGrouping {
        return Double(characters.filter(\.isNumber).map(String.init).joined())
      }
      return decimalValue(characters, decimalIndex: separatorIndexes[0])
    }

    // Several separators: the last one is the decimal mark, the rest group.
    return decimalValue(characters, decimalIndex: separatorIndexes.last!)
  }

  private static func decimalValue(_ characters: [Character], decimalIndex: Int) -> Double? {
    var normalized = ""
    for (index, character) in characters.enumerated() {
      if character.isNumber {
        normalized.append(character)
      } else if index == decimalIndex {
        normalized.append(".")
      }
    }
    guard normalized != ".", !normalized.isEmpty else { return nil }
    return Double(normalized)
  }
}
