import Foundation
import SwiftUI

/// Finds `$AAPL`-style cashtags in a message so they render as tappable
/// tickers. A tag starts with a letter, so `$100` stays money; a trailing
/// dot or dash (end of a sentence) isn't part of it.
nonisolated enum TickerChipParser {
  enum Segment: Equatable, Sendable {
    case text(String)
    case ticker(String)
  }

  static let maxLength = 12
  private static let urlScheme = "norviq-ticker"

  static func segments(in text: String) -> [Segment] {
    var segments: [Segment] = []
    var buffer = ""
    var index = text.startIndex
    var previous: Character?

    while index < text.endIndex {
      let character = text[index]
      if character == "$", previous.map({ !$0.isLetter && !$0.isNumber && $0 != "$" }) ?? true,
         let (symbol, end) = ticker(in: text, after: index) {
        if !buffer.isEmpty {
          segments.append(.text(buffer))
          buffer = ""
        }
        segments.append(.ticker(symbol))
        previous = text[text.index(before: end)]
        index = end
        continue
      }
      buffer.append(character)
      previous = character
      index = text.index(after: index)
    }
    if !buffer.isEmpty { segments.append(.text(buffer)) }
    return segments
  }

  static func tickers(in text: String) -> [String] {
    segments(in: text).compactMap {
      if case let .ticker(symbol) = $0 { return symbol }
      return nil
    }
  }

  /// The tag after the `$` at `dollar`, uppercased, and where it ends.
  private static func ticker(in text: String, after dollar: String.Index) -> (String, String.Index)? {
    var end = text.index(after: dollar)
    guard end < text.endIndex, text[end].isASCII, text[end].isLetter else { return nil }
    while end < text.endIndex, text[end].isASCII,
          text[end].isLetter || text[end].isNumber || text[end] == "." || text[end] == "-" {
      end = text.index(after: end)
    }
    // "$AAPL." ends a sentence; "$BRK.B" keeps its class.
    while let last = text[text.index(after: dollar) ..< end].last, last == "." || last == "-" {
      end = text.index(before: end)
    }
    let symbol = String(text[text.index(after: dollar) ..< end])
    // Part of a longer word ("$AAPLxyz…" past the limit) isn't a ticker.
    guard symbol.count <= maxLength else { return nil }
    if end < text.endIndex, text[end].isLetter || text[end].isNumber { return nil }
    return (symbol.uppercased(), end)
  }

  /// The message as one `Text`-ready string with each ticker a link the chat
  /// screen intercepts.
  static func attributed(_ text: String, tint: Color) -> AttributedString {
    var result = AttributedString()
    for segment in segments(in: text) {
      switch segment {
      case let .text(plain):
        result.append(AttributedString(plain))
      case let .ticker(symbol):
        var chip = AttributedString("$\(symbol)")
        chip.link = url(for: symbol)
        chip.foregroundColor = tint
        chip.inlinePresentationIntent = .stronglyEmphasized
        result.append(chip)
      }
    }
    return result
  }

  static func url(for symbol: String) -> URL? {
    URL(string: "\(urlScheme):\(symbol)")
  }

  static func symbol(from url: URL) -> String? {
    guard url.scheme == urlScheme else { return nil }
    let symbol = url.absoluteString.dropFirst(urlScheme.count + 1)
    return symbol.isEmpty ? nil : String(symbol)
  }
}
