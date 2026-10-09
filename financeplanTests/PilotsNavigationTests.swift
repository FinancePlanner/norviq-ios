import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class PilotsNavigationTests: XCTestCase {
  func testRoutesAreIdentifiedBySlugOrFollowIdNotBySnapshot() {
    let pilot = PilotSummary.fixture(holdingsCount: 12)
    let refreshed = PilotSummary.fixture(holdingsCount: 13)
    XCTAssertEqual(PilotRoute.pilot(pilot), .pilot(refreshed))
    XCTAssertEqual(Set([PilotRoute.pilot(pilot), .pilot(refreshed)]).count, 1)
    XCTAssertNotEqual(PilotRoute.pilot(pilot), .pilot(.fixture(slug: "berkshire", kind: .fund)))

    let follow = PilotFollowResponse.fixture(status: .active)
    XCTAssertEqual(PilotRoute.follow(follow), .follow(.fixture(status: .paused)))
    XCTAssertNotEqual(PilotRoute.follow(follow), .follow(.fixture(id: "other")))
    XCTAssertNotEqual(PilotRoute.browse, .pilot(pilot))
  }

  func testDisclosureIdsAreStableAcrossInsertsAndUniqueForTwins() {
    let older = disclosure("NVDA")
    let twin = disclosure("NVDA")
    let newer = disclosure("AAPL")

    let before = IdentifiedDisclosure.identify([older, twin])
    let after = IdentifiedDisclosure.identify([newer, older, twin])

    XCTAssertEqual(Set(before.map(\.id)).count, 2, "identical filings still get distinct ids")
    XCTAssertEqual(Array(after.dropFirst()).map(\.id), before.map(\.id), "a new filing on top keeps the others' ids")
  }

  func testStoreSplitsPilotsByKindOnLoad() async {
    let service = MockPilotsService()
    service.pilotsResult = .success([.fixture(), .fixture(slug: "berkshire", displayName: "Berkshire", kind: .fund)])
    let store = PilotsStore(service: service)

    await store.load()

    XCTAssertEqual(store.politicians.map(\.slug), ["nancy-pelosi"])
    XCTAssertEqual(store.funds.map(\.slug), ["berkshire"])
  }

  private func disclosure(_ symbol: String) -> PilotDisclosureItem {
    PilotDisclosureItem(
      symbol: symbol, side: "buy", instrument: "stock", transactionDate: "2026-09-14",
      disclosureDate: "2026-09-28", amountMin: 1001, amountMax: 15000, period: nil
    )
  }
}
