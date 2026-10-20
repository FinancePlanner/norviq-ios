import Foundation
import StockPlanShared

/// A message as the chat shows it: confirmed by the server, or still on its
/// way. Identity is the author's `clientMessageId` when there is one, so the
/// row keeps its place when the server's copy replaces the pending one.
nonisolated struct GroupChatMessage: Identifiable, Equatable, Sendable {
  enum DeliveryState: Equatable, Sendable {
    case sent
    case sending
    case failed(String)
  }

  let id: String
  /// Nil until the server has assigned one.
  let seq: Int64?
  let serverID: UUID?
  let clientMessageId: String?
  let authorId: UUID?
  let authorUsername: String?
  let body: String?
  let isDeleted: Bool
  let createdAt: Date
  var state: DeliveryState

  init(_ message: GroupMessage) {
    self.id = Self.identity(authorId: message.authorId, clientMessageId: message.clientMessageId, serverID: message.id)
    self.seq = message.seq
    self.serverID = message.id
    self.clientMessageId = message.clientMessageId
    self.authorId = message.authorId
    self.authorUsername = message.authorUsername
    self.body = message.body
    self.isDeleted = message.isDeleted
    self.createdAt = message.createdAt
    self.state = .sent
  }

  /// A message the user just wrote, before the server has answered.
  init(pendingBody body: String, clientMessageId: String, authorId: UUID?, authorUsername: String?, createdAt: Date = Date()) {
    self.id = Self.identity(authorId: authorId, clientMessageId: clientMessageId, serverID: nil)
    self.seq = nil
    self.serverID = nil
    self.clientMessageId = clientMessageId
    self.authorId = authorId
    self.authorUsername = authorUsername
    self.body = body
    self.isDeleted = false
    self.createdAt = createdAt
    self.state = .sending
  }

  static func identity(authorId: UUID?, clientMessageId: String?, serverID: UUID?) -> String {
    if let clientMessageId {
      return "\(authorId?.uuidString ?? "me")/\(clientMessageId)"
    }
    return serverID?.uuidString ?? UUID().uuidString
  }

  var isPending: Bool { seq == nil }
}

/// One row of the chat list.
nonisolated enum GroupChatRow: Identifiable, Equatable, Sendable {
  case day(Date)
  case newMessages
  /// `showsHeader`: the first of a run by one author, so it shows name and time.
  case message(GroupChatMessage, showsHeader: Bool)

  var id: String {
    switch self {
    case let .day(date): "day-\(Int(date.timeIntervalSince1970))"
    case .newMessages: "new-messages"
    case let .message(message, _): message.id
    }
  }
}

/// Turns messages (oldest first) into chat rows: a separator for each day,
/// one "New messages" divider, and messages grouped into runs.
nonisolated enum GroupChatLayout {
  /// Messages by one author closer together than this share a header.
  static let groupingWindow: TimeInterval = 5 * 60

  /// `unreadAfterSeq`: the read marker when the channel was opened. The
  /// divider goes before the first later message by someone else.
  static func rows(
    for messages: [GroupChatMessage],
    unreadAfterSeq: Int64?,
    currentUserID: UUID?,
    calendar: Calendar = .current
  ) -> [GroupChatRow] {
    var rows: [GroupChatRow] = []
    var previous: GroupChatMessage?
    var placedDivider = false

    for message in messages {
      let day = calendar.startOfDay(for: message.createdAt)
      let isNewDay = previous.map { calendar.startOfDay(for: $0.createdAt) != day } ?? true
      if isNewDay { rows.append(.day(day)) }

      var dividerHere = false
      if !placedDivider, let unreadAfterSeq, let seq = message.seq, seq > unreadAfterSeq,
         message.authorId == nil || message.authorId != currentUserID {
        rows.append(.newMessages)
        placedDivider = true
        dividerHere = true
      }

      let continuesRun = previous.map {
        !isNewDay && !dividerHere
          && $0.authorId == message.authorId
          && $0.authorUsername == message.authorUsername
          && message.createdAt.timeIntervalSince($0.createdAt) < groupingWindow
      } ?? false
      rows.append(.message(message, showsHeader: !continuesRun))
      previous = message
    }
    return rows
  }
}
