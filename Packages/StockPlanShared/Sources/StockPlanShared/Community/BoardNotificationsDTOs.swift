import Foundation

/// What happened. Decodes any value it doesn't know as `.other`, so adding a
/// kind on the server never breaks an older client's whole feed — the mistake
/// `NotificationEventKind` cannot undo.
public enum BoardNotificationKind: String, Codable, CaseIterable, Sendable {
    /// Someone replied to your post or to your comment.
    case reply
    /// Someone upvoted your post.
    case upvote
    case other

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = BoardNotificationKind(rawValue: raw) ?? .other
    }
}

public struct BoardNotification: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let kind: BoardNotificationKind
    /// Nil once the actor's account is gone.
    public let actorUsername: String?
    public let postId: UUID
    public let boardSlug: String
    public let postTitle: String
    /// The reply, for `.reply`.
    public let commentId: UUID?
    /// Start of the reply's text, for `.reply`.
    public let excerpt: String?
    public let createdAt: Date
    public let isRead: Bool

    public init(
        id: UUID,
        kind: BoardNotificationKind,
        actorUsername: String?,
        postId: UUID,
        boardSlug: String,
        postTitle: String,
        commentId: UUID?,
        excerpt: String?,
        createdAt: Date,
        isRead: Bool
    ) {
        self.id = id
        self.kind = kind
        self.actorUsername = actorUsername
        self.postId = postId
        self.boardSlug = boardSlug
        self.postTitle = postTitle
        self.commentId = commentId
        self.excerpt = excerpt
        self.createdAt = createdAt
        self.isRead = isRead
    }
}

public struct BoardNotificationPage: Codable, Sendable, Equatable {
    public let items: [BoardNotification]
    public let nextCursor: String?
    public let unreadCount: Int

    public init(items: [BoardNotification], nextCursor: String?, unreadCount: Int) {
        self.items = items
        self.nextCursor = nextCursor
        self.unreadCount = unreadCount
    }
}

public struct BoardUnreadCount: Codable, Sendable, Equatable {
    public let unreadCount: Int

    public init(unreadCount: Int) {
        self.unreadCount = unreadCount
    }
}

/// `ids` nil marks everything read.
public struct MarkBoardNotificationsReadRequest: Codable, Sendable, Equatable {
    public let ids: [UUID]?

    public init(ids: [UUID]?) {
        self.ids = ids
    }
}

/// Push preferences. The in-app feed always records both kinds.
public struct BoardNotificationSettings: Codable, Sendable, Equatable {
    public let replyPush: Bool
    public let upvotePush: Bool

    public init(replyPush: Bool, upvotePush: Bool) {
        self.replyPush = replyPush
        self.upvotePush = upvotePush
    }

    public static let `default` = BoardNotificationSettings(replyPush: true, upvotePush: true)
}
