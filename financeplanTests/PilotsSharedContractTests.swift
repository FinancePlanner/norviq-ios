import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

/// Pins the StockPlanShared version the pilots feature needs: these types and
/// the lenient `WatchlistStatus` exist from 5.17.0.
final class PilotsSharedContractTests: XCTestCase {
  func testWatchlistItemWithExitedStatusDecodes() throws {
    let json = Data(#"{"id":"w1","symbol":"NVDA","note":"Pelosi sold 2026-09-30","status":"exited"}"#.utf8)
    let item = try JSONDecoder.stockPlanShared.decode(WatchlistItemResponse.self, from: json)
    XCTAssertEqual(item.status, .exited)
  }

  func testUnknownWatchlistStatusDecodesAsActive() throws {
    let json = Data(#"{"id":"w1","symbol":"NVDA","status":"something_new"}"#.utf8)
    let item = try JSONDecoder.stockPlanShared.decode(WatchlistItemResponse.self, from: json)
    XCTAssertEqual(item.status, .active)
  }

  func testPilotDetailDecodesFromTheServerShape() throws {
    let json = Data(#"""
    {"pilot":{"slug":"nancy-pelosi","displayName":"Nancy Pelosi","kind":"politician","chamber":"house","updatedAt":"2026-09-30T12:00:00Z","holdingsCount":2},
     "weights":[{"symbol":"NVDA","weight":0.6},{"symbol":"AAPL","weight":0.4}],
     "skippedPuts":1,
     "recentDisclosures":[{"symbol":"NVDA","side":"buy","instrument":"call","transactionDate":"2026-09-14","disclosureDate":"2026-09-28","amountMin":1001,"amountMax":15000,"period":null}],
     "lagNote":"Congressional trades are disclosed up to 45 days after they happen."}
    """#.utf8)
    let detail = try JSONDecoder.stockPlanShared.decode(PilotDetail.self, from: json)
    XCTAssertEqual(detail.pilot.kind, .politician)
    XCTAssertEqual(detail.weights.map(\.symbol), ["NVDA", "AAPL"])
    XCTAssertEqual(detail.skippedPuts, 1)
    XCTAssertEqual(detail.recentDisclosures.first?.instrument, "call")
  }
}
