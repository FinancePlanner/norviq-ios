import Foundation

/// `X-StockPlan-Client-Capabilities`: a comma-separated list of features this
/// build understands. The backend switches behaviour per token, so an old App
/// Store build keeps working while a new one opts in.
///
/// - `ai-consent-v1` — this client shows the AI consent sheet and handles
///   `403 AI_CONSENT_REQUIRED`, so the backend enforces consent for it. Sent on
///   every request.
/// - `mfa-auth-v1` — sign-in responses may be an MFA challenge. Sent by
///   `AuthHTTPClient` on the sign-in routes only.
nonisolated enum ClientCapabilities {
  static let header = "X-StockPlan-Client-Capabilities"
  static let aiConsent = "ai-consent-v1"
  static let mfaAuth = "mfa-auth-v1"

  /// Tokens every backend request carries.
  static let always = [aiConsent]

  /// `existing` plus `tokens`, without duplicates, in order.
  static func merged(_ existing: String?, adding tokens: [String]) -> String {
    var result = (existing ?? "")
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    for token in tokens where !result.contains(where: { $0.caseInsensitiveCompare(token) == .orderedSame }) {
      result.append(token)
    }
    return result.joined(separator: ", ")
  }

  /// Adds the always-on tokens to `request`, keeping any already set.
  static func applied(to request: URLRequest) -> URLRequest {
    var request = request
    request.setValue(
      merged(request.value(forHTTPHeaderField: header), adding: always),
      forHTTPHeaderField: header
    )
    return request
  }
}
