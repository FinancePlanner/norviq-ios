import Foundation

/// Links into Groups:
/// - `financeplan://groups/<groupId>/channels/<channelId>`, what message pushes carry
/// - `financeplan://groups/<groupId>`
/// - `financeplan://groups/invitations`, what invite pushes carry
/// - `https://norviq.org/g/<code>`, the invite link people share (universal link)
/// - `financeplan://groups/join/<code>`, the web hand-off page's fallback
nonisolated enum GroupDeepLink: Equatable, Sendable {
  case channel(groupID: UUID, channelID: UUID)
  case group(UUID)
  case invitations
  case invite(code: String)

  static let host = "groups"
  static let invitePathPrefix = "g"
  /// Notification categories, matching the backend's push kinds.
  static let messageCategory = "group_message"
  static let inviteCategory = "group_invite"

  static func parse(_ url: URL) -> GroupDeepLink? {
    guard let scheme = url.scheme?.lowercased(), let urlHost = url.host?.lowercased() else { return nil }
    let parts = url.pathComponents.filter { $0 != "/" }
    if scheme == "https", SocialDeepLink.hosts.contains(urlHost) {
      guard parts.count == 2, parts[0] == invitePathPrefix else { return nil }
      return SocialDeepLink.normalizedCode(parts[1]).map { .invite(code: $0) }
    }
    guard AssistantDeepLink.schemes.contains(scheme), urlHost == host else { return nil }
    switch parts.count {
    case 1 where parts[0] == "invitations":
      return .invitations
    case 1:
      return UUID(uuidString: parts[0]).map(GroupDeepLink.group)
    case 2 where parts[0] == "join":
      return SocialDeepLink.normalizedCode(parts[1]).map { .invite(code: $0) }
    case 3 where parts[1] == "channels":
      guard let groupID = UUID(uuidString: parts[0]), let channelID = UUID(uuidString: parts[2]) else { return nil }
      return .channel(groupID: groupID, channelID: channelID)
    default:
      return nil
    }
  }

  static func channelURL(groupID: UUID, channelID: UUID) -> URL? {
    URL(string: "financeplan://\(host)/\(groupID.uuidString)/channels/\(channelID.uuidString)")
  }

  /// The channel a push's thread belongs to: the backend threads message
  /// pushes as `group-channel-<channelId>`.
  static func channelID(fromThread thread: String?) -> UUID? {
    guard let thread, thread.hasPrefix("group-channel-") else { return nil }
    return UUID(uuidString: String(thread.dropFirst("group-channel-".count)))
  }
}

extension Notification.Name {
  /// Posted by `ContentView` to open the Groups tab. `userInfo["link"]` is a
  /// `GroupDeepLink` when one opened it.
  static let openGroupsFromPushNotification = Notification.Name("openGroupsFromPushNotification")
}
