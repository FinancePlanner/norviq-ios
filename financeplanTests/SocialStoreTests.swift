import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

private final class MockSocialService: SocialServicing, @unchecked Sendable {
  struct Failure: Error {}

  var configResult: Result<SocialConfig, Error> = .success(.disabled)
  var friendsList: [SocialUserSummary] = []
  var requests = FriendRequestsResponse(incoming: [], outgoing: [])
  var responded: [(id: String, accept: Bool)] = []
  var sentTo: [String] = []
  var blockCalls: [(id: String, blocked: Bool)] = []
  var reports: [ReportRequest] = []

  func config() async throws -> SocialConfig { try configResult.get() }
  func searchUsers(query: String) async throws -> [SocialUserSummary] { [] }
  func profile(userId: String) async throws -> SocialProfile { throw Failure() }
  func friends() async throws -> [SocialUserSummary] { friendsList }
  func removeFriend(userId: String) async throws {}
  func friendRequests() async throws -> FriendRequestsResponse { requests }
  func sendFriendRequest(userId: String) async throws -> FriendRequest {
    sentTo.append(userId)
    return FriendRequest(id: "req-\(userId)", from: .me, to: SocialUserSummary(id: userId, username: userId), createdAt: .now)
  }
  func respond(to requestId: String, accept: Bool) async throws { responded.append((requestId, accept)) }
  func cancelFriendRequest(requestId: String) async throws {}
  func createInvite() async throws -> InviteLink { throw Failure() }
  func invitePreview(code: String) async throws -> SocialUserSummary { throw Failure() }
  func redeemInvite(code: String) async throws -> InviteRedeemResponse { throw Failure() }
  func privacy() async throws -> SocialPrivacySettings { .default }
  func updatePrivacy(_ settings: SocialPrivacySettings) async throws -> SocialPrivacySettings { settings }
  func blockedUsers() async throws -> [SocialUserSummary] { [] }
  func setBlocked(userId: String, blocked: Bool) async throws { blockCalls.append((userId, blocked)) }
  func report(_ request: ReportRequest) async throws { reports.append(request) }
}

private extension SocialUserSummary {
  static let me = SocialUserSummary(id: "me", username: "me")
  static let ana = SocialUserSummary(id: "ana", username: "ana", displayName: "Ana")
  static let bo = SocialUserSummary(id: "bo", username: "bo")
}

@MainActor
final class SocialStoreTests: XCTestCase {
  func testConfigFailureReadsAsDisabled() async {
    let service = MockSocialService()
    service.configResult = .failure(MockSocialService.Failure())
    let store = SocialStore(service: service)
    await store.loadConfig()
    XCTAssertFalse(store.config.enabled)
  }

  func testLoadSortsFriendsAndCountsIncomingRequests() async {
    let service = MockSocialService()
    service.friendsList = [.bo, .ana]
    service.requests = FriendRequestsResponse(
      incoming: [FriendRequest(id: "r1", from: .bo, to: .me, createdAt: .now)],
      outgoing: []
    )
    let store = SocialStore(service: service)
    await store.load()
    XCTAssertEqual(store.friends.map(\.id), ["ana", "bo"])
    XCTAssertEqual(store.badgeCount, 1)
    XCTAssertTrue(store.hasLoaded)
  }

  func testAddingSomeoneWhoAlreadyAskedAcceptsTheirRequest() async {
    let service = MockSocialService()
    service.requests = FriendRequestsResponse(
      incoming: [FriendRequest(id: "r1", from: .ana, to: .me, createdAt: .now)],
      outgoing: []
    )
    let store = SocialStore(service: service)
    await store.load()

    let ok = await store.sendRequest(to: .ana)

    XCTAssertTrue(ok)
    XCTAssertTrue(service.sentTo.isEmpty, "Must accept the pending request, not send a second one.")
    XCTAssertEqual(service.responded.first?.id, "r1")
    XCTAssertEqual(service.responded.first?.accept, true)
    XCTAssertEqual(store.status(of: "ana"), .friends)
    XCTAssertEqual(store.badgeCount, 0)
  }

  func testSendingARequestMarksItPending() async {
    let store = SocialStore(service: MockSocialService())
    await store.sendRequest(to: .bo)
    XCTAssertEqual(store.status(of: "bo"), .outgoingPending)
  }

  func testBlockingRemovesFriendshipAndRequests() async {
    let service = MockSocialService()
    service.friendsList = [.ana]
    service.requests = FriendRequestsResponse(
      incoming: [FriendRequest(id: "r1", from: .ana, to: .me, createdAt: .now)],
      outgoing: [FriendRequest(id: "r2", from: .me, to: .ana, createdAt: .now)]
    )
    let store = SocialStore(service: service)
    await store.load()

    await store.block(.ana)

    XCTAssertEqual(service.blockCalls.first?.id, "ana")
    XCTAssertEqual(service.blockCalls.first?.blocked, true)
    XCTAssertTrue(store.friends.isEmpty)
    XCTAssertTrue(store.incoming.isEmpty)
    XCTAssertTrue(store.outgoing.isEmpty)
    XCTAssertEqual(store.status(of: "ana"), .blocked)
  }

  func testReportDropsBlankNotes() async {
    let service = MockSocialService()
    let store = SocialStore(service: service)
    let ok = await store.report(userID: "bo", reason: .spam, note: "   ")
    XCTAssertTrue(ok)
    XCTAssertEqual(service.reports.first?.targetType, .user)
    XCTAssertNil(service.reports.first?.note)
  }

  func testResetClearsTheGraph() async {
    let service = MockSocialService()
    service.friendsList = [.ana]
    let store = SocialStore(service: service)
    await store.load()
    store.reset()
    XCTAssertTrue(store.friends.isEmpty)
    XCTAssertFalse(store.hasLoaded)
  }

  func testUnknownFriendshipStatusDecodesAsNone() throws {
    let json = Data(#"{"id":"x","username":"x","friendshipStatus":"super_friends"}"#.utf8)
    let user = try JSONDecoder.stockPlanShared.decode(SocialUserSummary.self, from: json)
    XCTAssertEqual(user.friendshipStatus, .none)
  }

  func testPrivacyDefaultsKeepReturnPercentPrivate() {
    XCTAssertFalse(SocialPrivacySettings.default.showReturnPercent)
  }
}
