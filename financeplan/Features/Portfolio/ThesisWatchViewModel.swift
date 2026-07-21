import Factory
import Foundation
import Observation
import StockPlanShared

@MainActor
@Observable
final class ThesisWatchViewModel {
  private let service: any NewsServicing

  private(set) var stories: [ThesisWatchStory] = []
  private(set) var capabilities: ThesisWatchCapabilities?
  private(set) var nextCursor: String?
  private(set) var isLoading = false
  private(set) var isLoadingMore = false
  private(set) var notificationsEnabled = false
  private(set) var errorMessage: String?
  var scope: ThesisWatchScope = .forYou

  init(service: any NewsServicing = Container.shared.newsService()) {
    self.service = service
  }

  func load(force: Bool = false) async {
    guard !isLoading, force || stories.isEmpty else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      let response = try await service.thesisWatch(scope: scope, sector: nil, cursor: nil, limit: 20)
      stories = response.items
      capabilities = response.capabilities
      nextCursor = response.nextCursor
      if response.capabilities.isPro {
        notificationsEnabled = try await service.thesisWatchNotificationPreferences().enabled
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func selectScope(_ newScope: ThesisWatchScope) async {
    guard scope != newScope else { return }
    scope = newScope
    stories = []
    await load(force: true)
  }

  func loadMore() async {
    guard !isLoadingMore, let nextCursor else { return }
    isLoadingMore = true
    defer { isLoadingMore = false }
    do {
      let response = try await service.thesisWatch(scope: scope, sector: nil, cursor: nextCursor, limit: 20)
      stories.append(contentsOf: response.items)
      self.nextCursor = response.nextCursor
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func markRead(_ story: ThesisWatchStory) async {
    try? await service.markThesisWatchRead(storyId: story.id)
  }

  func sendFeedback(_ signal: ThesisWatchFeedbackSignal, for story: ThesisWatchStory) async {
    do {
      try await service.sendThesisWatchFeedback(storyId: story.id, signal: signal)
      await load(force: true)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func setNotificationsEnabled(_ enabled: Bool) async {
    do {
      let timezone = TimeZone.current.identifier
      let preferences = try await service.updateThesisWatchNotificationPreferences(
        enabled: enabled,
        timezone: timezone
      )
      notificationsEnabled = preferences.enabled
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
