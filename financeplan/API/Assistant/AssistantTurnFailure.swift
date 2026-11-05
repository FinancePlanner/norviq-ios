import Foundation

/// An `error` frame from the persisted-turn stream.
///
/// The stream is already a 200 by the time the server knows a turn cannot run,
/// so these codes do the job the HTTP status does on other routes.
nonisolated struct AssistantTurnFailure: LocalizedError {
    let message: String
    var code: String? = nil

    var errorDescription: String? { message }
}

/// What a client does about a failed turn.
nonisolated enum AssistantTurnRecovery: Equatable {
    case askForConsent
    case showPaywall
    case recreateConversation
    case showMessage

    init(_ error: any Error) {
        if let failure = error as? AssistantTurnFailure {
            switch failure.code {
            case "ai_consent_required": self = .askForConsent
            case "quota_exhausted", "upgrade_required": self = .showPaywall
            case "conversation_not_found": self = .recreateConversation
            default: self = .showMessage
            }
        } else if let failure = error as? AssistantStreamClient.Failure {
            switch failure {
            case .aiConsentRequired: self = .askForConsent
            case .upgradeRequired: self = .showPaywall
            default: self = .showMessage
            }
        } else if AIConsentRequired.matches(error) {
            self = .askForConsent
        } else {
            self = .showMessage
        }
    }
}
