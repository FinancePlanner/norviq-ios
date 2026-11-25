import XCTest
@testable import financeplan

/// The canonical money, change and "as of" text (DS 2.0 P2b).
final class CanonicalTextTests: XCTestCase {
  private let enUS = Locale(identifier: "en_US")
  private let ptPT = Locale(identifier: "pt_PT")

  private var auckland: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Pacific/Auckland") ?? .gmt
    return calendar
  }

  private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
    let components = DateComponents(year: y, month: m, day: d, hour: h, minute: min)
    return auckland.date(from: components) ?? .distantPast
  }

  // MARK: - AsOf

  func testFourCalendarDaysOldIsNotStale() {
    let last = date(2026, 11, 21, 23, 30)
    let now = date(2026, 11, 25, 8, 0)
    XCTAssertFalse(AsOf.isStale(last, now: now, calendar: auckland))
  }

  func testFiveCalendarDaysOldIsStale() {
    let last = date(2026, 11, 20, 23, 30)
    let now = date(2026, 11, 25, 8, 0)
    XCTAssertTrue(AsOf.isStale(last, now: now, calendar: auckland))
  }

  func testAsOfLabelIsDayMonthYear() {
    let day = date(2026, 11, 11, 12, 0)
    let label = AsOf.label(day, locale: enUS)
    XCTAssertTrue(label.contains("2026"))
    XCTAssertFalse(label.contains("/"))
    XCTAssertFalse(AsOf.label(day, locale: ptPT).isEmpty)
  }

  // MARK: - DeltaText

  func testNegativeChangeCarriesGlyphSignBasisAndWord() throws {
    let model = try XCTUnwrap(
      DeltaText.Model.make(fraction: -0.032, basis: "1 month", amount: nil, currencyCode: nil, locale: enUS)
    )
    XCTAssertEqual(model.text, "▼ \u{2212}3.2% 1 month")
    XCTAssertTrue(model.accessibilityLabel.contains("down"))
    XCTAssertEqual(model.tone, .loss)
  }

  func testPositiveChangeWithAmount() throws {
    let model = try XCTUnwrap(
      DeltaText.Model.make(fraction: 0.0321, basis: "1 year", amount: 120, currencyCode: "USD", locale: enUS)
    )
    XCTAssertEqual(model.glyph, "▲")
    XCTAssertEqual(model.tone, .gain)
    XCTAssertEqual(model.text, "▲ +3.2% · +$120.00 1 year")
  }

  func testRoundsToZeroIsFlat() throws {
    let model = try XCTUnwrap(
      DeltaText.Model.make(fraction: 0.00004, basis: "1 week", amount: nil, currencyCode: nil, locale: enUS)
    )
    XCTAssertEqual(model.tone, .flat)
    XCTAssertEqual(model.glyph, "–")
  }

  func testMissingFractionHasNoModel() {
    XCTAssertNil(DeltaText.Model.make(fraction: .nan, basis: nil, amount: nil, currencyCode: nil, locale: enUS))
    XCTAssertNil(DeltaText.Model.make(fraction: nil, basis: nil, amount: nil, currencyCode: nil, locale: enUS))
    XCTAssertNil(DeltaText.Model.make(fraction: .infinity, basis: nil, amount: nil, currencyCode: nil, locale: enUS))
  }

  // MARK: - MoneyText

  func testMissingCurrencyEndsInDashAndNeverDollar() {
    let text = MoneyText.text(1234.5, currencyCode: nil, signed: false, locale: enUS)
    XCTAssertTrue(text.hasSuffix(MoneyFormatter.missingCurrencySuffix), text)
    XCTAssertFalse(text.contains("$"))
  }

  func testMissingValueIsDash() {
    XCTAssertEqual(MoneyText.text(nil, currencyCode: "USD", signed: false, locale: enUS), "\u{2014}")
    XCTAssertEqual(MoneyText.text(.nan, currencyCode: "USD", signed: false, locale: enUS), "\u{2014}")
  }

  func testSignedMoney() {
    XCTAssertEqual(MoneyText.text(-168.78, currencyCode: "USD", signed: true, locale: enUS), "\u{2212}$168.78")
  }
}
