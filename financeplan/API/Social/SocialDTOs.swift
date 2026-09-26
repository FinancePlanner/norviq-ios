import Foundation

// Social graph DTOs (Phase 1). They live in the app until the backend ships
// them; then they move to norviq-shared unchanged, the way AccountLinkingDTOs
// did. The contract is financeplan/Documentation/social_api.md.

nonisolated enum FriendshipStatus: String, Codable, Sendable, Hashable {
  case none
  case outgoingPending = "outgoing_pending"
  case incomingPending = "incoming_pending"
  case friends
  case blocked

  /// A newer server value must not break decoding of the whole list.
  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = FriendshipStatus(rawValue: raw) ?? .none
  }
}

nonisolated struct SocialUserSummary: Codable, Sendable, Hashable, Identifiable {
  let id: String
  let username: String
  let displayName: String?
  let avatarUrl: String?
  var friendshipStatus: FriendshipStatus
  let mutualFriendCount: Int?

  init(
    id: String,
    username: String,
    displayName: String? = nil,
    avatarUrl: String? = nil,
    friendshipStatus: FriendshipStatus = .none,
    mutualFriendCount: Int? = nil
  ) {
    self.id = id
    self.username = username
    self.displayName = displayName
    self.avatarUrl = avatarUrl
    self.friendshipStatus = friendshipStatus
    self.mutualFriendCount = mutualFriendCount
  }

  var title: String {
    guard let displayName, !displayName.trimmingCharacters(in: .whitespaces).isEmpty else { return "@\(username)" }
    return displayName
  }

  /// What lists sort by: the display name, else the bare username. Sorting by
  /// `title` would float every "@handle" above the named friends.
  var sortName: String {
    guard let displayName, !displayName.trimmingCharacters(in: .whitespaces).isEmpty else { return username }
    return displayName
  }
}

/// A profile as the viewer is allowed to see it. Every stat is optional: the
/// server leaves out whatever the owner's privacy settings hide.
nonisolated struct SocialProfile: Codable, Sendable, Hashable {
  let user: SocialUserSummary
  let streakDays: Int?
  let xpLevel: Int?
  let badgeCount: Int?
  let joinedAt: Date?
}

nonisolated struct FriendRequest: Codable, Sendable, Hashable, Identifiable {
  let id: String
  let from: SocialUserSummary
  let to: SocialUserSummary
  let createdAt: Date
}

nonisolated struct FriendsListResponse: Codable, Sendable, Hashable {
  let friends: [SocialUserSummary]
  let nextCursor: String?
}

nonisolated struct FriendRequestsResponse: Codable, Sendable, Hashable {
  let incoming: [FriendRequest]
  let outgoing: [FriendRequest]
}

nonisolated struct UserSearchResponse: Codable, Sendable, Hashable {
  let users: [SocialUserSummary]
  let nextCursor: String?
}

nonisolated struct SendFriendRequestRequest: Codable, Sendable, Hashable {
  let userId: String
}

nonisolated struct InviteLink: Codable, Sendable, Hashable {
  let code: String
  let url: String
  let expiresAt: Date?
}

nonisolated struct InviteRedeemResponse: Codable, Sendable, Hashable {
  let inviter: SocialUserSummary
}

nonisolated enum SearchVisibility: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
  case everyone
  case friendsOfFriends = "friends_of_friends"
  case nobody

  var id: String { rawValue }

  var title: String {
    switch self {
    case .everyone: String(localized: "Everyone")
    case .friendsOfFriends: String(localized: "Friends of friends")
    case .nobody: String(localized: "Nobody")
    }
  }
}

nonisolated struct SocialPrivacySettings: Codable, Sendable, Hashable {
  var searchVisibility: SearchVisibility
  var discoverableByContacts: Bool
  var discoverableByX: Bool
  /// Off by default: return % is only ever shown to friends who opt in.
  var showReturnPercent: Bool
  var showStreaks: Bool
  var showXP: Bool
  var leaderboardOptIn: Bool

  static let `default` = SocialPrivacySettings(
    searchVisibility: .everyone,
    discoverableByContacts: true,
    discoverableByX: true,
    showReturnPercent: false,
    showStreaks: true,
    showXP: true,
    leaderboardOptIn: true
  )
}

nonisolated struct BlockedUsersResponse: Codable, Sendable, Hashable {
  let users: [SocialUserSummary]
}

nonisolated enum ReportReason: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
  case spam
  case harassment
  case hate
  case scam
  case impersonation
  case inappropriate
  case other

  var id: String { rawValue }

  var title: String {
    switch self {
    case .spam: String(localized: "Spam")
    case .harassment: String(localized: "Harassment or bullying")
    case .hate: String(localized: "Hate speech")
    case .scam: String(localized: "Scam or fraud")
    case .impersonation: String(localized: "Impersonation")
    case .inappropriate: String(localized: "Inappropriate content")
    case .other: String(localized: "Something else")
    }
  }
}

nonisolated enum ReportTargetType: String, Codable, Sendable, Hashable {
  case user
  case message
}

nonisolated struct ReportRequest: Codable, Sendable, Hashable {
  let targetType: ReportTargetType
  let targetId: String
  let reason: ReportReason
  let note: String?
}

/// Server-side switches, so each phase can go live without an app release.
nonisolated struct SocialConfig: Codable, Sendable, Hashable {
  let enabled: Bool
  let contactsDiscovery: Bool
  let xImport: Bool
  let leaderboards: Bool
  let messaging: Bool

  static let disabled = SocialConfig(
    enabled: false, contactsDiscovery: false, xImport: false, leaderboards: false, messaging: false
  )
}
