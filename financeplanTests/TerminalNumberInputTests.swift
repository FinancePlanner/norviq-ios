import Foundation
import XCTest
@testable import financeplan

@MainActor
final class TerminalNumberInputTests: XCTestCase {
  private let english = Locale(identifier: "en_US")
  private let portuguese = Locale(identifier: "pt_PT")

  func testUnitMultipliesTheTypedValue() async {
    XCTAssertEqual(TerminalNumberInput(text: "11", unit: .billion).value(locale: english), 11_000_000_000)
    XCTAssertEqual(TerminalNumberInput(text: "10", unit: .trillion).value(locale: english), 10_000_000_000_000)
    XCTAssertEqual(TerminalNumberInput(text: "250", unit: .thousand).value(locale: english), 250_000)
    XCTAssertEqual(TerminalNumberInput(text: "1100").value(locale: english), 1_100)
  }

  func testPortugueseCommaIsADecimalMark() async {
    XCTAssertEqual(TerminalNumberInput(text: "1,5", unit: .billion).value(locale: portuguese), 1_500_000_000)
    XCTAssertEqual(TerminalNumberInput(text: "2,75", unit: .million).value(locale: portuguese), 2_750_000)
    XCTAssertEqual(TerminalNumberInput(text: "1,500").value(locale: english), 1_500)
  }

  func testMinusSignIsRefusedNotDropped() async {
    XCTAssertEqual(TerminalNumberInput(text: "-100").reading(locale: english), .negative)
    XCTAssertEqual(TerminalNumberInput(text: "\u{2212}100", unit: .million).reading(locale: english), .negative)
    XCTAssertNil(TerminalNumberInput(text: "-100").value(locale: english))
  }

  func testEmptyAndUnreadableText() async {
    XCTAssertEqual(TerminalNumberInput(text: "   ").reading(locale: english), .empty)
    XCTAssertEqual(TerminalNumberInput(text: "abc").reading(locale: english), .invalid)
  }

  func testPrefillPicksTheLargestUnitThatReadsBackExactly() async {
    XCTAssertEqual(
      TerminalNumberInput(value: 11_000_000_000, locale: english),
      TerminalNumberInput(text: "11", unit: .billion)
    )
    XCTAssertEqual(
      TerminalNumberInput(value: 10_000_000_000_000, locale: english),
      TerminalNumberInput(text: "10", unit: .trillion)
    )
    XCTAssertEqual(
      TerminalNumberInput(value: 1_500_000_000, locale: portuguese),
      TerminalNumberInput(text: "1,5", unit: .billion)
    )
    XCTAssertEqual(
      TerminalNumberInput(value: 220.5, usesUnits: false, locale: english),
      TerminalNumberInput(text: "220.5")
    )
    XCTAssertEqual(
      TerminalNumberInput(value: 4_500, usesUnits: false, locale: english),
      TerminalNumberInput(text: "4500")
    )
    XCTAssertEqual(TerminalNumberInput(value: nil, locale: english), TerminalNumberInput())
  }

  func testPrefillNeverChangesTheStoredNumber() async {
    for locale in [english, portuguese] {
      for value in [1_234_567.891, 909.090909, 62.5, 2_916.67, 10_600_000_000, 0.000001, 1_100] {
        XCTAssertEqual(
          TerminalNumberInput(value: value, locale: locale).value(locale: locale),
          value,
          "\(value) in \(locale.identifier)"
        )
      }
    }
  }

  func testDisplayFormats() async {
    XCTAssertEqual(
      TerminalFormat.price(10_000_000_000_000 / 11_000_000_000, currency: "USD", locale: english),
      "$909.09"
    )
    XCTAssertEqual(TerminalFormat.shares(1_099.6, roundDown: false, locale: english), "1,099.6")
    XCTAssertEqual(TerminalFormat.shares(1_099.6, roundDown: true, locale: english), "1,099")
    XCTAssertEqual(TerminalFormat.progress(750.0 / 1_100.0, locale: english), "68.18%")
    XCTAssertEqual(TerminalFormat.money(1_000_000, currency: "USD", locale: english), "$1.0M")
    XCTAssertEqual(TerminalFormat.money(10_000_000_000_000, currency: "USD", locale: english), "$10.00T")
  }
}
