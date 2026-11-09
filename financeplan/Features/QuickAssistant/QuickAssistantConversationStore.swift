import Foundation

/// Remembers the Quick Q conversation for each signed-in user on this device.
///
/// Quick Q keeps its own conversation because the latest one is shared with
/// linked Telegram chats. Only the id is stored; messages stay on the server.
struct QuickAssistantConversationStore: @unchecked Sendable {
    private let defaults: UserDefaults
    /// What the user may attach, remembered for this app session.
    let flags: AttachmentFlagCache

    init(defaults: UserDefaults = .standard, flags: AttachmentFlagCache = .shared) {
        self.defaults = defaults
        self.flags = flags
    }

    func conversationID(forUser userID: String) -> String? {
        defaults.string(forKey: key(userID))
    }

    func setConversationID(_ id: String?, forUser userID: String) {
        defaults.set(id, forKey: key(userID))
    }

    private func key(_ userID: String) -> String { "quick_assistant_conversation.\(userID)" }
}

/// Whether images and documents are on for a user, from the one preferences
/// request Quick Q makes. In memory only: a new launch asks again.
final class AttachmentFlagCache: @unchecked Sendable {
    struct Flags: Equatable {
        let images: Bool
        let documents: Bool
    }

    static let shared = AttachmentFlagCache()

    private let lock = NSLock()
    private var byUser: [String: Flags] = [:]

    init() {}

    func flags(forUser userID: String) -> Flags? {
        lock.withLock { byUser[userID] }
    }

    func set(_ flags: Flags, forUser userID: String) {
        lock.withLock { byUser[userID] = flags }
    }
}
