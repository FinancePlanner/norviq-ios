import Foundation

/// Where an assistant push or deep link points.
///
/// The backend sends category `assistant_message`, thread `assistant-<id>`
/// and a payload carrying `conversationId` plus
/// `financeplan://assistant/conversations/<id>`. Any of those can name the
/// conversation; when none of them does (or the id is not a UUID) the
/// assistant still opens, on its default conversation.
nonisolated enum AssistantDeepLink: Equatable, Sendable {
  static let category = "assistant_message"
  static let payloadType = "assistant_message"
  static let threadPrefix = "assistant-"
  static let host = "assistant"
  /// `financeplan` is what the backend writes; the others are the app's own
  /// callback schemes, accepted so a link built from them also works.
  static let schemes: Set<String> = ["financeplan", "norviqa", "norviqa-beta"]

  /// `nil` means "open the assistant, no particular conversation".
  case assistant(conversationID: String?)

  var conversationID: String? {
    switch self {
    case let .assistant(conversationID): conversationID
    }
  }

  /// Parses `financeplan://assistant[/conversations/<UUID>]`. Returns nil for
  /// URLs that are not assistant links (OAuth callbacks, stock links, …) so the
  /// caller can leave them alone.
  static func parse(_ url: URL) -> AssistantDeepLink? {
    guard let scheme = url.scheme?.lowercased(), schemes.contains(scheme),
          url.host?.lowercased() == host
    else { return nil }
    let parts = url.pathComponents.filter { $0 != "/" }
    guard parts.count >= 2, parts[0].lowercased() == "conversations" else {
      return .assistant(conversationID: nil)
    }
    return .assistant(conversationID: normalizedConversationID(parts[1]))
  }

  static func parse(_ string: String?) -> AssistantDeepLink? {
    guard let string, let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      return nil
    }
    return parse(url)
  }

  /// A conversation id from `assistant-<UUID>`, or nil.
  static func conversationID(fromThread threadIdentifier: String?) -> String? {
    guard let threadIdentifier, threadIdentifier.hasPrefix(threadPrefix) else { return nil }
    return normalizedConversationID(String(threadIdentifier.dropFirst(threadPrefix.count)))
  }

  /// Canonical (lowercased) UUID string, or nil when the value is not a UUID.
  /// The backend's ids are UUIDs, and comparing the visible conversation with
  /// a pushed one must not fail on letter case.
  static func normalizedConversationID(_ raw: String?) -> String? {
    guard let raw, let uuid = UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      return nil
    }
    return uuid.uuidString.lowercased()
  }
}

/// What the assistant screen currently shows. `nil` conversation while it is
/// still loading.
nonisolated struct AssistantPresence: Equatable, Sendable {
  var isVisible: Bool
  var conversationID: String?

  static let hidden = AssistantPresence(isVisible: false, conversationID: nil)

  func isViewing(_ conversationID: String?) -> Bool {
    guard isVisible, let conversationID, let current = self.conversationID else { return false }
    return AssistantDeepLink.normalizedConversationID(current) == AssistantDeepLink.normalizedConversationID(conversationID)
  }
}

/// A tap on an assistant push, or an assistant deep link.
nonisolated enum AssistantOpenDecision: Equatable, Sendable {
  /// Assistant is not on screen: present it on this conversation (nil = default).
  case present(conversationID: String?)
  /// Assistant is on screen on another conversation: switch it in place.
  case switchVisible(conversationID: String)
  /// Assistant already shows this conversation: refetch the thread.
  case refreshVisible(conversationID: String)
  /// Assistant is on screen and the link names no conversation: leave it.
  case keepVisible
}

/// An assistant push arriving while the app is in the foreground.
nonisolated enum AssistantForegroundDecision: Equatable, Sendable {
  case showBanner
  /// The user is reading that thread: no banner, refetch it instead.
  case refreshThread(conversationID: String)
}

nonisolated enum AssistantPushRouting {
  static func openDecision(conversationID: String?, presence: AssistantPresence) -> AssistantOpenDecision {
    guard presence.isVisible else { return .present(conversationID: conversationID) }
    guard let conversationID else { return .keepVisible }
    if presence.isViewing(conversationID) { return .refreshVisible(conversationID: conversationID) }
    return .switchVisible(conversationID: conversationID)
  }

  static func foregroundDecision(conversationID: String?, presence: AssistantPresence) -> AssistantForegroundDecision {
    guard let conversationID, presence.isViewing(conversationID) else { return .showBanner }
    return .refreshThread(conversationID: conversationID)
  }
}

/// Commands for an assistant screen that is already on screen.
nonisolated enum AssistantInPlaceCommand: Equatable, Sendable {
  case open(conversationID: String)
  case refresh(conversationID: String)
}

extension Notification.Name {
  /// Posted by `ContentView` when a routed push or link should present the
  /// assistant. `userInfo["conversationId"]` is optional.
  static let openAssistantFromPushNotification = Notification.Name("openAssistantFromPushNotification")
}
