import Foundation

extension Notification.Name {
  /// Posted when any AI endpoint answers `403 AI_CONSENT_REQUIRED`.
  /// `AIConsentStore` turns it into a consent prompt on the visible AI surface.
  nonisolated static let aiConsentRequired = Notification.Name("norviq.aiConsentRequired")
}

/// The backend's "user has not allowed AI data sharing" signal:
/// `403 {"error": true, "reason": "AI_CONSENT_REQUIRED"}`.
///
/// Detected once, in `BaseHTTPClient.validateResponse` and the streaming
/// assistant client, so every AI call — present or future — reacts the same
/// way without each feature parsing the body itself.
nonisolated enum AIConsentRequired {
  static let reason = "AI_CONSENT_REQUIRED"

  static func matches(statusCode: Int, body: Data) -> Bool {
    guard statusCode == 403,
          let envelope = try? JSONDecoder().decode(ReasonEnvelope.self, from: body)
    else { return false }
    return envelope.reason == reason
  }

  /// `{"error": true, "reason": "AI_CONSENT_REQUIRED"}` — only `reason` is read.
  private struct ReasonEnvelope: Decodable {
    let reason: String?
  }

  /// True when `error` came from a consent-required response. Typed client
  /// errors carry the reason as their message.
  static func matches(_ error: any Error) -> Bool {
    if let described = (error as? LocalizedError)?.errorDescription, described.contains(reason) {
      return true
    }
    return String(describing: error).contains(reason)
  }

  static func post() {
    NotificationCenter.default.post(name: .aiConsentRequired, object: nil)
  }
}
