import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

/// Home's activity feed and the line chart use the app's locale and the
/// currency their data is in (spec § 2.0 A4: one screen, one format).
@MainActor
final class HomeMoneyFormatTests: XCTestCase {
  private let unitedStates = Locale(identifier: "en_US")
  private let portugal = Locale(identifier: "pt_PT")

  private func activity(_ type: UserActivityType, amount: Double?) -> UserActivityResponse {
    UserActivityResponse(
      id: UUID(),
      userId: UUID(),
      type: type,
      title: "Row",
      subtitle: "",
      amount: amount,
      isGrowth: (amount ?? 0) > 0,
      symbol: "circle",
      createdAt: Date(timeIntervalSince1970: 1_795_521_600)
    )
  }

  func testExpenseActivityUsesTheBudgetCurrency() {
    let text = UnifiedActivityFeed.amountText(
      for: activity(.expenseRecorded, amount: -82),
      portfolioCurrencyCode: "USD",
      spendingCurrencyCode: "EUR",
      locale: portugal
    )
    XCTAssertEqual(text, "\u{2212}82,00\u{00A0}€")
  }

  func testHoldingActivityUsesThePortfolioCurrency() {
    let text = UnifiedActivityFeed.amountText(
      for: activity(.stockAdded, amount: 965.54),
      portfolioCurrencyCode: "USD",
      spendingCurrencyCode: "EUR",
      locale: portugal
    )
    XCTAssertEqual(text, "+965,54\u{00A0}US$")
  }

  func testUnknownCurrencyIsNeverGuessed() {
    let text = UnifiedActivityFeed.amountText(
      for: activity(.expenseUpdated, amount: -5),
      portfolioCurrencyCode: "USD",
      spendingCurrencyCode: nil,
      locale: unitedStates
    )
    XCTAssertEqual(text, "\u{2212}5.00\u{00A0}—")
  }

  func testChartDayLabelIsTheUtcDayInTheAppLocale() {
    // 1 Nov 2026 00:00 UTC: the API's day, whatever the phone's time zone.
    let date = Date(timeIntervalSince1970: 1_793_491_200)
    XCTAssertEqual(InteractiveLineChart.dayLabel(date, locale: unitedStates), "Nov 1")
  }
}
