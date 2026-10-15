import Factory
import Foundation
import Observation
import StockPlanShared

/// The "Market brief alerts" switch: one push per brief, written in the app's
/// language. Off by default on the server.
///
/// Shared, so the switch in Settings and the language watcher on the home
/// screen agree on what the server holds.
@MainActor
@Observable
final class MarketBriefAlertsStore {
  private(set) var isEnabled = false
  private(set) var isLoading = false
  private(set) var errorMessage: String?
  /// The language the server sends pushes in, as last read or written.
  private(set) var serverLanguage: String?

  private let service: any MarketBriefServicing
  /// Turns push notifications on (asking for permission when needed) and
  /// returns whether the user is now opted in.
  private let ensurePushOptIn: @MainActor () async -> Bool

  init(
    service: any MarketBriefServicing = Container.shared.marketBriefService(),
    ensurePushOptIn: @escaping @MainActor () async -> Bool = MarketBriefAlertsStore.ensurePushOptInWithCoordinator
  ) {
    self.service = service
    self.ensurePushOptIn = ensurePushOptIn
  }

  /// Reads the server's switch. When it is on in another language (the app
  /// language changed while Settings was closed), it is rewritten.
  func load(language: String) async {
    isLoading = true
    defer { isLoading = false }
    do {
      let preferences = try await service.notificationPreferences()
      apply(preferences)
      errorMessage = nil
      if preferences.enabled, preferences.language != language {
        await write(enabled: true, language: language)
      }
    } catch {
      errorMessage = String(localized: "Couldn't load market brief alerts.")
    }
  }

  /// Turning the switch on also turns push notifications on, through the same
  /// permission flow as earnings reminders.
  func setEnabled(_ enabled: Bool, language: String) async {
    let previous = isEnabled
    isEnabled = enabled
    if enabled {
      guard await ensurePushOptIn() else {
        isEnabled = previous
        return
      }
    }
    isLoading = true
    defer { isLoading = false }
    await write(enabled: enabled, language: language, rollingBackTo: previous)
  }

  /// The app language changed: pushes follow it while the switch is on.
  func languageChanged(to language: String) async {
    if serverLanguage == nil {
      await load(language: language)
      return
    }
    guard isEnabled, serverLanguage != language else { return }
    await write(enabled: true, language: language)
  }

  /// Sign-out: the next account starts from the server's value.
  func reset() {
    isEnabled = false
    isLoading = false
    errorMessage = nil
    serverLanguage = nil
  }

  private func write(enabled: Bool, language: String, rollingBackTo previous: Bool? = nil) async {
    let previous = previous ?? isEnabled
    isEnabled = enabled
    do {
      let preferences = try await service.updateNotificationPreferences(enabled: enabled, language: language)
      apply(preferences)
      errorMessage = nil
    } catch {
      isEnabled = previous
      errorMessage = String(localized: "Couldn't update market brief alerts.")
    }
  }

  private func apply(_ preferences: MarketBriefNotificationPreferences) {
    isEnabled = preferences.enabled
    serverLanguage = preferences.language
  }

  static func ensurePushOptInWithCoordinator() async -> Bool {
    let coordinator = Container.shared.pushNotificationsCoordinator()
    if !coordinator.isOptedIn {
      await coordinator.setNotificationsEnabled(true)
    }
    return coordinator.isOptedIn
  }
}
