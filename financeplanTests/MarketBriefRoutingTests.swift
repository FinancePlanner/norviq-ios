import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

private func briefPayload(
  slot: Any = "morning",
  tradingDate: Any = "2026-10-15",
  deepLink: Any = "financeplan://market/brief?slot=morning&date=2026-10-15"
) -> [AnyHashable: Any] {
  [
    "aps": [
      "alert": ["title": "Morning brief", "body": "Futures lower ahead of CPI."],
      "category": "MARKET_BRIEF",
      "thread-id": "market-brief"
    ],
    "schemaVersion": 1,
    "type": "market_brief",
    "slot": slot,
    "tradingDate": tradingDate,
    "deepLink": deepLink
  ]
}

// MARK: - Push payload parsing

final class MarketBriefPushPayloadParsingTests: XCTestCase {
  func testBackendPayloadParsesSlotAndDate() {
    let route = PushNotificationPayloadParser.parse(
      userInfo: briefPayload(),
      categoryIdentifier: "MARKET_BRIEF",
      threadIdentifier: "market-brief"
    )
    XCTAssertEqual(route?.kind, .marketBrief)
    XCTAssertEqual(route?.marketBriefRef, MarketBriefRef(slot: .morning, tradingDate: "2026-10-15"))
    XCTAssertEqual(route?.deepLink, "financeplan://market/brief?slot=morning&date=2026-10-15")
    XCTAssertNil(route?.symbol)
  }

  func testRawUserInfoWithoutContentIdentifiersStillRoutes() {
    // Launch options only carry userInfo; the category comes from `aps`.
    let route = PushNotificationPayloadParser.parse(userInfo: briefPayload(slot: "evening", tradingDate: "2026-10-14"))
    XCTAssertEqual(route?.kind, .marketBrief)
    XCTAssertEqual(route?.marketBriefRef, MarketBriefRef(slot: .evening, tradingDate: "2026-10-14"))
  }

  func testMissingSlotFallsBackToTheDeepLink() {
    var payload = briefPayload()
    payload["slot"] = nil
    payload["tradingDate"] = nil
    let route = PushNotificationPayloadParser.parse(userInfo: payload)
    XCTAssertEqual(route?.marketBriefRef, MarketBriefRef(slot: .morning, tradingDate: "2026-10-15"))
  }

  func testMalformedSlotAndLinkOpenTheLatestBrief() {
    let route = PushNotificationPayloadParser.parse(
      userInfo: briefPayload(slot: "midday", tradingDate: "15/10/2026", deepLink: "financeplan://market/brief"),
      categoryIdentifier: "MARKET_BRIEF"
    )
    XCTAssertEqual(route?.kind, .marketBrief, "a brief push never falls through to a target alert")
    XCTAssertNil(route?.marketBriefRef)
  }

  func testTypeAloneIdentifiesABriefPush() {
    let route = PushNotificationPayloadParser.parse(userInfo: ["type": "market_brief", "slot": "evening", "tradingDate": "2026-10-15"])
    XCTAssertEqual(route?.kind, .marketBrief)
    XCTAssertEqual(route?.marketBriefRef, MarketBriefRef(slot: .evening, tradingDate: "2026-10-15"))
  }

  func testOtherPushesAreUnaffected() {
    let route = PushNotificationPayloadParser.parse(userInfo: ["type": "target_hit", "symbol": "AAPL"])
    XCTAssertEqual(route?.kind, .targetHit)
    XCTAssertNil(route?.marketBriefRef)
  }
}

// MARK: - Deep links

final class MarketBriefDeepLinkTests: XCTestCase {
  func testParsesSlotAndDate() throws {
    let url = try XCTUnwrap(URL(string: "financeplan://market/brief?slot=evening&date=2026-10-14"))
    XCTAssertEqual(MarketBriefDeepLink.parse(url)?.ref, MarketBriefRef(slot: .evening, tradingDate: "2026-10-14"))
  }

  func testBareLinkMeansLatest() throws {
    let url = try XCTUnwrap(URL(string: "norviqa://market/brief"))
    let link = try XCTUnwrap(MarketBriefDeepLink.parse(url))
    XCTAssertNil(link.ref)
  }

  func testHalfAPairMeansLatest() throws {
    let url = try XCTUnwrap(URL(string: "financeplan://market/brief?slot=morning"))
    XCTAssertNil(try XCTUnwrap(MarketBriefDeepLink.parse(url)).ref)
  }

  func testRejectsOtherLinks() throws {
    XCTAssertNil(MarketBriefDeepLink.parse(try XCTUnwrap(URL(string: "financeplan://assistant/conversations/x"))))
    XCTAssertNil(MarketBriefDeepLink.parse(try XCTUnwrap(URL(string: "financeplan://market/quotes"))))
    XCTAssertNil(MarketBriefDeepLink.parse(try XCTUnwrap(URL(string: "https://norviq.org/market/brief"))))
  }

  func testTradingDateValidation() {
    XCTAssertTrue(MarketBriefDeepLink.isTradingDate("2026-10-15"))
    XCTAssertFalse(MarketBriefDeepLink.isTradingDate("2026-1-15"))
    XCTAssertFalse(MarketBriefDeepLink.isTradingDate("2026-10-15&x=1"))
    XCTAssertFalse(MarketBriefDeepLink.isTradingDate("abcd-ef-gh"))
  }
}

// MARK: - Router

@MainActor
final class MarketBriefRouterTests: XCTestCase {
  func testOpenQueuesOneRequestUntilConsumed() async {
    let router = MarketBriefRouter()
    let ref = MarketBriefRef(slot: .morning, tradingDate: "2026-10-15")

    router.open(ref)

    XCTAssertEqual(router.openCount, 1)
    XCTAssertEqual(router.consume()?.ref, ref)
    XCTAssertNil(router.consume())
    XCTAssertEqual(router.openCount, 1)
  }
}

// MARK: - Endpoints

final class MarketBriefEndpointTests: XCTestCase {
  private func queryItems(_ request: URLRequest) -> [String: String] {
    let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems ?? []
    return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
  }

  func testLatestBriefSendsOnlyTheLanguage() async throws {
    let client = BaseHTTPClient(baseURL: try XCTUnwrap(URL(string: "https://api.example.com")))

    let request = try await client.makeURLRequest(for: GetMarketBriefEndpoint(lang: "pt-PT"))

    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.url?.path, "/v1/market/brief")
    XCTAssertEqual(queryItems(request), ["lang": "pt-PT"])
    XCTAssertNil(request.httpBody)
  }

  func testExactBriefSendsSlotAndDate() async throws {
    let client = BaseHTTPClient(baseURL: try XCTUnwrap(URL(string: "https://api.example.com")))

    let request = try await client.makeURLRequest(
      for: GetMarketBriefEndpoint(lang: "en", slot: .evening, date: "2026-10-14")
    )

    XCTAssertEqual(queryItems(request), ["lang": "en", "slot": "evening", "date": "2026-10-14"])
  }

  func testHalfAPairIsNotSent() throws {
    XCTAssertEqual(try GetMarketBriefEndpoint(lang: "en", slot: .morning, date: nil).asParameters().count, 1)
  }

  func testNotificationPreferencesRoutes() async throws {
    let client = BaseHTTPClient(baseURL: try XCTUnwrap(URL(string: "https://api.example.com")))

    let read = try await client.makeURLRequest(for: GetMarketBriefNotificationsEndpoint())
    XCTAssertEqual(read.httpMethod, "GET")
    XCTAssertEqual(read.url?.path, "/v1/market/brief/notifications")

    let write = try await client.makeURLRequest(
      for: UpdateMarketBriefNotificationsEndpoint(enabled: true, language: "pt-PT")
    )
    XCTAssertEqual(write.httpMethod, "PUT")
    XCTAssertEqual(write.url?.path, "/v1/market/brief/notifications")
    let body = try XCTUnwrap(write.httpBody)
    let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    XCTAssertEqual(payload["enabled"] as? Bool, true)
    XCTAssertEqual(payload["language"] as? String, "pt-PT")
  }
}

// MARK: - Formatting

final class MarketBriefFormatTests: XCTestCase {
  func testSourceHostDropsWWWAndPath() {
    XCTAssertEqual(MarketBriefFormat.sourceHost("https://www.Reuters.com/markets/x?y=1"), "reuters.com")
    XCTAssertEqual(MarketBriefFormat.sourceHost("https://eco.sapo.pt/a"), "eco.sapo.pt")
    XCTAssertNil(MarketBriefFormat.sourceHost(nil))
    XCTAssertNil(MarketBriefFormat.sourceHost("not a url"))
  }

  func testTradingDateIsALisbonDay() throws {
    let date = try XCTUnwrap(MarketBriefFormat.tradingDate("2026-10-15"))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = MarketBriefFormat.tradingTimeZone
    XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: date), DateComponents(year: 2026, month: 10, day: 15))
    XCTAssertNil(MarketBriefFormat.tradingDate("15-10-2026"))
  }

  func testGeneratedTimeUsesTheReadersTimeZone() throws {
    let lisbon = try XCTUnwrap(TimeZone(identifier: "Europe/Lisbon"))
    XCTAssertEqual(MarketBriefFormat.generatedTimeLabel("2026-10-15T07:16:00Z", language: "pt-PT", timeZone: lisbon), "08:16")
    XCTAssertNotNil(MarketBriefFormat.generatedAt("2026-10-15T07:16:00.123Z"))
    XCTAssertNil(MarketBriefFormat.generatedTimeLabel(nil, language: "en"))
  }
}
