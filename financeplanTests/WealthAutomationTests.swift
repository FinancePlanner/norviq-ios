import Foundation
import Testing
@testable import financeplan

@Suite("Wealth automation")
struct WealthAutomationTests {
  @Test("Rebalancing targets normalize symbols and preserve a full allocation")
  func parsesRebalancingTargets() throws {
    let targets = try RebalanceTargetsParser.parse("aapl:60, MSFT:30, cash:10")

    #expect(targets.count == 3)
    #expect(targets[0].symbol == "AAPL")
    #expect(targets[2].kind == "cash")
    #expect(targets[2].symbol == nil)
    #expect(abs(targets.reduce(0) { $0 + $1.targetWeight } - 1) < 0.0001)
  }

  @Test("Rebalancing targets reject incomplete allocations")
  func rejectsIncompleteRebalancingTargets() {
    #expect(throws: RebalanceTargetsParser.ValidationError.self) {
      try RebalanceTargetsParser.parse("AAPL:50, cash:10")
    }
  }

  @Test("Rebalance events decode production dismissal and currency fields")
  func decodesDismissedRebalanceEvent() throws {
    let payload = #"{"id":"event-1","policyId":"policy-1","status":"dismissed","preview":{"portfolioValue":10000,"currency":"USD","maximumDrift":0.08,"triggerReasons":["drift"],"trades":[],"warnings":[]},"createdAt":"2026-07-14T10:00:00Z","dismissedAt":"2026-07-14T10:05:00Z"}"#.data(
      using: .utf8
    )!

    let event = try JSONDecoder().decode(RebalanceEventWire.self, from: payload)

    #expect(event.status == "dismissed")
    #expect(event.dismissedAt == "2026-07-14T10:05:00Z")
    #expect(event.preview.currency == "USD")
  }

  @Test("Automation push payload routes to the referenced smart screen")
  func parsesSmartScreenPush() {
    let route = PushNotificationPayloadParser.parse(userInfo: [
      "type": "watchlist_screen",
      "data": ["screen_id": "screen-1"],
      "deepLink": "financeplan://automation/screens/screen-1",
    ])

    #expect(route?.kind == .watchlistScreen)
    #expect(route?.screenID == "screen-1")
  }

  @Test("Automation push payload routes to the referenced portfolio")
  func parsesRebalancingPush() {
    let route = PushNotificationPayloadParser.parse(userInfo: [
      "type": "rebalancing",
      "data": ["portfolio_list_id": "portfolio-1", "event_id": "event-1"],
    ])

    #expect(route?.kind == .rebalancing)
    #expect(route?.portfolioListID == "portfolio-1")
    #expect(route?.eventID == "event-1")
  }
}
