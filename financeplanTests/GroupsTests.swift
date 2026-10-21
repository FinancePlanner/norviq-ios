import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

private final class MockGroupsService: GroupsServicing, @unchecked Sendable {
  struct Failure: LocalizedError {
    var errorDescription: String? { "Offline" }
  }

  var me = UUID()
  var page = GroupMessagePage(items: [], hasMoreBefore: false, hasMoreAfter: false, lastReadSeq: 0)
  var afterPages: [GroupMessagePage] = []
  var sendResult: (SendGroupMessageRequest) throws -> GroupMessage = { _ in throw Failure() }
  /// Runs before a send answers; lets a test deliver the echo first.
  var beforeSendReturns: (() async -> Void)?
  var sent: [SendGroupMessageRequest] = []
  var markedRead: [Int64] = []
  var list = GroupListResponse(items: [], pendingInvitationCount: 0)

  func myGroups() async throws -> GroupListResponse { list }
  func create(_ request: CreateGroupRequest) async throws -> GroupDetail { throw Failure() }
  func discover(query: String?, ticker: String?, tickers: [String], cursor: String?) async throws -> GroupDirectoryPage {
    GroupDirectoryPage(items: [], nextCursor: nil)
  }
  func unreadCount() async throws -> GroupUnreadCount { GroupUnreadCount(total: 0, pendingInvitationCount: 0) }
  func group(id: UUID) async throws -> GroupDetail { throw Failure() }
  func update(groupId: UUID, _ request: UpdateGroupRequest) async throws -> GroupDetail { throw Failure() }
  func delete(groupId: UUID) async throws {}
  func join(groupId: UUID) async throws -> GroupDetail { throw Failure() }
  func leave(groupId: UUID) async throws {}
  func setPushEnabled(groupId: UUID, _ enabled: Bool) async throws -> GroupMembership { throw Failure() }
  func members(groupId: UUID, cursor: String?) async throws -> GroupMemberPage { GroupMemberPage(items: [], nextCursor: nil) }
  func setRole(groupId: UUID, userId: UUID, role: GroupRole) async throws {}
  func kick(groupId: UUID, userId: UUID) async throws {}
  func ban(groupId: UUID, userId: UUID) async throws {}
  func transferOwnership(groupId: UUID, to userId: UUID) async throws {}
  func createChannel(groupId: UUID, _ request: CreateGroupChannelRequest) async throws -> GroupChannel { throw Failure() }
  func updateChannel(id: UUID, _ request: UpdateGroupChannelRequest) async throws -> GroupChannel { throw Failure() }
  func deleteChannel(id: UUID) async throws {}
  func messages(channelId: UUID, before: Int64?, after: Int64?, limit: Int?) async throws -> GroupMessagePage {
    if after != nil { return afterPages.isEmpty ? .empty : afterPages.removeFirst() }
    return page
  }
  func send(channelId: UUID, _ request: SendGroupMessageRequest) async throws -> GroupMessage {
    sent.append(request)
    await beforeSendReturns?()
    return try sendResult(request)
  }
  func markRead(channelId: UUID, seq: Int64) async throws { markedRead.append(seq) }
  func deleteMessage(id: UUID) async throws {}
  func reportMessage(id: UUID, _ request: GroupMessageReportRequest) async throws {}
  func createInviteLink(groupId: UUID, _ request: CreateGroupInviteRequest) async throws -> GroupInviteLink { throw Failure() }
  func inviteFriends(groupId: UUID, userIds: [UUID]) async throws -> GroupDirectInvitationResponse {
    GroupDirectInvitationResponse(invitedUserIds: userIds)
  }
  func invitations() async throws -> GroupInvitationList { GroupInvitationList(items: []) }
  func acceptInvitation(id: UUID) async throws -> GroupDetail { throw Failure() }
  func declineInvitation(id: UUID) async throws {}
  func invitePreview(code: String) async throws -> GroupInvitePreview { throw Failure() }
  func redeemInvite(code: String) async throws -> GroupDetail { throw Failure() }
  func realtime() -> AsyncThrowingStream<GroupsRealtimeSignal, Error> { AsyncThrowingStream { $0.finish() } }
  func currentUserID() async -> UUID? { me }
}

private extension GroupMessagePage {
  static let empty = GroupMessagePage(items: [], hasMoreBefore: false, hasMoreAfter: false, lastReadSeq: 0)
}

private let groupID = UUID()
private let channelID = UUID()

private func message(
  seq: Int64,
  author: UUID = UUID(),
  username: String = "ana",
  body: String = "hi",
  clientMessageId: String? = nil,
  at date: Date = Date(timeIntervalSince1970: 1_800_000_000)
) -> GroupMessage {
  GroupMessage(
    id: UUID(),
    groupId: groupID,
    channelId: channelID,
    seq: seq,
    clientMessageId: clientMessageId,
    authorId: author,
    authorUsername: username,
    body: body,
    isDeleted: false,
    createdAt: date
  )
}

private func channel() -> GroupChannel {
  GroupChannel(
    id: channelID, groupId: groupID, name: "general", kind: .text, topic: nil, position: 0,
    lastSeq: 0, lastMessageAt: nil, lastReadSeq: 0, unreadCount: 0
  )
}

private func summary(unread: Int = 0) -> GroupSummary {
  GroupSummary(
    id: groupID, name: "Dividend club", description: "", iconEmoji: nil, topic: .community, ticker: nil,
    visibility: .private, memberCount: 2, defaultChannelId: channelID, lastMessageAt: nil, lastMessage: nil,
    unreadCount: unread, membership: GroupMembership(role: .member, pushEnabled: true, joinedAt: Date()),
    createdAt: Date()
  )
}

// MARK: - Config

final class GroupsConfigTests: XCTestCase {
  func testGroupsDefaultOffWhenTheServerDoesNotSendThem() throws {
    let json = Data(#"{"enabled":true,"contactsDiscovery":false,"xImport":false,"leaderboards":false,"messaging":false}"#.utf8)
    let config = try JSONDecoder().decode(SocialConfig.self, from: json)
    XCTAssertFalse(config.groups)
    XCTAssertFalse(config.groupsPublic)
    XCTAssertFalse(config.groupsEnabled)
  }

  func testGroupsNeedSocialOn() throws {
    let on = Data(#"{"enabled":true,"contactsDiscovery":false,"xImport":false,"leaderboards":false,"messaging":false,"groups":true,"groupsPublic":true}"#.utf8)
    let config = try JSONDecoder().decode(SocialConfig.self, from: on)
    XCTAssertTrue(config.groupsEnabled)
    XCTAssertTrue(config.groupsPublic)

    let socialOff = Data(#"{"enabled":false,"contactsDiscovery":false,"xImport":false,"leaderboards":false,"messaging":false,"groups":true}"#.utf8)
    XCTAssertFalse(try JSONDecoder().decode(SocialConfig.self, from: socialOff).groupsEnabled)
  }
}

// MARK: - SSE parser

final class SSELineParserTests: XCTestCase {
  /// `bytes.lines` drops the blank line that ends a frame, so frames must
  /// dispatch on their `data:` line.
  func testDispatchesOnDataLinesWithoutBlankLines() {
    var parser = SSELineParser()
    let lines = [
      "retry: 2000",
      "event: ready",
      #"data: {"type":"ready"}"#,
      ": ping",
      "event: message.created",
      #"data: {"type":"message.created"}"#,
      #"data: {"type":"other"}"#
    ]
    let output = lines.compactMap { parser.consume($0) }
    XCTAssertEqual(output, [
      .retry(milliseconds: 2000),
      .frame(event: "ready", data: #"{"type":"ready"}"#),
      .comment,
      .frame(event: "message.created", data: #"{"type":"message.created"}"#),
      .frame(event: "message", data: #"{"type":"other"}"#)
    ])
  }

  func testIgnoresIdsUnknownFieldsAndCarriageReturns() {
    var parser = SSELineParser()
    XCTAssertNil(parser.consume("id: 42"))
    XCTAssertNil(parser.consume("whatever: x"))
    XCTAssertNil(parser.consume("event: reconnect\r"))
    XCTAssertEqual(parser.consume("data:{}\r"), .frame(event: "reconnect", data: "{}"))
    XCTAssertNil(parser.consume("retry: soon"))
  }

  func testDecodesRealtimeEventsAndSkipsUnreadableOnes() throws {
    let created = message(seq: 7)
    let encoded = try JSONEncoder.stockPlanShared.encode(
      GroupRealtimeEvent(type: .messageCreated, groupId: groupID, channelId: channelID, message: created)
    )
    let data = try XCTUnwrap(String(bytes: encoded, encoding: .utf8))
    let event = try XCTUnwrap(GroupsRealtimeClient.decode(data))
    XCTAssertEqual(event.type, .messageCreated)
    XCTAssertEqual(event.message?.seq, 7)
    XCTAssertEqual(GroupsRealtimeClient.decode(#"{"type":"typing.started"}"#)?.type, .other)
    XCTAssertNil(GroupsRealtimeClient.decode("not json"))
  }

  func testBackoffUsesServerRetryThenDoublesToACap() {
    XCTAssertEqual(GroupsStore.backoff(failures: 0, serverRetry: .milliseconds(2000)), .milliseconds(2000))
    let first = GroupsStore.backoff(failures: 1, serverRetry: .seconds(2))
    XCTAssertGreaterThanOrEqual(first, .milliseconds(1600))
    XCTAssertLessThanOrEqual(first, .milliseconds(2400))
    XCTAssertLessThanOrEqual(GroupsStore.backoff(failures: 20, serverRetry: .seconds(2)), .seconds(36))
  }
}

// MARK: - Chat layout

final class GroupChatLayoutTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
  }

  func testGroupsRunsByAuthorWithinFiveMinutes() {
    let ana = UUID()
    let bo = UUID()
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let messages = [
      message(seq: 1, author: ana, at: start),
      message(seq: 2, author: ana, at: start.addingTimeInterval(60)),
      message(seq: 3, author: ana, at: start.addingTimeInterval(60 + 301)),
      message(seq: 4, author: bo, username: "bo", at: start.addingTimeInterval(400))
    ].map(GroupChatMessage.init)
    let headers = GroupChatLayout.rows(for: messages, unreadAfterSeq: nil, currentUserID: nil, calendar: calendar)
      .compactMap { row -> Bool? in
        if case let .message(_, showsHeader) = row { return showsHeader }
        return nil
      }
    XCTAssertEqual(headers, [true, false, true, true])
  }

  func testDaySeparatorsAndOneNewMessagesDivider() {
    let me = UUID()
    let day1 = Date(timeIntervalSince1970: 1_800_000_000)
    let day2 = day1.addingTimeInterval(86_400)
    let messages = [
      message(seq: 1, at: day1),
      message(seq: 2, author: me, at: day2),
      message(seq: 3, at: day2.addingTimeInterval(10)),
      message(seq: 4, at: day2.addingTimeInterval(20))
    ].map(GroupChatMessage.init)
    let rows = GroupChatLayout.rows(for: messages, unreadAfterSeq: 1, currentUserID: me, calendar: calendar)
    let shape = rows.map { row -> String in
      switch row {
      case .day: "day"
      case .newMessages: "new"
      case let .message(message, _): "m\(message.seq ?? 0)"
      }
    }
    // The divider skips the user's own message 2 and sits before 3.
    XCTAssertEqual(shape, ["day", "m1", "day", "m2", "new", "m3", "m4"])
    guard case let .message(afterDivider, showsHeader) = rows[5] else { return XCTFail("expected a message") }
    XCTAssertEqual(afterDivider.seq, 3)
    XCTAssertTrue(showsHeader, "the first message after the divider starts a new run")
  }

  func testNoDividerWhenEverythingIsRead() {
    let messages = [message(seq: 1), message(seq: 2)].map(GroupChatMessage.init)
    let rows = GroupChatLayout.rows(for: messages, unreadAfterSeq: 2, currentUserID: nil)
    XCTAssertFalse(rows.contains(.newMessages))
  }
}

// MARK: - Tickers

final class TickerChipParserTests: XCTestCase {
  func testFindsCashtags() {
    XCTAssertEqual(
      TickerChipParser.segments(in: "Long $aapl and $BRK.B."),
      [.text("Long "), .ticker("AAPL"), .text(" and "), .ticker("BRK.B"), .text(".")]
    )
  }

  func testLeavesMoneyAndWordsAlone() {
    XCTAssertEqual(TickerChipParser.tickers(in: "It cost $100, US$5 and a$b"), [])
    XCTAssertEqual(TickerChipParser.tickers(in: "$ABCDEFGHIJKLMN is too long"), [])
    XCTAssertEqual(TickerChipParser.tickers(in: "($NVDA) $TSLA-"), ["NVDA", "TSLA"])
  }

  func testLinksRoundTrip() throws {
    let url = try XCTUnwrap(TickerChipParser.url(for: "BRK.B"))
    XCTAssertEqual(TickerChipParser.symbol(from: url), "BRK.B")
    XCTAssertNil(TickerChipParser.symbol(from: URL(string: "https://norviq.org")!))
  }
}

// MARK: - Deep links and pushes

final class GroupDeepLinkTests: XCTestCase {
  private func parse(_ link: String) -> GroupDeepLink? {
    URL(string: link).flatMap(GroupDeepLink.parse)
  }

  func testParsesEveryGroupLink() {
    let group = UUID()
    let channel = UUID()
    XCTAssertEqual(
      parse("financeplan://groups/\(group.uuidString)/channels/\(channel.uuidString)"),
      .channel(groupID: group, channelID: channel)
    )
    XCTAssertEqual(parse("financeplan://groups/\(group.uuidString)"), .group(group))
    XCTAssertEqual(parse("financeplan://groups/invitations"), .invitations)
    XCTAssertEqual(parse("financeplan://groups/join/aB3dE6gH9k"), .invite(code: "aB3dE6gH9k"))
    XCTAssertEqual(parse("https://norviq.org/g/aB3dE6gH9k"), .invite(code: "aB3dE6gH9k"))
    XCTAssertEqual(parse("https://www.norviq.org/g/aB3dE6gH9k"), .invite(code: "aB3dE6gH9k"))
  }

  func testRejectsOtherLinks() {
    XCTAssertNil(parse("https://norviq.org/i/aB3dE6gH9k"), "friend invites stay social")
    XCTAssertNil(parse("https://evil.example/g/aB3dE6gH9k"))
    XCTAssertNil(parse("financeplan://groups/join/..%2F"))
    XCTAssertNil(parse("financeplan://groups/not-a-uuid/channels/x"))
    XCTAssertNil(SocialDeepLink.parse(URL(string: "https://norviq.org/g/aB3dE6gH9k")!))
  }

  func testJoinSheetAcceptsLinksAndBareCodes() {
    XCTAssertEqual(GroupJoinSheet.code(from: " https://norviq.org/g/aB3dE6gH9k "), "aB3dE6gH9k")
    XCTAssertEqual(GroupJoinSheet.code(from: "norviq.org/g/aB3dE6gH9k"), "aB3dE6gH9k")
    XCTAssertEqual(GroupJoinSheet.code(from: "aB3dE6gH9k"), "aB3dE6gH9k")
    XCTAssertNil(GroupJoinSheet.code(from: "no"))
  }

  func testMessagePushOpensItsChannel() {
    let group = UUID()
    let channel = UUID()
    let route = PushNotificationPayloadParser.parse(userInfo: [
      "schemaVersion": 1,
      "type": "group_message",
      "groupId": group.uuidString,
      "channelId": channel.uuidString,
      "messageId": UUID().uuidString,
      "deepLink": "financeplan://groups/\(group.uuidString)/channels/\(channel.uuidString)"
    ])
    XCTAssertEqual(route?.kind, .groupMessage)
    XCTAssertEqual(route?.groupLink, .channel(groupID: group, channelID: channel))
  }

  func testPushesWithoutALinkFallBackToTheirIds() {
    let group = UUID()
    let channel = UUID()
    XCTAssertEqual(
      PushNotificationPayloadParser.parse(userInfo: [
        "type": "group_message", "groupId": group.uuidString, "channelId": channel.uuidString
      ])?.groupLink,
      .channel(groupID: group, channelID: channel)
    )
    XCTAssertEqual(PushNotificationPayloadParser.parse(userInfo: ["type": "group_invite"])?.groupLink, .invitations)
  }

  func testThreadNamesTheChannel() {
    let channel = UUID()
    XCTAssertEqual(GroupDeepLink.channelID(fromThread: "group-channel-\(channel.uuidString)"), channel)
    XCTAssertNil(GroupDeepLink.channelID(fromThread: "group-invites"))
  }
}

// MARK: - Chat model

@MainActor
final class GroupChatModelTests: XCTestCase {
  private func makeModel(_ service: MockGroupsService) -> GroupChatModel {
    GroupChatModel(groupID: groupID, channel: channel(), currentUserID: service.me, currentUsername: "me", service: service)
  }

  func testOptimisticSendIsReplacedInPlaceByTheServerCopy() async {
    let service = MockGroupsService()
    service.page = GroupMessagePage(items: [message(seq: 1)], hasMoreBefore: false, hasMoreAfter: false, lastReadSeq: 1)
    let model = makeModel(service)
    await model.load()

    service.sendResult = { request in
      message(seq: 2, author: service.me, username: "me", body: request.body, clientMessageId: request.clientMessageId)
    }
    model.send("  Ex-div on Friday  ")
    XCTAssertEqual(model.messages.count, 2)
    let pending = model.messages[1]
    XCTAssertTrue(pending.isPending)
    XCTAssertEqual(pending.state, .sending)
    XCTAssertEqual(pending.body, "Ex-div on Friday")

    await waitUntil { model.messages.last?.isPending == false }
    XCTAssertEqual(model.messages.map(\.seq), [1, 2])
    XCTAssertEqual(model.messages[1].id, pending.id, "the row keeps its identity across the swap")
    XCTAssertEqual(service.sent.first?.clientMessageId, pending.clientMessageId)
  }

  func testEchoBeforeTheResponseDoesNotDuplicate() async {
    let service = MockGroupsService()
    let model = makeModel(service)
    await model.load()
    var echo: GroupMessage?
    service.beforeSendReturns = { @MainActor in
      // The stream delivers the message before the POST returns.
      if let echo {
        model.apply(GroupRealtimeEvent(type: .messageCreated, groupId: groupID, channelId: channelID, message: echo))
      }
    }
    service.sendResult = { _ in try XCTUnwrap(echo) }
    model.send("hello")
    let clientMessageId = try? XCTUnwrap(model.messages.first?.clientMessageId)
    echo = message(seq: 1, author: service.me, username: "me", body: "hello", clientMessageId: clientMessageId)

    await waitUntil { model.messages.first?.isPending == false }
    XCTAssertEqual(model.messages.count, 1)
    XCTAssertEqual(model.messages.first?.seq, 1)
  }

  func testFailedSendCanBeRetriedWithTheSameClientId() async {
    let service = MockGroupsService()
    let model = makeModel(service)
    await model.load()
    model.send("first try")
    await waitUntil { if case .failed = model.messages.first?.state { return true } else { return false } }

    service.sendResult = { request in
      message(seq: 1, author: service.me, username: "me", body: request.body, clientMessageId: request.clientMessageId)
    }
    guard let failed = model.messages.first else { return XCTFail("expected the failed message") }
    model.retry(failed)
    await waitUntil { model.messages.first?.isPending == false }
    XCTAssertEqual(service.sent.count, 2)
    XCTAssertEqual(service.sent[0].clientMessageId, service.sent[1].clientMessageId)
  }

  func testRejectedContentIsRemovedWithANotice() async {
    let service = MockGroupsService()
    service.sendResult = { _ in
      throw GroupsHTTPClient.Error.coded(status: 422, code: "content_rejected", message: "That message breaks the community guidelines.")
    }
    let model = makeModel(service)
    await model.load()
    model.send("something awful")
    await waitUntil { model.notice != nil }
    XCTAssertTrue(model.messages.isEmpty)
    XCTAssertEqual(model.notice, "That message breaks the community guidelines.")
  }

  func testCatchUpFetchesEverythingAfterTheNewestMessage() async {
    let service = MockGroupsService()
    service.page = GroupMessagePage(items: [message(seq: 1)], hasMoreBefore: false, hasMoreAfter: false, lastReadSeq: 1)
    let model = makeModel(service)
    await model.load()
    service.afterPages = [
      GroupMessagePage(items: [message(seq: 2), message(seq: 3)], hasMoreBefore: true, hasMoreAfter: true, lastReadSeq: 1),
      GroupMessagePage(items: [message(seq: 4)], hasMoreBefore: true, hasMoreAfter: false, lastReadSeq: 1)
    ]
    await model.catchUp()
    XCTAssertEqual(model.messages.map(\.seq), [1, 2, 3, 4])
  }

  func testDeleteEventLeavesATombstone() async {
    let service = MockGroupsService()
    let held = message(seq: 1)
    service.page = GroupMessagePage(items: [held], hasMoreBefore: false, hasMoreAfter: false, lastReadSeq: 1)
    let model = makeModel(service)
    await model.load()
    model.apply(GroupRealtimeEvent(type: .messageDeleted, groupId: groupID, channelId: channelID, messageId: held.id, seq: 1))
    XCTAssertEqual(model.messages.first?.isDeleted, true)
    XCTAssertNil(model.messages.first?.body)
  }

  func testMarkReadMovesOnlyForward() async {
    let service = MockGroupsService()
    service.page = GroupMessagePage(items: [message(seq: 1), message(seq: 2)], hasMoreBefore: false, hasMoreAfter: false, lastReadSeq: 0)
    let model = makeModel(service)
    await model.load()
    await model.markRead()
    await model.markRead()
    XCTAssertEqual(service.markedRead, [2])
  }

  private func waitUntil(_ condition: @MainActor () -> Bool) async {
    for _ in 0..<100 where !condition() {
      try? await Task.sleep(for: .milliseconds(10))
    }
  }
}

// MARK: - Store

@MainActor
final class GroupsStoreTests: XCTestCase {
  func testLiveMessagesCountUnreadExceptOwnAndOnScreen() async {
    let service = MockGroupsService()
    service.list = GroupListResponse(items: [summary()], pendingInvitationCount: 1)
    let store = GroupsStore(service: service, defaults: Self.defaults())
    await store.load()
    XCTAssertEqual(store.badgeCount, 1)

    await store.handle(GroupRealtimeEvent(type: .messageCreated, groupId: groupID, channelId: channelID, message: message(seq: 1)))
    XCTAssertEqual(store.unreadCount, 1)
    XCTAssertEqual(store.groups.first?.lastMessage?.excerpt, "hi")

    await store.handle(GroupRealtimeEvent(
      type: .messageCreated, groupId: groupID, channelId: channelID, message: message(seq: 2, author: service.me)
    ))
    XCTAssertEqual(store.unreadCount, 1, "the user's own message isn't unread")

    let chat = GroupChatModel(groupID: groupID, channel: channel(), currentUserID: service.me, service: service)
    let token = store.chatDidAppear(chat)
    XCTAssertTrue(store.isViewing(channelID: channelID))
    await store.handle(GroupRealtimeEvent(type: .messageCreated, groupId: groupID, channelId: channelID, message: message(seq: 3)))
    XCTAssertEqual(store.unreadCount, 1, "a message on screen isn't unread")
    XCTAssertEqual(chat.messages.map(\.seq), [3], "and it reaches the open chat")
    XCTAssertEqual(store.lastViewedChannel(in: groupID), channelID)

    store.chatDidDisappear(token: token)
    XCTAssertFalse(store.isViewing(channelID: channelID))
  }

  private static func defaults() -> UserDefaults {
    UserDefaults(suiteName: "GroupsStoreTests.\(UUID().uuidString)") ?? .standard
  }

  func testRemovalDropsTheGroup() async {
    let service = MockGroupsService()
    service.list = GroupListResponse(items: [summary(unread: 3)], pendingInvitationCount: 0)
    let store = GroupsStore(service: service, defaults: Self.defaults())
    await store.load()
    await store.handle(GroupRealtimeEvent(type: .membershipRemoved, groupId: groupID, reason: .kicked))
    XCTAssertTrue(store.groups.isEmpty)
    XCTAssertEqual(store.removedGroupID, groupID)
  }
}
