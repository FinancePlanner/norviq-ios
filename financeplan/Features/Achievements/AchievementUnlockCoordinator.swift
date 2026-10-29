import Foundation
import Observation

/// Finds new unlocks when the app comes forward and holds them for the
/// celebration sheet. Unlocks are marked seen before they are shown, so a
/// failure shows nothing rather than the same celebration over and over.
@MainActor
@Observable
final class AchievementUnlockCoordinator {
  private(set) var pending: [AchievementUnlock] = []
  /// False while another sheet covers the screen (settings, paywall,
  /// capture, assistant); the celebration waits for it to close.
  private(set) var isContextEligible = true
  private var isChecking = false

  private let service: any AchievementsServicing
  private let isEnabled: () -> Bool
  private let onCelebrated: (AchievementUnlock) -> Void

  init(
    service: any AchievementsServicing,
    isEnabled: @escaping () -> Bool,
    onCelebrated: @escaping (AchievementUnlock) -> Void
  ) {
    self.service = service
    self.isEnabled = isEnabled
    self.onCelebrated = onCelebrated
  }

  var isPresented: Bool { !pending.isEmpty && isContextEligible }

  func setContextEligible(_ eligible: Bool) {
    isContextEligible = eligible
  }

  func checkForUnlocks() async {
    guard isEnabled(), !isChecking, pending.isEmpty else { return }
    isChecking = true
    defer { isChecking = false }
    do {
      let unlocks = try await service.unseen()
      guard !unlocks.isEmpty else { return }
      try await service.markSeen(unlocks.map(\.id))
      pending = unlocks
    } catch {
      // Nothing shown; the next foregrounding tries again.
    }
  }

  func dismiss() {
    guard let first = pending.first else { return }
    pending = []
    onCelebrated(first)
  }
}
