import Foundation

/// An invite link: `https://norviq.org/i/<code>` (universal link, also what
/// people paste into Instagram, Facebook or WhatsApp) or
/// `financeplan://invite/<code>`.
nonisolated enum SocialDeepLink: Equatable, Sendable {
  case invite(code: String)

  static let hosts: Set<String> = ["norviq.org", "www.norviq.org"]
  static let invitePathPrefix = "i"
  static let inviteHost = "invite"

  static func parse(_ url: URL) -> SocialDeepLink? {
    guard let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased() else { return nil }
    let parts = url.pathComponents.filter { $0 != "/" }
    let rawCode: String?
    if scheme == "https", hosts.contains(host) {
      rawCode = parts.count == 2 && parts[0] == invitePathPrefix ? parts[1] : nil
    } else if AssistantDeepLink.schemes.contains(scheme), host == inviteHost {
      rawCode = parts.count == 1 ? parts[0] : nil
    } else {
      rawCode = nil
    }
    return normalizedCode(rawCode).map { .invite(code: $0) }
  }

  /// Codes are short URL-safe tokens. Anything else is not ours and must not
  /// reach the API as a path segment.
  static func normalizedCode(_ raw: String?) -> String? {
    guard let raw else { return nil }
    let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    guard (4...64).contains(code.count),
          code.unicodeScalars.allSatisfy({ allowed.contains($0) && $0.isASCII })
    else { return nil }
    return code
  }

  static func inviteURL(code: String) -> URL? {
    URL(string: "https://norviq.org/\(invitePathPrefix)/\(code)")
  }
}

extension Notification.Name {
  /// Posted by `ContentView` to open the Friends tab. `userInfo["inviteCode"]`
  /// is set when an invite link opened it.
  static let openSocialFromPushNotification = Notification.Name("openSocialFromPushNotification")
}
