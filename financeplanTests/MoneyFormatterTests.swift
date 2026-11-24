import Foundation
import XCTest
@testable import financeplan

/// The money contract (spec § 5.4), proven against the golden fixtures that
/// web and Android also run. `Fixtures/money.json` is a byte-for-byte copy of
/// `docs/design-system-fixtures/money.json`; never edit it here.
final class MoneyFormatterTests: XCTestCase {
  private let unitedStates = Locale(identifier: "en_US")
  private let portugal = Locale(identifier: "pt_PT")

  private struct Fixtures: Decodable {
    let version: String
    let cases: [Case]
  }

  private struct Case: Decodable, CustomStringConvertible {
    let kind: String
    let style: String
    let value: Double
    let currency: String?
    let locale: String
    let platforms: [String]
    let expected: String

    var description: String {
      "\(kind)/\(style) \(value) \(currency ?? "nil") \(locale)"
    }
  }

  private func loadFixtures() throws -> Fixtures {
    let bundle = Bundle(for: MoneyFormatterTests.self)
    let url = try XCTUnwrap(
      bundle.url(forResource: "money", withExtension: "json")
        ?? bundle.url(forResource: "money", withExtension: "json", subdirectory: "Fixtures"),
      "Fixtures/money.json is missing from the test bundle"
    )
    return try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
  }

  private func locale(for tag: String) -> Locale {
    switch tag {
    case "en-US": unitedStates
    case "pt-PT": portugal
    default: Locale(identifier: tag.replacingOccurrences(of: "-", with: "_"))
    }
  }

  /// Spells out every non-ASCII scalar so a failure shows whether the gap is
  /// whitespace, the minus sign or the symbol itself.
  private func scalars(_ s: String) -> String {
    s.unicodeScalars
      .map { $0.isASCII ? String($0) : String(format: "<U+%04X>", $0.value) }
      .joined()
  }

  private func format(_ fixture: Case) -> String? {
    let locale = locale(for: fixture.locale)
    switch (fixture.kind, fixture.style) {
    case ("money", "standard"):
      return MoneyFormatter.string(fixture.value, currencyCode: fixture.currency, locale: locale)
    case ("money", "signed"):
      return MoneyFormatter.signed(fixture.value, currencyCode: fixture.currency, locale: locale)
    case ("percent", "signed1"):
      return MoneyFormatter.percentSigned(fixture.value, locale: locale)
    default:
      return nil
    }
  }

  func testFixtures() throws {
    let fixtures = try loadFixtures()
    XCTAssertEqual(fixtures.version, "2026-11-24")
    let iosCases = fixtures.cases.filter { $0.platforms.contains("ios") }
    XCTAssertFalse(iosCases.isEmpty)
    for fixture in iosCases {
      let output = try XCTUnwrap(format(fixture), "No iOS formatter for \(fixture)")
      XCTAssertEqual(
        output,
        fixture.expected,
        "\(fixture): got \(scalars(output)), expected \(scalars(fixture.expected))"
      )
    }
  }

  func testMissingCurrencyNeverPrintsDollar() {
    XCTAssertEqual(
      MoneyFormatter.string(1234, currencyCode: nil, locale: unitedStates),
      "1,234.00\u{00A0}—"
    )
  }

  func testBlankCurrencyIsTreatedAsMissing() {
    XCTAssertEqual(
      MoneyFormatter.string(48432.05, currencyCode: "  ", locale: portugal),
      "48\u{00A0}432,05\u{00A0}—"
    )
    XCTAssertEqual(
      MoneyFormatter.signed(-5, currencyCode: "", locale: unitedStates),
      "\u{2212}5.00\u{00A0}—"
    )
  }

  func testNormaliseReplacesNarrowSpacesAndHyphens() {
    XCTAssertEqual(
      MoneyFormatter.normalise("-1\u{202F}234\u{2009}€"),
      "\u{2212}1\u{00A0}234\u{00A0}€"
    )
  }

  func testDefaultLocaleFollowsTheAppLanguageNotTheRegion() {
    XCTAssertEqual(MoneyFormatter.locale(for: .english).identifier, "en_US")
    XCTAssertEqual(MoneyFormatter.locale(for: .portuguesePortugal).identifier, "pt_PT")
  }
}
