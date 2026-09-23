import Foundation
import XCTest
@testable import financeplan

/// The separator a user types is only meaningful next to their locale: "4,123"
/// is four-and-a-bit in Lisbon and four thousand in Chicago. These pin both
/// readings rather than guessing from the digit count.
@MainActor
final class MoneyInputParserTests: XCTestCase {
  private let portugal = Locale(identifier: "pt_PT")
  private let unitedStates = Locale(identifier: "en_US")

  func testThreeDecimalsAreDecimalsWhenTheSeparatorIsTheLocaleDecimalSeparator() {
    XCTAssertEqual(MoneyInputParser.parse("4,123", locale: portugal), 4.123)
    XCTAssertEqual(MoneyInputParser.parse("4.123", locale: unitedStates), 4.123)
  }

  func testThreeDigitsAfterTheGroupingSeparatorAreThousands() {
    XCTAssertEqual(MoneyInputParser.parse("1.234", locale: portugal), 1234)
    XCTAssertEqual(MoneyInputParser.parse("1,234", locale: unitedStates), 1234)
  }

  func testBothSeparatorsTogetherReadAsGroupingThenDecimal() {
    XCTAssertEqual(MoneyInputParser.parse("1.234,56", locale: portugal), 1234.56)
    XCTAssertEqual(MoneyInputParser.parse("1,234.56", locale: unitedStates), 1234.56)
  }

  func testTwoDecimalsStayDecimalsInEitherLocale() {
    XCTAssertEqual(MoneyInputParser.parse("4,12", locale: portugal), 4.12)
    XCTAssertEqual(MoneyInputParser.parse("4.12", locale: unitedStates), 4.12)
  }

  func testPlainIntegersParse() {
    XCTAssertEqual(MoneyInputParser.parse("4", locale: portugal), 4)
    XCTAssertEqual(MoneyInputParser.parse("4", locale: unitedStates), 4)
  }

  func testJunkIsRejected() {
    XCTAssertNil(MoneyInputParser.parse("", locale: portugal))
    XCTAssertNil(MoneyInputParser.parse("   ", locale: portugal))
    XCTAssertNil(MoneyInputParser.parse(",", locale: portugal))
    XCTAssertNil(MoneyInputParser.parse("abc", locale: portugal))
  }
}
