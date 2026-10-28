import Factory
import Foundation
import Observation

/// The Achievements screen: the catalogue as the server sees it, plus
/// pinning up to three of them to the profile showcase.
@MainActor
@Observable
final class AchievementsStore {
  static let showcaseLimit = 3

  private(set) var response: AchievementsResponse?
  private(set) var isLoading = false
  private(set) var loadError: String?
  /// A failed pin or unpin; the screen shows it once and clears it.
  var actionError: String?
  private(set) var isSavingShowcase = false

  private let service: any AchievementsServicing

  init(service: any AchievementsServicing) {
    self.service = service
  }

  convenience init() {
    self.init(service: Container.shared.achievementsService())
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      response = try await service.list()
      loadError = nil
    } catch {
      loadError = error.localizedDescription
    }
  }

  func pin(_ achievement: Achievement) async {
    guard let response, Self.canPin(achievement), let tier = achievement.currentTier else { return }
    var items = Self.pinnedItems(in: response)
    guard !items.contains(where: { $0.key == achievement.key }) else { return }
    guard items.count < Self.showcaseLimit else {
      actionError = String(localized: "You can pin up to 3 achievements.")
      return
    }
    items.append(AchievementShowcaseItem(key: achievement.key, tier: tier))
    await saveShowcase(items)
  }

  func unpin(_ achievement: Achievement) async {
    guard let response else { return }
    let items = Self.pinnedItems(in: response).filter { $0.key != achievement.key }
    await saveShowcase(items)
  }

  func isPinned(_ achievement: Achievement) -> Bool {
    achievement.tiers.contains { $0.showcaseRank != nil }
  }

  private func saveShowcase(_ items: [AchievementShowcaseItem]) async {
    isSavingShowcase = true
    defer { isSavingShowcase = false }
    do {
      response = try await service.setShowcase(items)
    } catch {
      actionError = String(localized: "Couldn't update your showcase. Try again.")
    }
  }

  // MARK: - Pure helpers

  /// The current showcase as the server expects it back, in rank order.
  static func pinnedItems(in response: AchievementsResponse) -> [AchievementShowcaseItem] {
    pinnedTiers(in: response).map { AchievementShowcaseItem(key: $0.achievement.key, tier: $0.tier.tier) }
  }

  /// Pinned achievements in rank order.
  static func showcase(in response: AchievementsResponse) -> [Achievement] {
    pinnedTiers(in: response).map(\.achievement)
  }

  /// Earned (at least one tier), visible, and not a performance achievement:
  /// friends may not be allowed to see performance, so it never headlines.
  static func canPin(_ achievement: Achievement) -> Bool {
    guard achievement.state != .hidden, !achievement.isPerformance else { return false }
    return achievement.currentTier != nil
  }

  private static func pinnedTiers(in response: AchievementsResponse) -> [(achievement: Achievement, tier: AchievementTier)] {
    response.achievements
      .flatMap { achievement in
        achievement.tiers.compactMap { tier in tier.showcaseRank.map { (achievement, tier, $0) } }
      }
      .sorted { $0.2 < $1.2 }
      .map { (achievement: $0.0, tier: $0.1) }
  }
}
