import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class PilotFollowRulesTests: XCTestCase {
  func testAPilotWithNoTradesCannotBeFollowedOnAnyPlan() {
    let empty = PilotSummary.fixture(holdingsCount: 0)
    XCTAssertEqual(PilotFollowRules.block(for: empty, isPro: true, followCount: 0), .noTradesYet)
    XCTAssertEqual(PilotFollowRules.block(for: empty, isPro: false, followCount: 0), .noTradesYet)
  }

  func testFreeGetsOneFollowAndProGetsTen() {
    let pilot = PilotSummary.fixture()
    XCTAssertNil(PilotFollowRules.block(for: pilot, isPro: false, followCount: 0))
    XCTAssertEqual(PilotFollowRules.block(for: pilot, isPro: false, followCount: 1), .needsPro)
    XCTAssertNil(PilotFollowRules.block(for: pilot, isPro: true, followCount: 9))
    XCTAssertEqual(PilotFollowRules.block(for: pilot, isPro: true, followCount: 10), .atLimit)
  }

  func testStartingCapitalMustBeAboveZeroAndAtMostTenMillion() {
    XCTAssertEqual(PilotFollowRules.capitalProblem(nil), "Enter a starting amount.")
    XCTAssertEqual(PilotFollowRules.capitalProblem(0), "Enter an amount above zero.")
    XCTAssertEqual(PilotFollowRules.capitalProblem(10_000_001), "The most you can start with is $10,000,000.")
    XCTAssertNil(PilotFollowRules.capitalProblem(10_000))
    XCTAssertNil(PilotFollowRules.capitalProblem(10_000_000))
  }

  func testTypedCapitalIsCheckedFromTheRawText() {
    let enUS = Locale(identifier: "en_US")
    XCTAssertNil(PilotFollowRules.capitalProblem(text: "10,000,000", locale: enUS))
    XCTAssertEqual(PilotFollowRules.capitalProblem(text: "10,000,001", locale: enUS), "The most you can start with is $10,000,000.")
    XCTAssertEqual(PilotFollowRules.capitalProblem(text: "", locale: enUS), "Enter a starting amount.")
    // The shared parser drops a minus; the capital rule refuses it instead.
    XCTAssertEqual(PilotFollowRules.capitalProblem(text: "-500", locale: enUS), "Enter an amount above zero.")
    XCTAssertEqual(PilotFollowRules.capitalProblem(text: "\u{2212}500", locale: enUS), "Enter an amount above zero.")
  }
}

@MainActor
final class PilotFollowFailureTests: XCTestCase {
  private func rejected(_ status: Int, _ message: String?) -> PilotsHTTPClient.Error {
    .rejected(status: status, message: message)
  }

  func testUpgradeRequiredOpensThePaywallForFreeAndNeverShowsTheRawReason() {
    let error = PilotsHTTPClient.Error.upgradeRequired(
      feature: "pilot_follows",
      message: "Upgrade required. feature=pilot_follows plan=free required=pro"
    )
    XCTAssertEqual(PilotFollowFailure.from(error, isPro: false), .needsPro)
    // No limit in the body: neutral copy, no invented number.
    XCTAssertEqual(
      PilotFollowFailure.from(error, isPro: true),
      .message("You've reached your pilot follow limit. Stop one to follow another.")
    )
  }

  func testProAtTheLimitIsToldTheNumbersFromTheServer() {
    let atLimit = PilotsHTTPClient.Error.upgradeRequired(
      feature: "pilot_follows",
      message: "Upgrade required. feature=pilot_follows plan=pro limit=10 current=10",
      limit: 10,
      current: 10
    )
    XCTAssertEqual(
      PilotFollowFailure.from(atLimit, isPro: true),
      .message("You're following 10 of the 10 pilots your plan allows. Stop one to follow another.")
    )
    XCTAssertEqual(PilotFollowFailure.from(atLimit, isPro: false), .needsPro)
  }

  func testPortfolioCapExplainsArchiving() {
    let error = PilotsHTTPClient.Error.upgradeRequired(
      feature: "portfolio_lists",
      message: "Upgrade required. feature=portfolio_lists plan=pro limit=25 current=25"
    )
    XCTAssertEqual(
      PilotFollowFailure.from(error, isPro: true),
      .message("You've reached the portfolio limit for your plan. Archive a portfolio, then try again.")
    )
  }

  func testA403ThatIsNotAnUpgradeIsAScopeProblem() {
    XCTAssertEqual(
      PilotFollowFailure.from(rejected(403, "Insufficient scope."), isPro: true),
      .message("Your sign-in can't make this change. Sign out and back in, then try again.")
    )
    // Upgrade is read from the billing body's `feature`, never from text.
    XCTAssertEqual(
      PilotFollowFailure.from(rejected(403, "Upgrade required. feature=pilot_follows plan=free"), isPro: false),
      .message("Your sign-in can't make this change. Sign out and back in, then try again.")
    )
  }

  func testFeatureOffAndMissingPilot() {
    XCTAssertEqual(PilotFollowFailure.from(rejected(404, "Not Found"), isPro: true), .message("Following pilots isn't available right now."))
    XCTAssertEqual(PilotFollowFailure.from(rejected(404, nil), isPro: true), .message("Following pilots isn't available right now."))
    XCTAssertEqual(PilotFollowFailure.from(rejected(404, "Watchlist not found."), isPro: true), .message("Watchlist not found."))
  }

  func testServerReasonsAreShownFor400_409_422WithFallbacks() {
    XCTAssertEqual(PilotFollowFailure.from(rejected(409, "This pilot has no disclosures yet. Try again later."), isPro: true), .message("This pilot has no disclosures yet. Try again later."))
    XCTAssertEqual(PilotFollowFailure.from(rejected(409, nil), isPro: true), .message("No trades seen yet for this pilot. Try again later."))
    XCTAssertEqual(PilotFollowFailure.from(rejected(422, nil), isPro: true), .message("Choose an empty watchlist, or let Norviq create one."))
    XCTAssertEqual(PilotFollowFailure.from(rejected(400, nil), isPro: true), .message("Starting capital must be more than $0 and at most $10,000,000."))
  }

  func testOtherErrorsUseTheirDescription() {
    XCTAssertEqual(PilotFollowFailure.from(PilotsHTTPClient.Error.invalidStatus(500), isPro: true), .message("Request failed (500)."))
  }
}

@MainActor
final class PilotFormattingTests: XCTestCase {
  private let enUS = Locale(identifier: "en_US")

  func testDaysAreShownAsReportedInEveryTimeZone() {
    XCTAssertEqual(PilotFormatting.dayText("2026-09-14", locale: enUS), "Sep 14, 2026")
    XCTAssertEqual(PilotFormatting.dayText("not-a-day", locale: enUS), "not-a-day")
    XCTAssertNil(PilotFormatting.day("2026/09/14"))
  }

  func testValuePointsDropBadDatesAndSortOldestFirst() {
    let points = PilotFormatting.valuePoints([
      PilotFollowSnapshotResponse(date: "2026-10-02", value: 10_420, cash: 10),
      PilotFollowSnapshotResponse(date: "garbage", value: 1, cash: 0),
      PilotFollowSnapshotResponse(date: "2026-10-01", value: 10_000, cash: 10)
    ])
    XCTAssertEqual(points.map(\.value), [10_000, 10_420])
  }

  func testPerformanceAgainstStartingCapital() throws {
    let performance = try XCTUnwrap(PilotFormatting.performance(start: 10_000, latest: 10_420))
    XCTAssertEqual(performance, 0.042, accuracy: 1e-9)
    XCTAssertNil(PilotFormatting.performance(start: nil, latest: 10_420))
    XCTAssertNil(PilotFormatting.performance(start: 0, latest: 10_420))
    XCTAssertNil(PilotFormatting.performance(start: 10_000, latest: nil))
    XCTAssertEqual(PilotFormatting.signedPercent(0.042, locale: enUS), "+4.2%")
    XCTAssertEqual(PilotFormatting.signedPercent(-0.031, locale: enUS), "-3.1%")
  }

  func testPilotSubtitles() {
    XCTAssertEqual(PilotFormatting.subtitle(for: .fixture(holdingsCount: 12)), "Representative · 12 holdings")
    XCTAssertEqual(PilotFormatting.subtitle(for: .fixture(holdingsCount: 1)), "Representative · 1 holding")
    XCTAssertEqual(PilotFormatting.subtitle(for: .fixture(holdingsCount: 0)), "Representative · No trades seen yet")
    XCTAssertEqual(PilotFormatting.subtitle(for: .fixture(slug: "berkshire", displayName: "Berkshire", kind: .fund, holdingsCount: 40)), "13F fund · 40 holdings")
  }

  func testSkippedPutsNote() {
    XCTAssertNil(PilotFormatting.skippedPutsNote(0))
    XCTAssertEqual(PilotFormatting.skippedPutsNote(1), "1 put trade wasn't mirrored: a simulated portfolio can't go short.")
    XCTAssertEqual(PilotFormatting.skippedPutsNote(3), "3 put trades weren't mirrored: a simulated portfolio can't go short.")
  }

  func testDisclosureText() throws {
    let call = try XCTUnwrap(PilotDetail.fixture().recentDisclosures.first)
    XCTAssertEqual(PilotFormatting.disclosureTitle(call), "Bought NVDA calls")
    XCTAssertEqual(
      PilotFormatting.disclosureDetail(call, locale: enUS),
      "$1,001–$15,000 · traded Sep 14, 2026 · disclosed Sep 28, 2026"
    )
    let put = PilotDisclosureItem(symbol: "TSLA", side: "buy", instrument: "put", transactionDate: nil, disclosureDate: nil, amountMin: 50_000, amountMax: nil, period: nil)
    XCTAssertTrue(PilotFormatting.isSkippedPut(put))
    XCTAssertEqual(PilotFormatting.disclosureTitle(put), "Bought TSLA puts")
    XCTAssertEqual(PilotFormatting.disclosureDetail(put, locale: enUS), "Over $50,000")
    let fund = PilotDisclosureItem(symbol: "AAPL", side: "sell_full", instrument: "stock", transactionDate: nil, disclosureDate: nil, amountMin: nil, amountMax: nil, period: "2026Q2")
    XCTAssertEqual(PilotFormatting.disclosureTitle(fund), "Sold all AAPL")
    XCTAssertEqual(PilotFormatting.disclosureDetail(fund, locale: enUS), "13F period 2026Q2")
  }

  func testWeightAndMoney() {
    XCTAssertEqual(PilotFormatting.weight(0.2534, locale: enUS), "25.3%")
    XCTAssertEqual(PilotFormatting.money(10_000, currency: "USD", wholeUnits: true, locale: enUS), "$10,000")
  }

  func testFollowSubtitles() {
    XCTAssertEqual(PilotFormatting.followSubtitle(.fixture(), locale: enUS), "Simulated portfolio · started with $10,000")
    XCTAssertEqual(PilotFormatting.followSubtitle(.fixture(targetKind: .watchlist), locale: enUS), "Watchlist feed")
  }

  func testEventText() {
    XCTAssertEqual(PilotFormatting.eventTitle(.fixture(kind: "buy"), locale: enUS), "Bought 12.5 NVDA")
    XCTAssertEqual(PilotFormatting.eventTitle(.fixture(kind: "sell", quantity: 3), locale: enUS), "Sold 3 NVDA")
    XCTAssertEqual(PilotFormatting.eventTitle(.fixture(kind: "watch_added", quantity: nil), locale: enUS), "Added NVDA to the watchlist")
    XCTAssertEqual(PilotFormatting.eventTitle(.fixture(kind: "watch_exited", quantity: nil), locale: enUS), "Marked NVDA as exited")
    XCTAssertEqual(PilotFormatting.eventTitle(.fixture(kind: "skipped_unpriced"), locale: enUS), "Skipped NVDA: no price available")
    XCTAssertEqual(PilotFormatting.eventTitle(.fixture(kind: "skipped_limit"), locale: enUS), "Skipped NVDA: watchlist is full")
    XCTAssertEqual(PilotFormatting.eventTitle(.fixture(kind: "new_kind"), locale: enUS), "New Kind NVDA")
    XCTAssertEqual(
      PilotFormatting.eventDetail(.fixture(), currency: "USD", locale: enUS, timeZone: .gmt),
      "at $123.45 · Sep 30, 2026"
    )
    XCTAssertEqual(
      PilotFormatting.eventDetail(.fixture(kind: "watch_added", price: nil), currency: "USD", locale: enUS, timeZone: .gmt),
      "Sep 30, 2026"
    )
  }
}
