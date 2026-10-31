import Foundation

// Groups are member spaces with text channels, in the shape of a Discord
// server: every group starts with `#general`, members chat in realtime, and a
// group is either invite-only or listed in the public directory. Boards stay
// the open forum; the two share moderation (sanctions, blocks, reports) only.
//
// Type names avoid a bare `Group`, which clashes with `SwiftUI.Group`.

// MARK: - Enums

/// What a group is about. Decodes any value it doesn't know as `.other`.
public enum GroupTopic: String, Codable, CaseIterable, Sendable {
    case stock
    case etf
    case crypto
    case community
    case custom
    case other

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = GroupTopic(rawValue: raw) ?? .other
    }

    /// Topics that may carry a ticker.
    public var allowsTicker: Bool {
        self == .stock || self == .etf || self == .crypto
    }
}

/// `private` groups are reachable only by invitation; `public` ones are
/// listed in the directory and anyone can join.
public enum GroupVisibility: String, Codable, CaseIterable, Sendable {
    case `private`
    case `public`
}

/// Decodes any value it doesn't know as `.other`, which clients treat as a
/// plain member.
public enum GroupRole: String, Codable, CaseIterable, Sendable {
    case owner
    case admin
    case member
    case other

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = GroupRole(rawValue: raw) ?? .other
    }

    /// Owner and admins manage channels, members and invites.
    public var canManage: Bool {
        self == .owner || self == .admin
    }
}

/// Only `text` exists in v1. Clients hide `.other` channels, so announcement
/// and forum kinds can be added without breaking older builds.
public enum GroupChannelKind: String, Codable, CaseIterable, Sendable {
    case text
    case other

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = GroupChannelKind(rawValue: raw) ?? .other
    }
}

public enum GroupMembershipRemovalReason: String, Codable, CaseIterable, Sendable {
    case left
    case kicked
    case banned
    /// The group itself was deleted.
    case deleted
    case other

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = GroupMembershipRemovalReason(rawValue: raw) ?? .other
    }
}

// MARK: - Groups

/// The viewer's own membership. Nil on a public group they haven't joined.
public struct GroupMembership: Codable, Sendable, Equatable {
    public let role: GroupRole
    /// Off mutes push for the whole group; the unread count still moves.
    public let pushEnabled: Bool
    public let joinedAt: Date

    public init(role: GroupRole, pushEnabled: Bool, joinedAt: Date) {
        self.role = role
        self.pushEnabled = pushEnabled
        self.joinedAt = joinedAt
    }
}

/// The last message in a group, for the list row preview.
public struct GroupMessagePreview: Codable, Sendable, Equatable {
    /// Nil once the author's account is gone.
    public let authorUsername: String?
    /// Truncated body; nil when the message was deleted.
    public let excerpt: String?
    public let createdAt: Date

    public init(authorUsername: String?, excerpt: String?, createdAt: Date) {
        self.authorUsername = authorUsername
        self.excerpt = excerpt
        self.createdAt = createdAt
    }
}

public struct GroupSummary: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let description: String
    /// A single emoji shown as the group's icon.
    public let iconEmoji: String?
    public let topic: GroupTopic
    /// Uppercased symbol without `$`, e.g. `AAPL`, `BRK.B`, `BTC-USD`.
    public let ticker: String?
    public let visibility: GroupVisibility
    public let memberCount: Int
    /// The first channel, which is `#general` unless it was renamed.
    public let defaultChannelId: UUID?
    public let lastMessageAt: Date?
    public let lastMessage: GroupMessagePreview?
    /// Unread messages across the group's channels; 0 for non-members.
    public let unreadCount: Int
    public let membership: GroupMembership?
    public let createdAt: Date

    public init(
        id: UUID,
        name: String,
        description: String,
        iconEmoji: String?,
        topic: GroupTopic,
        ticker: String?,
        visibility: GroupVisibility,
        memberCount: Int,
        defaultChannelId: UUID?,
        lastMessageAt: Date?,
        lastMessage: GroupMessagePreview?,
        unreadCount: Int,
        membership: GroupMembership?,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconEmoji = iconEmoji
        self.topic = topic
        self.ticker = ticker
        self.visibility = visibility
        self.memberCount = memberCount
        self.defaultChannelId = defaultChannelId
        self.lastMessageAt = lastMessageAt
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
        self.membership = membership
        self.createdAt = createdAt
    }
}

/// What the viewer may do in a group. All false on a public preview.
public struct GroupPermissions: Codable, Sendable, Equatable {
    public let canPost: Bool
    public let canInvite: Bool
    /// Rename, describe, change visibility.
    public let canEdit: Bool
    public let canManageChannels: Bool
    /// Kick, ban, delete others' messages.
    public let canModerate: Bool
    public let canDelete: Bool

    public init(
        canPost: Bool,
        canInvite: Bool,
        canEdit: Bool,
        canManageChannels: Bool,
        canModerate: Bool,
        canDelete: Bool
    ) {
        self.canPost = canPost
        self.canInvite = canInvite
        self.canEdit = canEdit
        self.canManageChannels = canManageChannels
        self.canModerate = canModerate
        self.canDelete = canDelete
    }

    public static let none = GroupPermissions(
        canPost: false, canInvite: false, canEdit: false,
        canManageChannels: false, canModerate: false, canDelete: false
    )
}

public struct GroupChannel: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let groupId: UUID
    /// Lowercase, digits and dashes; shown as `#name`.
    public let name: String
    public let kind: GroupChannelKind
    public let topic: String?
    public let position: Int
    /// Sequence number of the newest message; 0 for an empty channel.
    public let lastSeq: Int64
    public let lastMessageAt: Date?
    /// The viewer's read marker; messages with a higher seq are unread.
    public let lastReadSeq: Int64
    public let unreadCount: Int

    public init(
        id: UUID,
        groupId: UUID,
        name: String,
        kind: GroupChannelKind,
        topic: String?,
        position: Int,
        lastSeq: Int64,
        lastMessageAt: Date?,
        lastReadSeq: Int64,
        unreadCount: Int
    ) {
        self.id = id
        self.groupId = groupId
        self.name = name
        self.kind = kind
        self.topic = topic
        self.position = position
        self.lastSeq = lastSeq
        self.lastMessageAt = lastMessageAt
        self.lastReadSeq = lastReadSeq
        self.unreadCount = unreadCount
    }
}

public struct GroupDetail: Codable, Sendable, Equatable {
    public let group: GroupSummary
    /// Ordered by position. Empty on a public preview.
    public let channels: [GroupChannel]
    public let permissions: GroupPermissions
    /// Nil once the owner's account is gone.
    public let ownerUsername: String?

    public init(
        group: GroupSummary,
        channels: [GroupChannel],
        permissions: GroupPermissions,
        ownerUsername: String?
    ) {
        self.group = group
        self.channels = channels
        self.permissions = permissions
        self.ownerUsername = ownerUsername
    }
}

/// The viewer's groups, most recently active first.
public struct GroupListResponse: Codable, Sendable, Equatable {
    public let items: [GroupSummary]
    /// Pending direct invitations, for the badge on the invitations row.
    public let pendingInvitationCount: Int

    public init(items: [GroupSummary], pendingInvitationCount: Int) {
        self.items = items
        self.pendingInvitationCount = pendingInvitationCount
    }
}

/// Public groups, most members first.
public struct GroupDirectoryPage: Codable, Sendable, Equatable {
    public let items: [GroupSummary]
    public let nextCursor: String?

    public init(items: [GroupSummary], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public struct GroupUnreadCount: Codable, Sendable, Equatable {
    /// Unread messages across every group the viewer belongs to.
    public let total: Int
    public let pendingInvitationCount: Int

    public init(total: Int, pendingInvitationCount: Int) {
        self.total = total
        self.pendingInvitationCount = pendingInvitationCount
    }
}

public struct CreateGroupRequest: Codable, Sendable, Equatable {
    public let name: String
    public let description: String?
    public let iconEmoji: String?
    public let topic: GroupTopic
    /// Only for stock, ETF and crypto groups. A leading `$` is stripped.
    public let ticker: String?
    public let visibility: GroupVisibility

    public init(
        name: String,
        description: String?,
        iconEmoji: String?,
        topic: GroupTopic,
        ticker: String?,
        visibility: GroupVisibility
    ) {
        self.name = name
        self.description = description
        self.iconEmoji = iconEmoji
        self.topic = topic
        self.ticker = ticker
        self.visibility = visibility
    }
}

/// Nil fields are left unchanged. To clear the ticker, send an empty string.
public struct UpdateGroupRequest: Codable, Sendable, Equatable {
    public let name: String?
    public let description: String?
    public let iconEmoji: String?
    public let topic: GroupTopic?
    public let ticker: String?
    public let visibility: GroupVisibility?

    public init(
        name: String? = nil,
        description: String? = nil,
        iconEmoji: String? = nil,
        topic: GroupTopic? = nil,
        ticker: String? = nil,
        visibility: GroupVisibility? = nil
    ) {
        self.name = name
        self.description = description
        self.iconEmoji = iconEmoji
        self.topic = topic
        self.ticker = ticker
        self.visibility = visibility
    }
}

public struct GroupNotificationSettingsRequest: Codable, Sendable, Equatable {
    public let pushEnabled: Bool

    public init(pushEnabled: Bool) {
        self.pushEnabled = pushEnabled
    }
}

// MARK: - Members

public struct GroupMember: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID {
        userId
    }

    public let userId: UUID
    public let username: String?
    public let displayName: String?
    public let role: GroupRole
    public let joinedAt: Date

    public init(userId: UUID, username: String?, displayName: String?, role: GroupRole, joinedAt: Date) {
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.role = role
        self.joinedAt = joinedAt
    }
}

/// Owner first, then admins, then members by join date.
public struct GroupMemberPage: Codable, Sendable, Equatable {
    public let items: [GroupMember]
    public let nextCursor: String?

    public init(items: [GroupMember], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

/// Owner only, and only `admin` or `member`. Ownership moves through
/// `TransferGroupOwnershipRequest`.
public struct UpdateGroupMemberRequest: Codable, Sendable, Equatable {
    public let role: GroupRole

    public init(role: GroupRole) {
        self.role = role
    }
}

public struct TransferGroupOwnershipRequest: Codable, Sendable, Equatable {
    public let userId: UUID

    public init(userId: UUID) {
        self.userId = userId
    }
}

/// Removes the user and stops them rejoining by link or from the directory.
public struct GroupBanRequest: Codable, Sendable, Equatable {
    public let userId: UUID
    public let reason: String?

    public init(userId: UUID, reason: String?) {
        self.userId = userId
        self.reason = reason
    }
}

// MARK: - Channels

public struct CreateGroupChannelRequest: Codable, Sendable, Equatable {
    public let name: String
    public let topic: String?

    public init(name: String, topic: String?) {
        self.name = name
        self.topic = topic
    }
}

/// Nil fields are left unchanged. To clear the topic, send an empty string.
public struct UpdateGroupChannelRequest: Codable, Sendable, Equatable {
    public let name: String?
    public let topic: String?
    public let position: Int?

    public init(name: String? = nil, topic: String? = nil, position: Int? = nil) {
        self.name = name
        self.topic = topic
        self.position = position
    }
}

// MARK: - Messages

public struct GroupMessage: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let groupId: UUID
    public let channelId: UUID
    /// Gap-free and increasing within the channel; the paging and catch-up key.
    public let seq: Int64
    /// The sender's idempotency key, so a client can match its optimistic row.
    public let clientMessageId: String?
    /// Nil once the author's account is gone.
    public let authorId: UUID?
    public let authorUsername: String?
    /// Nil when the message was deleted.
    public let body: String?
    public let isDeleted: Bool
    public let createdAt: Date

    public init(
        id: UUID,
        groupId: UUID,
        channelId: UUID,
        seq: Int64,
        clientMessageId: String?,
        authorId: UUID?,
        authorUsername: String?,
        body: String?,
        isDeleted: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.groupId = groupId
        self.channelId = channelId
        self.seq = seq
        self.clientMessageId = clientMessageId
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.body = body
        self.isDeleted = isDeleted
        self.createdAt = createdAt
    }
}

/// Oldest first. Page with `before=<first seq>` or `after=<last seq>`.
public struct GroupMessagePage: Codable, Sendable, Equatable {
    public let items: [GroupMessage]
    public let hasMoreBefore: Bool
    public let hasMoreAfter: Bool
    /// The viewer's read marker when the page was served, for the
    /// "New messages" divider.
    public let lastReadSeq: Int64

    public init(items: [GroupMessage], hasMoreBefore: Bool, hasMoreAfter: Bool, lastReadSeq: Int64) {
        self.items = items
        self.hasMoreBefore = hasMoreBefore
        self.hasMoreAfter = hasMoreAfter
        self.lastReadSeq = lastReadSeq
    }
}

/// A repeat of the same `clientMessageId` returns the original message, so a
/// retry after a dropped response never posts twice.
public struct SendGroupMessageRequest: Codable, Sendable, Equatable {
    public let clientMessageId: String
    public let body: String

    public init(clientMessageId: String, body: String) {
        self.clientMessageId = clientMessageId
        self.body = body
    }
}

/// The marker only moves forward; a lower seq is ignored.
public struct MarkGroupChannelReadRequest: Codable, Sendable, Equatable {
    public let seq: Int64

    public init(seq: Int64) {
        self.seq = seq
    }
}

/// Lands in the same review queue as board reports.
public struct GroupMessageReportRequest: Codable, Sendable, Equatable {
    public let reason: BoardReportReason
    public let note: String?

    public init(reason: BoardReportReason, note: String?) {
        self.reason = reason
        self.note = note
    }
}

// MARK: - Invites

/// A shareable link, `https://norviq.org/g/<code>`.
public struct GroupInviteLink: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let groupId: UUID
    public let code: String
    public let url: String
    /// Nil never expires.
    public let expiresAt: Date?
    /// Nil is unlimited.
    public let maxUses: Int?
    public let uses: Int
    public let createdByUsername: String?
    public let createdAt: Date

    public init(
        id: UUID,
        groupId: UUID,
        code: String,
        url: String,
        expiresAt: Date?,
        maxUses: Int?,
        uses: Int,
        createdByUsername: String?,
        createdAt: Date
    ) {
        self.id = id
        self.groupId = groupId
        self.code = code
        self.url = url
        self.expiresAt = expiresAt
        self.maxUses = maxUses
        self.uses = uses
        self.createdByUsername = createdByUsername
        self.createdAt = createdAt
    }
}

public struct GroupInviteLinkList: Codable, Sendable, Equatable {
    public let items: [GroupInviteLink]

    public init(items: [GroupInviteLink]) {
        self.items = items
    }
}

/// Nil `expiresInHours` never expires; nil `maxUses` is unlimited.
public struct CreateGroupInviteRequest: Codable, Sendable, Equatable {
    public let expiresInHours: Int?
    public let maxUses: Int?

    public init(expiresInHours: Int?, maxUses: Int?) {
        self.expiresInHours = expiresInHours
        self.maxUses = maxUses
    }

    /// Seven days, unlimited uses.
    public static let `default` = CreateGroupInviteRequest(expiresInHours: 168, maxUses: nil)
}

/// What an invite link opens to before the viewer joins.
public struct GroupInvitePreview: Codable, Sendable, Equatable {
    public let code: String
    public let group: GroupSummary
    public let inviterUsername: String?
    public let alreadyMember: Bool
    public let expiresAt: Date?

    public init(code: String, group: GroupSummary, inviterUsername: String?, alreadyMember: Bool, expiresAt: Date?) {
        self.code = code
        self.group = group
        self.inviterUsername = inviterUsername
        self.alreadyMember = alreadyMember
        self.expiresAt = expiresAt
    }
}

/// Invite friends directly. Each one must be a friend the inviter hasn't
/// blocked and who hasn't blocked them.
public struct GroupDirectInvitationRequest: Codable, Sendable, Equatable {
    public let userIds: [UUID]

    public init(userIds: [UUID]) {
        self.userIds = userIds
    }
}

public struct GroupDirectInvitationResponse: Codable, Sendable, Equatable {
    /// Users who were sent an invitation; the rest were skipped (already
    /// members, banned, not friends).
    public let invitedUserIds: [UUID]

    public init(invitedUserIds: [UUID]) {
        self.invitedUserIds = invitedUserIds
    }
}

/// A pending direct invitation addressed to the viewer.
public struct GroupInvitation: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let group: GroupSummary
    public let inviterUsername: String?
    public let createdAt: Date

    public init(id: UUID, group: GroupSummary, inviterUsername: String?, createdAt: Date) {
        self.id = id
        self.group = group
        self.inviterUsername = inviterUsername
        self.createdAt = createdAt
    }
}

public struct GroupInvitationList: Codable, Sendable, Equatable {
    public let items: [GroupInvitation]

    public init(items: [GroupInvitation]) {
        self.items = items
    }
}

// MARK: - Realtime

/// Event names on `GET /v1/realtime/stream`. Decodes any value it doesn't
/// know as `.other`, which clients ignore.
public enum GroupRealtimeEventType: String, Codable, CaseIterable, Sendable {
    /// First event on every connection. Clients catch up over REST on it.
    case ready
    case messageCreated = "message.created"
    case messageDeleted = "message.deleted"
    /// The viewer read a channel on another device.
    case channelRead = "channel.read"
    case channelCreated = "channel.created"
    case channelUpdated = "channel.updated"
    case channelDeleted = "channel.deleted"
    case groupUpdated = "group.updated"
    /// The viewer is no longer a member.
    case membershipRemoved = "membership.removed"
    case invitationReceived = "invitation.received"
    /// The server is closing the stream; reconnect.
    case reconnect
    case other

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = GroupRealtimeEventType(rawValue: raw) ?? .other
    }
}

/// The `data:` payload of one stream event. Which fields are set depends on
/// `type`; everything else is nil.
public struct GroupRealtimeEvent: Codable, Sendable, Equatable {
    public let type: GroupRealtimeEventType
    public let groupId: UUID?
    public let channelId: UUID?
    /// `message.created`.
    public let message: GroupMessage?
    /// `message.deleted`.
    public let messageId: UUID?
    /// `message.deleted` and `channel.read`.
    public let seq: Int64?
    /// `channel.created` and `channel.updated`.
    public let channel: GroupChannel?
    /// `group.updated`.
    public let group: GroupSummary?
    /// `membership.removed`.
    public let reason: GroupMembershipRemovalReason?
    /// `invitation.received`.
    public let invitation: GroupInvitation?
    /// `ready`.
    public let serverTime: Date?

    public init(
        type: GroupRealtimeEventType,
        groupId: UUID? = nil,
        channelId: UUID? = nil,
        message: GroupMessage? = nil,
        messageId: UUID? = nil,
        seq: Int64? = nil,
        channel: GroupChannel? = nil,
        group: GroupSummary? = nil,
        reason: GroupMembershipRemovalReason? = nil,
        invitation: GroupInvitation? = nil,
        serverTime: Date? = nil
    ) {
        self.type = type
        self.groupId = groupId
        self.channelId = channelId
        self.message = message
        self.messageId = messageId
        self.seq = seq
        self.channel = channel
        self.group = group
        self.reason = reason
        self.invitation = invitation
        self.serverTime = serverTime
    }
}
