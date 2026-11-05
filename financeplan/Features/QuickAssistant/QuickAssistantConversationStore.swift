import Foundation

/// Remembers the Quick Q conversation for each signed-in user on this device.
///
/// Quick Q keeps its own conversation because the latest one is shared with
/// linked Telegram chats. Only the id is stored; messages stay on the server.
struct QuickAssistantConversationStore: @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func conversationID(forUser userID: String) -> String? {
        defaults.string(forKey: key(userID))
    }

    func setConversationID(_ id: String?, forUser userID: String) {
        defaults.set(id, forKey: key(userID))
    }

    private func key(_ userID: String) -> String { "quick_assistant_conversation.\(userID)" }
}
