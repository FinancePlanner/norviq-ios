import Foundation

enum MoneyInputParser {
  static func parse(_ raw: String) -> Double? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let filtered = trimmed.filter { $0.isNumber || $0 == "," || $0 == "." }
    guard !filtered.isEmpty else { return nil }

    let characters = Array(filtered)
    let separatorIndexes = characters.indices.filter { characters[$0] == "," || characters[$0] == "." }

    if separatorIndexes.isEmpty {
      return Double(filtered)
    }

    if separatorIndexes.count == 1 {
      let separatorIndex = separatorIndexes[0]
      let leadingDigits = separatorIndex
      let trailingDigits = characters.count - separatorIndex - 1
      if leadingDigits > 0 && trailingDigits == 3 {
        let normalized = filtered
          .replacingOccurrences(of: ",", with: "")
          .replacingOccurrences(of: ".", with: "")
        return Double(normalized)
      }
    }

    let decimalSeparator = characters[separatorIndexes.last!]
    var normalized = ""
    var consumedDecimal = false

    for character in characters {
      if character.isNumber {
        normalized.append(character)
        continue
      }

      if (character == "," || character == ".")
        && character == decimalSeparator
        && !consumedDecimal {
        normalized.append(".")
        consumedDecimal = true
      }
    }

    guard normalized != "." else { return nil }
    return Double(normalized)
  }
}
