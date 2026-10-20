import Factory
import Foundation
import Observation
import StockPlanShared

/// One open channel: its messages, sending, paging and the read marker.
///
/// Sending is optimistic. A message shows at once as pending, keyed by its
/// `clientMessageId`; the server's answer, or its echo on the live stream,
/// whichever lands first, replaces it in place. A retry reuses the same id,
/// so the server never posts it twice.
@MainActor
@Observable
final class GroupChatModel {
  let groupID: UUID
  private(set) var channel: GroupChannel
  private(set) var messages: [GroupChatMessage] = []
  private(set) var hasMoreBefore = false
  private(set) var isLoading = false
  private(set) var hasLoaded = false
  /// The read marker when the channel opened; where "New messages" goes.
  private(set) var unreadAfterSeq: Int64?
  private(set) var lastReadSeq: Int64 = 0
  var errorMessage: String?
  /// A short notice that clears itself, e.g. a message the filter refused.
  var notice: String?

  private let service: any GroupsServicing
  private(set) var currentUserID: UUID?
  private let currentUsername: String?
  private var markReadTask: Task<Void, Never>?
  /// Called after the read marker moves, so the store can clear unreads.
  var onRead: ((UUID, Int64) -> Void)?

  static let pageSize = 50
  static let markReadDelay: Duration = .milliseconds(600)

  init(
    groupID: UUID,
    channel: GroupChannel,
    currentUserID: UUID? = nil,
    currentUsername: String? = nil,
    service: any GroupsServicing = Container.shared.groupsService()
  ) {
    self.groupID = groupID
    self.channel = channel
    self.currentUserID = currentUserID
    self.currentUsername = currentUsername
    self.service = service
  }

  var channelID: UUID { channel.id }

  func rows() -> [GroupChatRow] {
    GroupChatLayout.rows(for: messages, unreadAfterSeq: unreadAfterSeq, currentUserID: currentUserID)
  }

  // MARK: Loading

  func load() async {
    if currentUserID == nil { currentUserID = await service.currentUserID() }
    isLoading = true
    defer { isLoading = false }
    do {
      let page = try await service.messages(channelId: channelID, before: nil, after: nil, limit: Self.pageSize)
      let pending = messages.filter(\.isPending)
      messages = page.items.map(GroupChatMessage.init) + pending
      hasMoreBefore = page.hasMoreBefore
      lastReadSeq = page.lastReadSeq
      if unreadAfterSeq == nil { unreadAfterSeq = page.lastReadSeq }
      hasLoaded = true
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func loadOlder() async {
    guard hasMoreBefore, !isLoading, let first = messages.first(where: { !$0.isPending })?.seq else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      let page = try await service.messages(channelId: channelID, before: first, after: nil, limit: Self.pageSize)
      for message in page.items { merge(GroupChatMessage(message)) }
      hasMoreBefore = page.hasMoreBefore
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Fetches everything after the newest message held, after a reconnect or
  /// a return from the background. Seqs have no gaps, so this misses nothing.
  func catchUp() async {
    guard hasLoaded, let last = lastConfirmedSeq else {
      await load()
      return
    }
    var after = last
    do {
      while true {
        let page = try await service.messages(channelId: channelID, before: nil, after: after, limit: 100)
        for message in page.items { merge(GroupChatMessage(message)) }
        guard page.hasMoreAfter, let newest = page.items.last?.seq else { break }
        after = newest
      }
    } catch {
      // The next ready event tries again; the messages held stay on screen.
    }
  }

  var lastConfirmedSeq: Int64? {
    messages.last(where: { !$0.isPending })?.seq
  }

  // MARK: Sending

  func send(_ text: String) {
    let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !body.isEmpty else { return }
    let clientMessageId = UUID().uuidString.lowercased()
    messages.append(
      GroupChatMessage(pendingBody: body, clientMessageId: clientMessageId, authorId: currentUserID, authorUsername: currentUsername)
    )
    Task { await deliver(body: body, clientMessageId: clientMessageId) }
  }

  func retry(_ message: GroupChatMessage) {
    guard case .failed = message.state, let clientMessageId = message.clientMessageId, let body = message.body else { return }
    setState(.sending, for: message.id)
    Task { await deliver(body: body, clientMessageId: clientMessageId) }
  }

  func discard(_ message: GroupChatMessage) {
    guard message.isPending else { return }
    messages.removeAll { $0.id == message.id }
  }

  func deliver(body: String, clientMessageId: String) async {
    let id = GroupChatMessage.identity(authorId: currentUserID, clientMessageId: clientMessageId, serverID: nil)
    do {
      let sent = try await service.send(
        channelId: channelID,
        SendGroupMessageRequest(clientMessageId: clientMessageId, body: body)
      )
      merge(GroupChatMessage(sent))
      scheduleMarkRead()
    } catch let error as GroupsHTTPClient.Error where error.code == "content_rejected" {
      // Nothing to retry: the same text would be refused again.
      messages.removeAll { $0.id == id }
      notice = error.errorDescription ?? String(localized: "That message can't be sent.")
    } catch {
      setState(.failed(error.localizedDescription), for: id)
    }
  }

  private func setState(_ state: GroupChatMessage.DeliveryState, for id: String) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    messages[index].state = state
  }

  // MARK: Merging

  /// Adds or replaces a server message. A pending row with the same
  /// `clientMessageId` becomes the confirmed one in place; an echo of a
  /// message already held changes nothing.
  func merge(_ message: GroupChatMessage) {
    messages.removeAll { existing in
      existing.id == message.id || (message.serverID != nil && existing.serverID == message.serverID)
    }
    guard let seq = message.seq else {
      messages.append(message)
      return
    }
    let firstPending = messages.firstIndex(where: \.isPending) ?? messages.endIndex
    let index = messages[..<firstPending].firstIndex(where: { ($0.seq ?? .max) > seq }) ?? firstPending
    messages.insert(message, at: index)
  }

  func apply(_ event: GroupRealtimeEvent) {
    guard event.channelId == channelID || event.message?.channelId == channelID else { return }
    switch event.type {
    case .messageCreated:
      guard let message = event.message else { return }
      merge(GroupChatMessage(message))
    case .messageDeleted:
      guard let messageID = event.messageId else { return }
      tombstone(messageID)
    case .channelRead:
      if let seq = event.seq { lastReadSeq = max(lastReadSeq, seq) }
    case .channelUpdated:
      if let updated = event.channel { channel = updated }
    default:
      break
    }
  }

  private func tombstone(_ messageID: UUID) {
    guard let index = messages.firstIndex(where: { $0.serverID == messageID }), let seq = messages[index].seq else { return }
    let held = messages[index]
    messages[index] = GroupChatMessage(
      GroupMessage(
        id: messageID,
        groupId: groupID,
        channelId: channelID,
        seq: seq,
        clientMessageId: held.clientMessageId,
        authorId: held.authorId,
        authorUsername: held.authorUsername,
        body: nil,
        isDeleted: true,
        createdAt: held.createdAt
      )
    )
  }

  // MARK: Moderation

  func delete(_ message: GroupChatMessage) async {
    guard let id = message.serverID else { return }
    do {
      try await service.deleteMessage(id: id)
      tombstone(id)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Drops everything by a user the viewer just blocked.
  func hideMessages(by username: String) {
    messages.removeAll { $0.authorUsername == username }
  }

  // MARK: Read marker

  /// Moves the read marker to the newest message after a short pause, so a
  /// burst of messages costs one request.
  func scheduleMarkRead() {
    markReadTask?.cancel()
    markReadTask = Task { [weak self] in
      try? await Task.sleep(for: Self.markReadDelay)
      guard !Task.isCancelled else { return }
      await self?.markRead()
    }
  }

  func markRead() async {
    guard let seq = lastConfirmedSeq, seq > lastReadSeq else { return }
    do {
      try await service.markRead(channelId: channelID, seq: seq)
      lastReadSeq = seq
      onRead?(channelID, seq)
    } catch {
      // Unread counts stay as they were; the next view retries.
    }
  }

  func stop() {
    markReadTask?.cancel()
  }
}
