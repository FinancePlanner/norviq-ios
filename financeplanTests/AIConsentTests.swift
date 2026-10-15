import Foundation
import XCTest
@testable import financeplan

/// Every test is `async`: an app-module `@Observable` store released from a
/// synchronous XCTest method crashes the test host (GamificationStore too).
@MainActor
final class AIConsentTests: XCTestCase {
  private final class ClientMock: AIConsentClientProtocol, @unchecked Sendable {
    var getResult: Result<AIConsentDTO, Error> = .success(AIConsentDTO(consentedAt: nil))
    var grantResult: Result<AIConsentDTO, Error> = .success(AIConsentDTO(consentedAt: "2026-10-14T10:00:00Z"))
    var revokeResult: Result<AIConsentDTO, Error> = .success(AIConsentDTO(consentedAt: nil))
    var getCalls = 0
    /// Runs inside `get()` before it returns — lets a test switch users mid-flight.
    var onGet: (@MainActor () -> Void)?

    func get() async throws -> AIConsentDTO {
      getCalls += 1
      if let onGet { await onGet() }
      return try getResult.get()
    }
    func grant() async throws -> AIConsentDTO { try grantResult.get() }
    func revoke() async throws -> AIConsentDTO { try revokeResult.get() }
  }

  private struct Offline: Error {}

  private var prompts = 0
  private var clock = Date(timeIntervalSince1970: 1_800_000_000)

  /// A throwaway defaults domain per test, removed when the test ends.
  private func makeDefaults() -> UserDefaults {
    let suiteName = "AIConsentTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    addTeardownBlock { UserDefaults().removePersistentDomain(forName: suiteName) }
    return defaults
  }

  private func makeStore(_ client: ClientMock = ClientMock()) -> AIConsentStore {
    AIConsentStore(
      client: client,
      defaults: makeDefaults(),
      now: { [unowned self] in self.clock },
      presentPrompt: { [unowned self] in self.prompts += 1 }
    )
  }

  // MARK: - Signal detection

  func testMatchesConsentRequiredReasonOnlyOn403() async {
    let body = Data(#"{"error":true,"reason":"AI_CONSENT_REQUIRED"}"#.utf8)
    XCTAssertTrue(AIConsentRequired.matches(statusCode: 403, body: body))
    XCTAssertFalse(AIConsentRequired.matches(statusCode: 400, body: body))
    XCTAssertFalse(AIConsentRequired.matches(statusCode: 403, body: Data(#"{"code":"upgrade_required"}"#.utf8)))
    // The reason must be the JSON field, not text somewhere in the body.
    XCTAssertFalse(AIConsentRequired.matches(
      statusCode: 403,
      body: Data(#"{"reason":"FORBIDDEN","detail":"AI_CONSENT_REQUIRED"}"#.utf8)
    ))
  }

  func testMatchesTypedClientErrorCarryingReason() async {
    XCTAssertTrue(AIConsentRequired.matches(StockHTTPClient.Error.api("AI_CONSENT_REQUIRED")))
    XCTAssertFalse(AIConsentRequired.matches(StockHTTPClient.Error.api("Something else")))
  }

  // MARK: - Capability header

  func testCapabilitiesMergeKeepsMFAAndAddsConsent() async {
    XCTAssertEqual(ClientCapabilities.merged(nil, adding: ["ai-consent-v1"]), "ai-consent-v1")
    XCTAssertEqual(ClientCapabilities.merged("mfa-auth-v1", adding: ["ai-consent-v1"]), "mfa-auth-v1, ai-consent-v1")
    XCTAssertEqual(ClientCapabilities.merged("mfa-auth-v1, ai-consent-v1", adding: ["ai-consent-v1"]), "mfa-auth-v1, ai-consent-v1")

    let request = ClientCapabilities.applied(to: URLRequest(url: URL(string: "https://api.example.com/v1/ai/chat")!))
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-StockPlan-Client-Capabilities"), "ai-consent-v1")
  }

  func testBaseClientSendsConsentCapabilityOnEveryRequest() async throws {
    let client = BaseHTTPClient(baseURL: URL(string: "https://api.example.com")!)
    let request = try await client.makeURLRequest(for: GetOnboardingStateEndpoint())
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-StockPlan-Client-Capabilities"), "ai-consent-v1")
  }

  // MARK: - Store

  func testNullConsentGatesAndPromptsOnce() async {
    let defaults = makeDefaults()
    let store = AIConsentStore(client: ClientMock(), defaults: defaults, presentPrompt: {})
    await store.refresh(userID: "u1")

    XCTAssertEqual(store.status, .notConsented)
    XCTAssertFalse(store.allowsAI)
    XCTAssertTrue(store.shouldAutoPrompt)

    store.decline()
    XCTAssertFalse(store.shouldAutoPrompt, "Not now must not re-prompt on entry")

    // Next launch, same user: the decline is remembered.
    let relaunched = AIConsentStore(client: ClientMock(), defaults: defaults, presentPrompt: {})
    await relaunched.refresh(userID: "u1")
    XCTAssertFalse(relaunched.allowsAI)
    XCTAssertFalse(relaunched.shouldAutoPrompt)
  }

  func testLegacyBackendIsUnknownAndNotReReadUntilStale() async {
    let client = ClientMock()
    client.getResult = .failure(AIConsentHTTPClient.Error.rejected(status: 404, message: nil))
    let store = makeStore(client)
    await store.refresh(userID: "u1")

    XCTAssertEqual(store.status, .unknown)
    XCTAssertTrue(store.allowsAI)
    XCTAssertFalse(store.shouldAutoPrompt)

    await store.refreshIfStale()
    XCTAssertEqual(client.getCalls, 1, "a 404 is trusted for a while")

    clock += AIConsentStore.freshness + 1
    await store.refreshIfStale()
    XCTAssertEqual(client.getCalls, 2)
  }

  func testOtherReadFailuresStayUnknownAndRetryOnNextEntry() async {
    let client = ClientMock()
    client.getResult = .failure(Offline())
    let store = makeStore(client)
    await store.refresh(userID: "u1")
    XCTAssertEqual(store.status, .unknown)

    client.getResult = .success(AIConsentDTO(consentedAt: "2026-10-14T10:00:00Z"))
    await store.refreshIfStale()
    XCTAssertEqual(client.getCalls, 2)
    XCTAssertEqual(store.status, .consented)

    await store.refreshIfStale()
    XCTAssertEqual(client.getCalls, 2, "a fresh answer is not re-read")
  }

  func testResponseForPreviousUserIsDropped() async {
    let client = ClientMock()
    let store = makeStore(client)
    // User A's read is in flight when the session switches to user B.
    client.getResult = .success(AIConsentDTO(consentedAt: "2026-10-14T10:00:00Z"))
    client.onGet = { [unowned store] in
      client.onGet = nil
      store.reset()
    }
    await store.refresh(userID: "user-a")
    XCTAssertEqual(store.status, .unknown, "A's consent must not land after the switch")

    client.getResult = .success(AIConsentDTO(consentedAt: nil))
    await store.refresh(userID: "user-b")
    XCTAssertEqual(store.status, .notConsented)
  }

  func testServerConsentRequiredFlipsStateAndPromptsUntilDeclined() async {
    let client = ClientMock()
    client.getResult = .failure(Offline())
    let store = makeStore(client)
    await store.refresh(userID: "u1")

    AIConsentRequired.post()
    XCTAssertEqual(store.status, .notConsented)
    XCTAssertEqual(prompts, 1)

    store.decline()
    AIConsentRequired.post()
    XCTAssertEqual(prompts, 1, "no prompt loop after Not now")
  }

  func testAllowRevokeAndErrorClearing() async {
    let client = ClientMock()
    let store = makeStore(client)
    await store.refresh(userID: "u1")
    store.decline()

    client.grantResult = .failure(Offline())
    let failed = await store.allow()
    XCTAssertFalse(failed)
    XCTAssertNotNil(store.errorMessage)
    store.clearError()
    XCTAssertNil(store.errorMessage)

    client.grantResult = .success(AIConsentDTO(consentedAt: "2026-10-14T10:00:00Z"))
    let allowed = await store.allow()
    XCTAssertTrue(allowed)
    XCTAssertEqual(store.status, .consented)

    let revoked = await store.revoke()
    XCTAssertTrue(revoked)
    XCTAssertEqual(store.status, .notConsented)
    XCTAssertFalse(store.shouldAutoPrompt, "turning it off is not a request to be asked again")
  }

  // MARK: - Current-password refusals

  func testEmailChangeErrorMapping() async {
    XCTAssertEqual(EmailChangeError(.api("CURRENT_PASSWORD_REQUIRED")), .currentPasswordRequired)
    XCTAssertEqual(EmailChangeError(.api("INVALID_CURRENT_PASSWORD")), .wrongPassword)
    XCTAssertEqual(EmailChangeError(.unauthorized("Invalid current password")), .wrongPassword, "legacy 401")
    XCTAssertEqual(EmailChangeError(.api("REAUTH_REQUIRED")), .reauthRequired)
    XCTAssertEqual(EmailChangeError(.api("Email already registered")), .emailAlreadyRegistered)
    XCTAssertNil(EmailChangeError(.unauthorized(nil)), "an expired token is not a wrong password")
    XCTAssertEqual(
      EmailChangeError.reauthRequired.errorDescription,
      "Your account uses Apple/Google sign-in. Contact fernando@facorreia.com to change your email."
    )
  }

  func testPasswordChangeErrorMapping() async {
    XCTAssertEqual(PasswordChangeError(.api("INVALID_CURRENT_PASSWORD")), .wrongPassword)
    XCTAssertEqual(PasswordChangeError(.unauthorized("Invalid current password")), .wrongPassword)
    XCTAssertEqual(PasswordChangeError(.api("CURRENT_PASSWORD_REQUIRED")), .currentPasswordRequired)
    XCTAssertNil(PasswordChangeError(.unauthorized(nil)))
    XCTAssertEqual(PasswordChangeError.wrongPassword.errorDescription, "Your current password is incorrect.")
  }
}
