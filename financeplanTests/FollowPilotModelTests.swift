import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

// Every test is `async`, even those that await nothing: see PilotsStoreTests
// for the synchronous-deinit crash this avoids.
@MainActor
final class FollowPilotModelTests: XCTestCase {
  private func makeModel(isPro: Bool, service: MockPilotsService = MockPilotsService()) -> (FollowPilotModel, MockPilotsService, PilotsStore) {
    let store = PilotsStore(service: service)
    let model = FollowPilotModel(pilot: .fixture(), isPro: isPro, idempotencyKey: "sheet-key", service: service, store: store)
    return (model, service, store)
  }

  func testProStartsOnAPortfolioAndFreeOnAWatchlist() async {
    XCTAssertEqual(makeModel(isPro: true).0.target, .portfolio)
    XCTAssertEqual(makeModel(isPro: false).0.target, .watchlist)
  }

  func testPortfolioRequestCarriesTheCapitalAndAsksForANewPortfolio() async {
    let (model, _, _) = makeModel(isPro: true)
    model.capitalText = "25000"

    XCTAssertEqual(
      model.makeRequest(),
      PilotFollowCreateRequest(pilotSlug: "nancy-pelosi", targetKind: .portfolio, portfolioListId: nil, watchlistListId: nil, startingCapital: 25_000)
    )
  }

  func testWatchlistRequestCarriesTheChosenListAndNoCapital() async {
    let (model, _, _) = makeModel(isPro: false)
    model.capitalText = "25000"
    XCTAssertEqual(
      model.makeRequest(),
      PilotFollowCreateRequest(pilotSlug: "nancy-pelosi", targetKind: .watchlist, portfolioListId: nil, watchlistListId: nil, startingCapital: nil)
    )

    model.watchlistListId = "33333333-3333-3333-3333-333333333333"
    XCTAssertEqual(model.makeRequest()?.watchlistListId, "33333333-3333-3333-3333-333333333333")
  }

  func testInvalidCapitalNeverReachesTheServer() async {
    let (model, service, _) = makeModel(isPro: true)
    for text in ["", "abc", "0", "20000000"] {
      model.capitalText = text
      let follow = await model.submit(isPro: true)
      XCTAssertNil(follow, text)
      XCTAssertNotNil(model.failureMessage, text)
    }
    XCTAssertTrue(service.followRequests.isEmpty)
  }

  func testFreeChoosingAPortfolioGetsThePaywallWithoutARequest() async {
    let (model, service, _) = makeModel(isPro: false)
    model.target = .portfolio
    model.capitalText = "10000"

    XCTAssertTrue(model.requiresPro(isPro: false))
    let follow = await model.submit(isPro: false)

    XCTAssertNil(follow)
    XCTAssertEqual(model.failure, .needsPro)
    XCTAssertTrue(service.followRequests.isEmpty)
  }

  func testFreeAtTheServerLimitGetsThePaywall() async {
    let service = MockPilotsService()
    service.followResult = .failure(PilotsHTTPClient.Error.upgradeRequired(feature: "pilot_follows", message: "Upgrade required. feature=pilot_follows plan=free limit=1 current=1"))
    let (model, _, _) = makeModel(isPro: false, service: service)

    _ = await model.submit(isPro: false)

    XCTAssertEqual(model.failure, .needsPro)
    XCTAssertNil(model.failureMessage)
  }

  func testNonEmptyWatchlistShowsTheServerReason() async {
    let service = MockPilotsService()
    service.followResult = .failure(PilotsHTTPClient.Error.rejected(status: 422, message: "Choose an empty watchlist, or let Norviq create one."))
    let (model, _, store) = makeModel(isPro: true, service: service)
    model.target = .watchlist
    model.watchlistListId = "33333333-3333-3333-3333-333333333333"

    let follow = await model.submit(isPro: true)

    XCTAssertNil(follow)
    XCTAssertEqual(model.failureMessage, "Choose an empty watchlist, or let Norviq create one.")
    XCTAssertTrue(store.follows.isEmpty)
  }

  func testEveryAttemptFromOneSheetReusesTheIdempotencyKey() async {
    let service = MockPilotsService()
    service.followResult = .failure(PilotsHTTPClient.Error.invalidStatus(502))
    let (model, _, _) = makeModel(isPro: true, service: service)

    _ = await model.submit(isPro: true)
    service.followResult = .success(.fixture())
    _ = await model.submit(isPro: true)

    XCTAssertEqual(service.idempotencyKeys, ["sheet-key", "sheet-key"])
  }

  func testSuccessAddsTheFollowToTheSharedStore() async {
    let (model, _, store) = makeModel(isPro: true)

    let follow = await model.submit(isPro: true)

    XCTAssertEqual(follow?.id, "11111111-1111-1111-1111-111111111111")
    XCTAssertEqual(store.follows.map(\.id), ["11111111-1111-1111-1111-111111111111"])
    XCTAssertEqual(store.followsRevision, 1)
    XCTAssertNil(model.failure)
  }

  func testWatchlistsLoadAndAFailureLeavesOnlyNewWatchlist() async {
    let service = MockPilotsService()
    service.watchlistsResult = .success([WatchlistListDTOResponse(id: "w1", name: "Ideas", isDefault: true, createdAt: nil, updatedAt: nil)])
    let (model, _, _) = makeModel(isPro: false, service: service)

    await model.loadWatchlists()
    XCTAssertEqual(model.watchlists.map(\.id), ["w1"])

    service.watchlistsResult = .failure(PilotsHTTPClient.Error.invalidStatus(500))
    await model.loadWatchlists()
    XCTAssertTrue(model.watchlists.isEmpty)
  }
}
