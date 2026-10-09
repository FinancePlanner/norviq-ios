import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

private final class MockBoardsService: BoardsServicing, @unchecked Sendable {
  struct Failure: LocalizedError {
    var errorDescription: String? { "That board address is taken." }
  }

  var viewerStatus = CommunityViewerStatus(username: "me", isAdmin: false, guidelinesAccepted: true, hasUsername: true, activeSanction: nil)
  var page = BoardPostPage(items: [], nextCursor: nil)
  var voteResult = BoardVoteResponse(score: 1, voted: true)
  var createBoardFails = false
  var acceptedGuidelines = false
  struct Query {
    let sort: BoardPostSort
    let kind: BoardPostKind?
    let tag: String?
  }

  var lastQuery: Query?
  var deleted: [UUID] = []

  func viewer() async throws -> CommunityViewerStatus { viewerStatus }
  func acceptGuidelines() async throws {
    acceptedGuidelines = true
    viewerStatus = CommunityViewerStatus(username: "me", isAdmin: false, guidelinesAccepted: true, hasUsername: true, activeSanction: nil)
  }
  func block(username: String) async throws {}
  func boards(cursor: String?) async throws -> BoardListResponse { BoardListResponse(items: [], nextCursor: nil) }
  func createBoard(_ request: CreateBoardRequest) async throws -> BoardSummary {
    if createBoardFails { throw Failure() }
    return .fixture(slug: request.slug)
  }
  func posts(slug: String, sort: BoardPostSort, kind: BoardPostKind?, tag: String?, cursor: String?) async throws -> BoardPostPage {
    lastQuery = Query(sort: sort, kind: kind, tag: tag)
    return page
  }
  func createPost(slug: String, _ request: CreateBoardPostRequest) async throws -> BoardPostSummary { .fixture() }
  func post(id: UUID) async throws -> BoardPostDetail { BoardPostDetail(post: .fixture(id: id), body: nil, comments: []) }
  func deletePost(id: UUID) async throws { deleted.append(id) }
  func vote(postId: UUID) async throws -> BoardVoteResponse { voteResult }
  func comment(postId: UUID, _ request: CreateBoardCommentRequest) async throws -> BoardComment { .fixture(id: UUID(), parent: nil) }
  func deleteComment(id: UUID) async throws {}
  func report(_ request: BoardReportRequest) async throws {}
  func deleteBoard(slug: String) async throws {}
  func sanction(_ request: CreateSanctionRequest) async throws -> UserSanction { throw Failure() }

  var notificationPage = BoardNotificationPage(items: [], nextCursor: nil, unreadCount: 0)
  var markedRead: [[UUID]?] = []
  var savedSettings: [BoardNotificationSettings] = []
  /// Runs before a settings save answers; lets a test hold one save open.
  var beforeSettingsSave: ((BoardNotificationSettings) async throws -> Void)?
  var notificationsFail = false
  func notifications(cursor: String?) async throws -> BoardNotificationPage {
    if notificationsFail { throw Failure() }
    return notificationPage
  }
  func unreadCount() async throws -> Int { notificationPage.unreadCount }
  func markRead(ids: [UUID]?) async throws { markedRead.append(ids) }
  func notificationSettings() async throws -> BoardNotificationSettings { savedSettings.last ?? .default }
  func updateNotificationSettings(_ settings: BoardNotificationSettings) async throws -> BoardNotificationSettings {
    try await beforeSettingsSave?(settings)
    savedSettings.append(settings)
    return settings
  }
}

private extension BoardSummary {
  static func fixture(slug: String = "dca") -> BoardSummary {
    BoardSummary(id: UUID(), slug: slug, name: "DCA", description: "", creatorUsername: "me", postCount: 0, createdAt: .now, lastActivityAt: .now)
  }
}

private extension BoardPostSummary {
  static func fixture(id: UUID = UUID(), author: String = "ana", url: String? = nil) -> BoardPostSummary {
    BoardPostSummary(
      id: id, boardSlug: "dca", kind: .link, title: "Why I DCA", url: url, domain: nil, tags: [],
      authorUsername: author, createdAt: .now, score: 0, commentCount: 0, participantCount: 1, viewCount: 0,
      viewerHasVoted: false, newCommentCount: nil
    )
  }
}

private extension BoardComment {
  static func fixture(id: UUID, parent: UUID?, depth: Int = 0) -> BoardComment {
    BoardComment(id: id, parentId: parent, depth: depth, authorUsername: "ana", body: "hi", createdAt: .now, isDeleted: false)
  }
}

private func sanction(_ kind: CommunitySanctionKind) -> UserSanction {
  UserSanction(id: UUID(), username: "me", kind: kind, reason: "test", expiresAt: nil, createdAt: .now, revokedAt: nil)
}

@MainActor
final class BoardThreadTests: XCTestCase {
  func testRepliesFollowTheirParentAndOrphansBecomeRoots() {
    let a = UUID(), b = UUID(), c = UUID(), d = UUID()
    let rows = BoardThread.rows(for: [
      .fixture(id: a, parent: nil),
      .fixture(id: b, parent: nil),
      .fixture(id: c, parent: a, depth: 1),
      .fixture(id: d, parent: UUID(), depth: 4)
    ])
    XCTAssertEqual(rows.map(\.id), [a, c, b, d])
    XCTAssertEqual(rows.map(\.depth), [0, 1, 0, 0])
  }

  func testSuggestedSlugIsLowercaseDashedAndBounded() {
    XCTAssertEqual(CreateBoardSheet.suggestedSlug(from: "Dividend Investing!"), "dividend-investing")
    XCTAssertEqual(CreateBoardSheet.suggestedSlug(from: "Ações & ETFs"), "acoes-etfs")
    XCTAssertEqual(CreateBoardSheet.suggestedSlug(from: String(repeating: "a", count: 40)).count, 32)
  }

  func testOnlyHTTPLinksOpen() {
    XCTAssertNotNil(BoardPostSummary.fixture(url: "https://example.com").openableURL)
    XCTAssertNil(BoardPostSummary.fixture(url: "javascript:alert(1)").openableURL)
    XCTAssertNil(BoardPostSummary.fixture(url: nil).openableURL)
  }
}

@MainActor
final class BoardsModelTests: XCTestCase {
  func testViewerStateFollowsTheSanction() async {
    let service = MockBoardsService()
    let store = BoardsViewerStore(service: service)
    await store.load()
    XCTAssertTrue(store.canWrite)
    XCTAssertEqual(store.username, "me")

    service.viewerStatus = CommunityViewerStatus(username: "me", isAdmin: false, guidelinesAccepted: true, hasUsername: true, activeSanction: sanction(.mute))
    await store.load()
    XCTAssertTrue(store.isMuted)
    XCTAssertFalse(store.canWrite)
    XCTAssertFalse(store.isBanned)

    service.viewerStatus = CommunityViewerStatus(username: "me", isAdmin: false, guidelinesAccepted: true, hasUsername: true, activeSanction: sanction(.ban))
    await store.load()
    XCTAssertTrue(store.isBanned)
  }

  func testAcceptingGuidelinesUnlocksWriting() async {
    let service = MockBoardsService()
    service.viewerStatus = CommunityViewerStatus(username: "me", isAdmin: false, guidelinesAccepted: false, hasUsername: true, activeSanction: nil)
    let store = BoardsViewerStore(service: service)
    await store.load()
    XCTAssertTrue(store.needsGuidelines)
    XCTAssertFalse(store.canWrite)
    await store.acceptGuidelines()
    XCTAssertTrue(service.acceptedGuidelines)
    XCTAssertTrue(store.canWrite)
  }

  func testVoteUpdatesTheRowFromTheServer() async {
    let service = MockBoardsService()
    let post = BoardPostSummary.fixture()
    service.page = BoardPostPage(items: [post], nextCursor: nil)
    service.voteResult = BoardVoteResponse(score: 7, voted: true)
    let model = BoardFeedModel(board: .fixture(), service: service)
    await model.load()
    await model.vote(post)
    XCTAssertEqual(model.posts.first?.score, 7)
    XCTAssertEqual(model.posts.first?.viewerHasVoted, true)
  }

  func testFiltersReachTheServerAndKindToggles() async {
    let service = MockBoardsService()
    let model = BoardFeedModel(board: .fixture(), service: service)
    model.sort = .top
    await model.toggleKind(.ask)
    XCTAssertEqual(service.lastQuery?.sort, .top)
    XCTAssertEqual(service.lastQuery?.kind, .ask)
    await model.toggleKind(.ask)
    XCTAssertNil(service.lastQuery?.kind)
  }

  func testBlockingHidesThatAuthorsPosts() async {
    let service = MockBoardsService()
    service.page = BoardPostPage(items: [.fixture(author: "ana"), .fixture(author: "bo")], nextCursor: nil)
    let model = BoardFeedModel(board: .fixture(), service: service)
    await model.load()
    model.hidePosts(by: "ana")
    XCTAssertEqual(model.posts.map(\.authorUsername), ["bo"])
  }

  func testCreateBoardFailureKeepsTheServerReason() async {
    let service = MockBoardsService()
    service.createBoardFails = true
    let model = BoardsDirectoryModel(service: service)
    let created = await model.create(slug: "dca", name: "DCA", description: "")
    XCTAssertNil(created)
    XCTAssertEqual(model.errorMessage, "That board address is taken.")
  }
}

private func notification(_ kind: BoardNotificationKind, read: Bool) -> BoardNotification {
  BoardNotification(
    id: UUID(), kind: kind, actorUsername: "bo", postId: UUID(), boardSlug: "dca", postTitle: "Why I DCA",
    commentId: nil, excerpt: nil, createdAt: .now, isRead: read
  )
}

@MainActor
final class BoardsNotificationsTests: XCTestCase {
  func testBoardPushParsesToABoardRouteWithItsPost() {
    let postID = UUID().uuidString
    let route = PushNotificationPayloadParser.parse(userInfo: ["type": "board_reply", "postId": postID, "boardSlug": "dca"])
    XCTAssertEqual(route?.kind, .boardReply)
    XCTAssertEqual(route?.boardPostID, postID)
    XCTAssertEqual(PushNotificationPayloadParser.parse(userInfo: ["type": "board_upvote", "postId": postID])?.kind, .boardUpvote)
    XCTAssertNil(PushNotificationPayloadParser.parse(userInfo: ["type": "board_reply"]), "a board push without a post is dropped")
    XCTAssertNil(PushNotificationPayloadParser.parse(userInfo: ["type": "board_reply", "postId": "../x"]))
  }

  func testBoardDeepLinkParsesOnlyPostLinks() throws {
    let id = UUID()
    XCTAssertEqual(BoardDeepLink.postID(from: try XCTUnwrap(URL(string: "financeplan://boards/dca/posts/\(id.uuidString)"))), id)
    XCTAssertNil(BoardDeepLink.postID(from: try XCTUnwrap(URL(string: "financeplan://boards/dca"))))
    XCTAssertNil(BoardDeepLink.postID(from: try XCTUnwrap(URL(string: "https://norviq.org/boards/dca/posts/\(id.uuidString)"))))
  }

  func testActivityHighlightsUnreadMarksAllReadAndDropsUnknownKinds() async {
    let service = MockBoardsService()
    let unread = notification(.reply, read: false)
    service.notificationPage = BoardNotificationPage(
      items: [unread, notification(.upvote, read: true), notification(.other, read: false)],
      nextCursor: nil,
      unreadCount: 2
    )
    let model = BoardsActivityModel(service: service)
    await model.load()
    XCTAssertEqual(model.items.count, 2, "unknown kinds are not rendered")
    XCTAssertTrue(model.highlighted.contains(unread.id))
    XCTAssertEqual(service.markedRead.count, 1)
    XCTAssertNil(service.markedRead.first ?? [UUID()], "marks everything read")
  }

  func testSavingSettingsKeepsTheServerAnswer() async {
    let service = MockBoardsService()
    let model = BoardsActivityModel(service: service)
    await model.save(BoardNotificationSettings(replyPush: true, upvotePush: false))
    XCTAssertEqual(model.settings, BoardNotificationSettings(replyPush: true, upvotePush: false))
    XCTAssertEqual(service.savedSettings.count, 1)
  }

  func testAnEarlierSaveFailingAfterALaterOneDoesNotUndoIt() async {
    let service = MockBoardsService()
    let first = BoardNotificationSettings(replyPush: false, upvotePush: true)
    let second = BoardNotificationSettings(replyPush: false, upvotePush: false)
    var heldSave: CheckedContinuation<Void, Error>?
    service.beforeSettingsSave = { settings in
      guard settings == first else { return }
      try await withCheckedThrowingContinuation { heldSave = $0 }
    }
    let model = BoardsActivityModel(service: service)

    let firstSave = Task { await model.save(first) }
    while heldSave == nil { await Task.yield() }
    await model.save(second)
    heldSave?.resume(throwing: MockBoardsService.Failure())
    await firstSave.value

    XCTAssertEqual(model.settings, second, "the older save's rollback must not overwrite the newer choice")
    XCTAssertNil(model.errorMessage, "a superseded save has nothing left to report")
  }

  func testAFailedNextPageIsReported() async {
    let service = MockBoardsService()
    service.notificationPage = BoardNotificationPage(items: [notification(.reply, read: true)], nextCursor: "next", unreadCount: 0)
    let model = BoardsActivityModel(service: service)
    await model.load()
    service.notificationsFail = true
    await model.loadMore()
    XCTAssertNotNil(model.errorMessage)
  }

  func testViewerStoreOpensAPendingPost() async {
    let store = BoardsViewerStore(service: MockBoardsService())
    let id = UUID()
    store.open(postID: id)
    XCTAssertEqual(store.pendingPost?.id, id)
  }
}
