import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

// Tests that create a store are `async` even when they await nothing: on this
// toolchain (Xcode 26.2, iOS 18 deployment target) an `@Observable @MainActor`
// object freed by a synchronous test crashes in
// `swift_task_deinitOnExecutorMainActorBackDeploy` ("pointer being freed was
// not allocated"). The same crash hits OnboardingQuestionnaireViewModel.
@MainActor
final class PilotsStoreTests: XCTestCase {
  private let notFound = PilotsHTTPClient.Error.rejected(status: 404, message: "Not Found")

  func testLoadMarksTheFeatureAvailableAndKeepsFollows() async {
    let service = MockPilotsService()
    service.followsResult = .success([.fixture()])
    let store = PilotsStore(service: service)

    await store.load()

    XCTAssertEqual(store.availability, .available)
    XCTAssertTrue(store.isAvailable)
    XCTAssertEqual(store.pilots.map(\.slug), ["nancy-pelosi"])
    XCTAssertEqual(store.follows.map(\.id), ["11111111-1111-1111-1111-111111111111"])
    XCTAssertNil(store.errorMessage)
  }

  func testFeatureSwitchedOffHidesEverythingWithoutAnError() async {
    let service = MockPilotsService()
    service.followsResult = .success([.fixture()])
    let store = PilotsStore(service: service)
    await store.load()

    service.pilotsResult = .failure(notFound)
    service.followsResult = .failure(notFound)
    await store.load()

    XCTAssertEqual(store.availability, .unavailable)
    XCTAssertFalse(store.isAvailable)
    XCTAssertTrue(store.pilots.isEmpty)
    XCTAssertTrue(store.follows.isEmpty)
    XCTAssertNil(store.errorMessage)
  }

  func testOtherFailuresKeepEntryPointsHiddenUntilAFirstSuccess() async {
    let service = MockPilotsService()
    service.pilotsResult = .failure(PilotsHTTPClient.Error.invalidStatus(500))
    let store = PilotsStore(service: service)

    await store.load()

    XCTAssertEqual(store.availability, .unknown)
    XCTAssertFalse(store.isAvailable)
    XCTAssertEqual(store.errorMessage, "Request failed (500).")
  }

  func testInsertReplaceAndRemoveKeepOneCopyAndBumpTheRevision() async {
    let store = PilotsStore(service: MockPilotsService())
    let follow = PilotFollowResponse.fixture()

    store.insert(follow)
    store.insert(follow)
    XCTAssertEqual(store.follows.count, 1)
    XCTAssertEqual(store.followsRevision, 2)

    store.replace(.fixture(status: .paused))
    XCTAssertEqual(store.follows.first?.status, .paused)
    XCTAssertEqual(store.followsRevision, 2)

    store.remove(followId: follow.id)
    XCTAssertTrue(store.follows.isEmpty)
    XCTAssertEqual(store.followsRevision, 3)
  }

  func testFollowsForPilotFiltersBySlug() async {
    let store = PilotsStore(service: MockPilotsService())
    store.insert(.fixture(id: "a"))
    store.insert(.fixture(id: "b", pilot: .fixture(slug: "berkshire", displayName: "Berkshire", kind: .fund)))

    XCTAssertEqual(store.follows(forPilot: "nancy-pelosi").map(\.id), ["a"])
  }

  func testIsFeatureOffOnlyFor404() {
    XCTAssertTrue(PilotsStore.isFeatureOff(notFound))
    XCTAssertFalse(PilotsStore.isFeatureOff(PilotsHTTPClient.Error.rejected(status: 403, message: nil)))
    XCTAssertFalse(PilotsStore.isFeatureOff(URLError(.notConnectedToInternet)))
  }
}
