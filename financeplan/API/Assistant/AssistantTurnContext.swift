import Foundation

/// A hint sent with one assistant turn and never stored by the server.
///
/// Sending it also tells the backend this client shows the current AI consent
/// copy, which is one of the conditions for the extended read tools.
nonisolated struct AssistantTurnContext: Codable, Sendable, Equatable {
    enum InputMode: String, Codable, Sendable {
        case text
        case voice
    }

    var screen: String?
    var timeZone: String?
    var locale: String?
    var inputMode: InputMode?

    static func current(
        screen: AIViewScope? = nil,
        inputMode: InputMode = .text,
        language: AppLanguage = .stored,
        timeZone: TimeZone = .current
    ) -> AssistantTurnContext {
        AssistantTurnContext(
            screen: screen?.rawValue,
            timeZone: timeZone.identifier,
            locale: language.rawValue,
            inputMode: inputMode
        )
    }
}
