import Factory
import Foundation
import SwiftUI

@Observable
@MainActor
final class TelegramLinkViewModel {
  private(set) var status: TelegramStatus?
  private(set) var alerts: [TelegramAlertPreference] = []
  /// Set only by an explicit Connect tap. Cleared once the link is confirmed,
  /// because the plaintext is meaningless afterwards.
  private(set) var pairingCode: TelegramPairingCode?
  private(set) var isLoading = false
  private(set) var isWorking = false
  private(set) var errorMessage: String?
  /// The user tapped "I understand" on the Telegram privacy notice. Kept per
  /// user on this device and cleared on disconnect, so it is shown once per link.
  private(set) var hasAcknowledgedPrivacy = false

  private let service: any TelegramLinkServiceProtocol
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let currentUserID: @MainActor () async -> String
  @ObservationIgnored private var acknowledgementKey: String?

  init(
    service: any TelegramLinkServiceProtocol,
    defaults: UserDefaults = .standard,
    currentUserID: @escaping @MainActor () async -> String = {
      await Container.shared.authSessionStore().currentUserID
    }
  ) {
    self.service = service
    self.defaults = defaults
    self.currentUserID = currentUserID
  }

  convenience init() {
    self.init(service: Container.shared.telegramLinkService())
  }

  var isAvailable: Bool { status?.available ?? false }
  var isConnected: Bool { status?.connected ?? false }
  var botHandle: String {
    guard let username = status?.botUsername, !username.isEmpty else { return "" }
    return "@" + username
  }

  /// Re-read on every appearance. The link is completed *in Telegram*, so the
  /// app cannot be told about it — returning to this screen is the signal.
  func load() async {
    isLoading = true
    defer { isLoading = false }
    await loadPrivacyAcknowledgement()
    do {
      let status = try await service.status()
      self.status = status
      if status.connected {
        pairingCode = nil
        alerts = try await service.preferences()
      } else {
        alerts = []
      }
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func connect() async {
    // No pairing code until the privacy notice was acknowledged — enforced
    // here, not only by the view hiding the button.
    if !hasAcknowledgedPrivacy { await loadPrivacyAcknowledgement() }
    guard hasAcknowledgedPrivacy else {
      errorMessage = String(localized: "Read and acknowledge the Telegram privacy notice first.")
      return
    }
    isWorking = true
    defer { isWorking = false }
    do {
      pairingCode = try await service.createCode()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func disconnect() async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await service.disconnect()
      pairingCode = nil
      setPrivacyAcknowledged(false)
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func acknowledgePrivacy() {
    setPrivacyAcknowledged(true)
  }

  private func loadPrivacyAcknowledgement() async {
    if acknowledgementKey == nil {
      let userID = await currentUserID()
      acknowledgementKey = userID.isEmpty ? nil : "telegram_privacy_ack.\(userID)"
    }
    guard let acknowledgementKey else { return }
    hasAcknowledgedPrivacy = defaults.bool(forKey: acknowledgementKey)
  }

  private func setPrivacyAcknowledged(_ acknowledged: Bool) {
    hasAcknowledgedPrivacy = acknowledged
    guard let acknowledgementKey else { return }
    if acknowledged {
      defaults.set(true, forKey: acknowledgementKey)
    } else {
      defaults.removeObject(forKey: acknowledgementKey)
    }
  }

  func setAlert(kind: String, enabled: Bool) async {
    isWorking = true
    defer { isWorking = false }
    do {
      alerts = try await service.setAlert(kind: kind, enabled: enabled)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Prefers the Telegram app, falling back to the web client when it is not
  /// installed — the same shape used for sharing to Discord elsewhere.
  func openTelegram(using openURL: OpenURLAction) {
    guard let code = pairingCode else { return }
    guard let username = status?.botUsername, !username.isEmpty,
          let appURL = URL(string: "tg://resolve?domain=\(username)&start=\(code.code)"),
          let webURL = URL(string: code.deepLink)
    else { return }
    openURL(appURL) { accepted in
      if !accepted {
        openURL(webURL)
      }
    }
  }
}
