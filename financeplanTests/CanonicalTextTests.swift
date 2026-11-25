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

  private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }

  func testAsOfLabelIsDayMonthYear() {
    var parts = DateComponents(year: 2026, month: 11, day: 21, hour: 0, minute: 0)
    parts.timeZone = .gmt
    let utcMidnight = utc.date(from: parts) ?? .distantPast
    XCTAssertEqual(AsOf.label(utcMidnight, locale: enUS, calendar: utc), "21 Nov 2026")
    XCTAssertEqual(AsOf.label(utcMidnight, locale: ptPT, calendar: utc), "21 nov. 2026")
    // 21 Nov 00:00 UTC is already the 21st at 13:00 in Auckland, and the 20th in UTC-5.
    XCTAssertEqual(AsOf.label(utcMidnight, locale: enUS, calendar: auckland), "21 Nov 2026")
    var west = Calendar(identifier: .gregorian)
    west.timeZone = TimeZone(secondsFromGMT: -5 * 3600) ?? .gmt
    XCTAssertEqual(AsOf.label(utcMidnight, locale: enUS, calendar: west), "20 Nov 2026")
  }

  // MARK: - DeltaText

  func testNegativeChangeCarriesGlyphSignBasisAndWord() throws {
    let model = try XCTUnwrap(
      DeltaText.Model.make(fraction: -0.032, basis: "1 month", amount: nil, currencyCode: nil, locale: enUS)
    )
    XCTAssertEqual(model.text, "▼ \u{2212}3.2% 1 month")
    XCTAssertEqual(model.accessibilityLabel, "down \u{2212}3.2% 1 month")
    XCTAssertEqual(model.tone, .loss)
  }

  func testPositiveChangeWithAmount() throws {
    let model = try XCTUnwrap(
      DeltaText.Model.make(fraction: 0.0321, basis: "1 year", amount: 120, currencyCode: "USD", locale: enUS)
    )
    XCTAssertEqual(model.glyph, "▲")
    XCTAssertEqual(model.tone, .gain)
    XCTAssertEqual(model.text, "▲ +3.2% · +$120.00 1 year")
    XCTAssertEqual(model.accessibilityLabel, "up +3.2% · +$120.00 1 year")
  }

  func testRoundsToZeroIsFlat() throws {
    let model = try XCTUnwrap(
      DeltaText.Model.make(fraction: 0.00004, basis: "1 week", amount: nil, currencyCode: nil, locale: enUS)
    )
    XCTAssertEqual(model.tone, .flat)
    XCTAssertEqual(model.glyph, "–")
  }

  func testNegativeRoundsToZeroIsFlatAndUnchanged() throws {
    let model = try XCTUnwrap(
      DeltaText.Model.make(fraction: -0.00004, basis: "", amount: nil, currencyCode: nil, locale: enUS)
    )
    XCTAssertEqual(model.tone, .flat)
    XCTAssertEqual(model.glyph, "\u{2013}")
    XCTAssertEqual(model.accessibilityLabel, "unchanged 0.0%")
    XCTAssertEqual(model.text, "\u{2013} 0.0%")
  }

  func testMissingFractionHasNoModel() {
    XCTAssertNil(DeltaText.Model.make(fraction: .nan, basis: "", amount: nil, currencyCode: nil, locale: enUS))
    XCTAssertNil(DeltaText.Model.make(fraction: nil, basis: "", amount: nil, currencyCode: nil, locale: enUS))
    XCTAssertNil(DeltaText.Model.make(fraction: .infinity, basis: "", amount: nil, currencyCode: nil, locale: enUS))
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
