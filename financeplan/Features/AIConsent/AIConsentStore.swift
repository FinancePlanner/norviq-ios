import Foundation
import Observation
import OSLog

/// Whether the signed-in user allowed Norviq to send their data to the
/// third-party AI providers (Anthropic, OpenRouter).
///
/// The backend is the source of truth and enforces it with
/// `403 AI_CONSENT_REQUIRED` for clients that send the `ai-consent-v1`
/// capability (see `ClientCapabilities`). This store only decides when to ask:
/// - `.notConsented` (the server said `consentedAt: null`) gates AI surfaces
///   and prompts on first entry.
/// - `.unknown` (not loaded yet, or the read failed) never blocks; a 403 flips
///   it to `.notConsented`, and the next AI-surface entry reads it again.
@Observable @MainActor
final class AIConsentStore {
  enum Status: Equatable {
    case unknown
    case consented
    case notConsented
  }

  private(set) var status: Status = .unknown
  private(set) var isSaving = false
  private(set) var errorMessage: String?

  @ObservationIgnored private let client: any AIConsentClientProtocol
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let presentPrompt: @MainActor () -> Void
  @ObservationIgnored private let now: @MainActor () -> Date
  @ObservationIgnored private var userID = ""
  /// Bumped on every user change and reset. A response that started under an
  /// older generation is dropped, so user A's answer never lands on user B.
  @ObservationIgnored private var generation = 0
  /// When the flag was last read. nil forces a read on the next entry.
  @ObservationIgnored private var lastReadAt: Date?
  @ObservationIgnored private var declinedThisSession = false
  @ObservationIgnored private var observer: (any NSObjectProtocol)?
  @ObservationIgnored private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "AIConsentStore"
  )

  /// How long a successful read (or a legacy-backend answer) is trusted.
  static let freshness: TimeInterval = 5 * 60

  init(
    client: any AIConsentClientProtocol,
    defaults: UserDefaults = .standard,
    now: @escaping @MainActor () -> Date = { Date() },
    presentPrompt: @escaping @MainActor () -> Void = { AIConsentPresenter.shared.present() }
  ) {
    self.client = client
    self.defaults = defaults
    self.now = now
    self.presentPrompt = presentPrompt
    observer = NotificationCenter.default.addObserver(
      forName: .aiConsentRequired,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.consentRequiredByServer() }
    }
  }

  /// False only when the server has said the user has not consented.
  var allowsAI: Bool { status != .notConsented }

  var isConsented: Bool { status == .consented }

  /// Ask on entry to an AI surface — unless the user already said "Not now"
  /// (or turned sharing off) on this device. They can still allow from the
  /// surface's disabled state or from assistant settings.
  var shouldAutoPrompt: Bool {
    status == .notConsented && !declinedThisSession && !hasDeclinedOnDevice
  }

  // MARK: - Lifecycle

  /// Called once the session is authenticated, with the signed-in user.
  func refresh(userID: String) async {
    if userID != self.userID {
      generation += 1
      self.userID = userID
      status = .unknown
      lastReadAt = nil
      declinedThisSession = false
      errorMessage = nil
    }
    await read()
  }

  /// On app foreground and AI-surface entry: re-reads when the flag is
  /// unknown or older than `freshness`.
  func refreshIfStale() async {
    guard !userID.isEmpty else { return }
    // `lastReadAt` is nil when never read or when the last read failed for a
    // reason worth retrying; a legacy-backend answer sets it like a success.
    if let lastReadAt, now().timeIntervalSince(lastReadAt) < Self.freshness {
      return
    }
    await read()
  }

  func reset() {
    generation += 1
    status = .unknown
    userID = ""
    lastReadAt = nil
    declinedThisSession = false
    errorMessage = nil
    isSaving = false
  }

  // MARK: - User actions

  @discardableResult
  func allow() async -> Bool {
    await save { try await self.client.grant() }
  }

  /// Revoke from settings. Also counts as "don't ask again" on this device.
  @discardableResult
  func revoke() async -> Bool {
    let saved = await save { try await self.client.revoke() }
    if saved { setDeclinedOnDevice(true) }
    return saved
  }

  /// "Not now" in the consent sheet.
  func decline() {
    declinedThisSession = true
    setDeclinedOnDevice(true)
  }

  /// The sheet clears a stale failure each time it is shown.
  func clearError() {
    errorMessage = nil
  }

  /// Presents the consent sheet (once, app-wide) for an explicit request.
  func requestPrompt() {
    presentPrompt()
  }

  private func consentRequiredByServer() {
    status = .notConsented
    lastReadAt = now()
    guard !declinedThisSession else { return }
    presentPrompt()
  }

  // MARK: - Private

  private func read() async {
    let started = generation
    do {
      let dto = try await client.get()
      guard started == generation else { return }
      apply(dto)
    } catch {
      guard started == generation else { return }
      let status = (error as? AIConsentHTTPClient.Error)?.statusCode
      logger.warning("ai consent read failed (\(status ?? 0, privacy: .public)): \(error.localizedDescription, privacy: .public)")
      // Never block on an unreadable flag — the backend's 403 decides.
      self.status = .unknown
      // 400/404: a backend without the route. Trust that answer for a while;
      // anything else (offline, 5xx) is retried on the next AI-surface entry.
      lastReadAt = (status == 400 || status == 404) ? now() : nil
    }
  }

  private func save(_ request: @escaping () async throws -> AIConsentDTO) async -> Bool {
    let started = generation
    isSaving = true
    errorMessage = nil
    defer { if started == generation { isSaving = false } }
    do {
      let dto = try await request()
      guard started == generation else { return false }
      apply(dto)
      return true
    } catch {
      guard started == generation else { return false }
      logger.warning("ai consent write failed: \(error.localizedDescription, privacy: .public)")
      errorMessage = String(localized: "Couldn't save your choice. Check your connection and try again.")
      return false
    }
  }

  private func apply(_ dto: AIConsentDTO) {
    let consented = dto.consentedAt.map { !$0.isEmpty } ?? false
    status = consented ? .consented : .notConsented
    lastReadAt = now()
    if consented {
      declinedThisSession = false
      setDeclinedOnDevice(false)
    }
  }

  private var declinedKey: String? {
    userID.isEmpty ? nil : "ai_consent_declined.\(userID)"
  }

  private var hasDeclinedOnDevice: Bool {
    guard let declinedKey else { return false }
    return defaults.bool(forKey: declinedKey)
  }

  private func setDeclinedOnDevice(_ declined: Bool) {
    guard let declinedKey else { return }
    if declined {
      defaults.set(true, forKey: declinedKey)
    } else {
      defaults.removeObject(forKey: declinedKey)
    }
  }
}
