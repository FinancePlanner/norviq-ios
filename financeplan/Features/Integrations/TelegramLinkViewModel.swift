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

  private let service: any TelegramLinkServiceProtocol

  init(service: any TelegramLinkServiceProtocol) {
    self.service = service
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
      await load()
    } catch {
      errorMessage = error.localizedDescription
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
