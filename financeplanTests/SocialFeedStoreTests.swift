import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

private final class FeedService: SocialServicing, @unchecked Sendable {
  struct Failure: Error {}

  var pages: [String?: SocialFeedResponse] = [:]
  var feedError: Error?
  var congratulateError: Error?
  private(set) var feedCalls: [String?] = []
  private(set) var congratulateCalls: [String] = []
  /// Suspends `congratulate` until the test resumes it, to probe double taps.
  var congratulateGate: CheckedContinuation<Void, Never>?
  var holdCongratulate = false

  func feed(cursor: String?, limit: Int) async throws -> SocialFeedResponse {
    feedCalls.append(cursor)
    if let feedError { throw feedError }
    return pages[cursor] ?? SocialFeedResponse(items: [], nextCursor: nil)
  }

  func congratulate(activityId: String) async throws {
    congratulateCalls.append(activityId)
    if holdCongratulate {
      await withCheckedContinuation { congratulateGate = $0 }
    }
    if let congratulateError { throw congratulateError }
  }

  func friendAchievements(userId: String) async throws -> [AchievementUnlock] { [] }
  func config() async throws -> SocialConfig { .disabled }
  func searchUsers(query: String) async throws -> [SocialUserSummary] { [] }
  func profile(userId: String) async throws -> SocialProfile { throw Failure() }
  func friends() async throws -> [SocialUserSummary] { [] }
  func removeFriend(userId: String) async throws {}
  func friendRequests() async throws -> FriendRequestsResponse { throw Failure() }
  func sendFriendRequest(userId: String) async throws -> FriendRequest { throw Failure() }
  func respond(to requestId: String, accept: Bool) async throws {}
  func cancelFriendRequest(requestId: String) async throws {}
  func createInvite() async throws -> InviteLink { throw Failure() }
  func invitePreview(code: String) async throws -> SocialUserSummary { throw Failure() }
  func redeemInvite(code: String) async throws -> InviteRedeemResponse { throw Failure() }
  func privacy() async throws -> SocialPrivacySettings { .default }
  func updatePrivacy(_ settings: SocialPrivacySettings) async throws -> SocialPrivacySettings { settings }
  func blockedUsers() async throws -> [SocialUserSummary] { [] }
  func setBlocked(userId: String, blocked: Bool) async throws {}
  func report(_ request: ReportRequest) async throws {}
  func matchContacts(_ request: ContactMatchRequest) async throws -> [ContactMatch] { [] }
  func startXImport(redirectURI: String) async throws -> OAuthStartResponsePayload { throw Failure() }
  func finishXImport(_ request: OAuthExchangeRequestPayload) async throws -> XImportMatchesResponse { throw Failure() }
  func importFacebookFriends(_ request: FacebookLimitedLoginRequest) async throws -> FacebookImportMatchesResponse {
    throw Failure()
  }
  func disconnectFacebook() async throws {}
}

@MainActor
final class SocialFeedStoreTests: XCTestCase {
  private func item(_ id: String, count: Int = 0, cheered: Bool = false) -> SocialFeedItem {
    SocialFeedItem(
      id: id,
      actor: SocialUserSummary(
        id: "u-\(id)", username: "user\(id)", displayName: nil, avatarUrl: nil,
        friendshipStatus: .friends, mutualFriendCount: nil
      ),
      achievement: SocialFeedAchievement(key: "craft.thesis", tier: "bronze", title: "Thesis Writer", iconKey: "book.fill"),
      createdAt: Date(timeIntervalSince1970: 1_790_000_000),
      congratsCount: count,
      viewerCongratulated: cheered
    )
  }

  func testRefreshLoadsTheFirstPage() async {
    let service = FeedService()
    service.pages[nil] = SocialFeedResponse(items: [item("a"), item("b")], nextCursor: "c1")
    let store = SocialFeedStore(service: service)
    await store.refresh()
    XCTAssertEqual(store.items.map(\.id), ["a", "b"])
    XCTAssertTrue(store.hasMore)
    XCTAssertEqual(service.feedCalls, [nil])
  }

  func testReachingTheLastRowAppendsTheNextPage() async {
    let service = FeedService()
    service.pages[nil] = SocialFeedResponse(items: [item("a"), item("b")], nextCursor: "c1")
    service.pages["c1"] = SocialFeedResponse(items: [item("c")], nextCursor: nil)
    let store = SocialFeedStore(service: service)
    await store.refresh()

    await store.loadMoreIfNeeded(after: store.items[0])
    XCTAssertEqual(service.feedCalls, [nil], "only the last row triggers paging")

    await store.loadMoreIfNeeded(after: store.items[1])
    XCTAssertEqual(store.items.map(\.id), ["a", "b", "c"])
    XCTAssertFalse(store.hasMore)

    await store.loadMoreIfNeeded(after: store.items[2])
    XCTAssertEqual(service.feedCalls, [nil, "c1"], "no fetch past the last page")
  }

  func testLoadFailureIsReported() async {
    let service = FeedService()
    service.feedError = FeedService.Failure()
    let store = SocialFeedStore(service: service)
    await store.refresh()
    XCTAssertNotNil(store.loadError)
    XCTAssertTrue(store.items.isEmpty)
  }

  func testCongratsIsOptimistic() async {
    let service = FeedService()
    service.pages[nil] = SocialFeedResponse(items: [item("a", count: 2)], nextCursor: nil)
    let store = SocialFeedStore(service: service)
    await store.refresh()

    await store.congratulate(store.items[0])

    XCTAssertEqual(service.congratulateCalls, ["a"])
    XCTAssertEqual(store.items[0].congratsCount, 3)
    XCTAssertTrue(store.items[0].viewerCongratulated)
  }

  func testDoubleTapSendsOneRequest() async {
    let service = FeedService()
    service.pages[nil] = SocialFeedResponse(items: [item("a")], nextCursor: nil)
    service.holdCongratulate = true
    let store = SocialFeedStore(service: service)
    await store.refresh()
    let row = store.items[0]

    let first = Task { await store.congratulate(row) }
    while service.congratulateGate == nil { await Task.yield() }
    await store.congratulate(row)
    service.congratulateGate?.resume()
    await first.value

    XCTAssertEqual(service.congratulateCalls, ["a"])
    XCTAssertEqual(store.items[0].congratsCount, 1)
  }

  func testAlreadyCheeredRowsSendNothing() async {
    let service = FeedService()
    service.pages[nil] = SocialFeedResponse(items: [item("a", count: 4, cheered: true)], nextCursor: nil)
    let store = SocialFeedStore(service: service)
    await store.refresh()
    await store.congratulate(store.items[0])
    XCTAssertTrue(service.congratulateCalls.isEmpty)
    XCTAssertEqual(store.items[0].congratsCount, 4)
  }

  func testFailedCongratsIsUndone() async {
    let service = FeedService()
    service.pages[nil] = SocialFeedResponse(items: [item("a", count: 2)], nextCursor: nil)
    service.congratulateError = FeedService.Failure()
    let store = SocialFeedStore(service: service)
    await store.refresh()

    await store.congratulate(store.items[0])

    XCTAssertEqual(store.items[0].congratsCount, 2)
    XCTAssertFalse(store.items[0].viewerCongratulated)
    XCTAssertNotNil(store.actionMessage)
  }

  func testCongratsOnAVanishedActivityRemovesTheRow() async {
    let service = FeedService()
    service.pages[nil] = SocialFeedResponse(items: [item("a"), item("b")], nextCursor: nil)
    service.congratulateError = SocialHTTPClient.Error.notFound(nil)
    let store = SocialFeedStore(service: service)
    await store.refresh()

    await store.congratulate(store.items[0])

    XCTAssertEqual(store.items.map(\.id), ["b"])
    XCTAssertNotNil(store.actionMessage)
  }

  func testA404MapsToNotFound() {
    XCTAssertEqual(SocialHTTPClient.Error.makeStatus(404, message: "Activity not found"), .notFound("Activity not found"))
    XCTAssertEqual(SocialHTTPClient.Error.makeStatus(500, message: "boom"), .api("boom"))
  }

  func testPrivacyRoundTripKeepsShowAchievements() throws {
    var settings = SocialPrivacySettings.default
    settings.showAchievements = false
    let data = try JSONEncoder.stockPlanShared.encode(settings)
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    // The shared encoder writes snake_case, as for every other privacy field.
    XCTAssertEqual(object["show_achievements"] as? Bool, false)
  }
}
