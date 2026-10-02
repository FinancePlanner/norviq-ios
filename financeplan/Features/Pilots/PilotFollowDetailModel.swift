import Factory
import Foundation
import Observation
import StockPlanShared

@MainActor
@Observable
final class PilotFollowDetailModel {
  private(set) var follow: PilotFollowResponse
  private(set) var events: [PilotFollowEventResponse] = []
  private(set) var valuePoints: [PilotValuePoint] = []
  private(set) var isLoading = false
  private(set) var isSaving = false
  /// The follow no longer exists on the server (404: stopped elsewhere, or
  /// the feature was switched off). The screen removes it and pops once the
  /// user has dismissed `errorMessage`.
  private(set) var isGone = false
  var errorMessage: String?

  private let service: any PilotsServicing
  private let store: PilotsStore

  init(
    follow: PilotFollowResponse,
    service: any PilotsServicing = Container.shared.pilotsService(),
    store: PilotsStore = Container.shared.pilotsStore()
  ) {
    self.follow = follow
    self.service = service
    self.store = store
  }

  var isPortfolio: Bool { follow.targetKind == .portfolio }
  var isPaused: Bool { follow.status == .paused }
  var latestValue: Double? { valuePoints.last?.value }
  var performance: Double? { PilotFormatting.performance(start: follow.startingCapital, latest: latestValue) }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      if isPortfolio {
        async let events = service.events(followId: follow.id)
        async let snapshots = service.snapshots(followId: follow.id)
        let (loadedEvents, loadedSnapshots) = try await (events, snapshots)
        self.events = loadedEvents
        valuePoints = PilotFormatting.valuePoints(loadedSnapshots)
      } else {
        // Watchlist follows have no value history; their feed is the event log.
        events = try await service.events(followId: follow.id)
        valuePoints = []
      }
      errorMessage = nil
    } catch {
      if Task.isCancelled || PilotsStore.isCancellation(error) { return }
      if PilotsStore.isFeatureOff(error) { return markGone() }
      errorMessage = error.localizedDescription
    }
  }

  func setPaused(_ paused: Bool) async {
    guard !isSaving else { return }
    isSaving = true
    defer { isSaving = false }
    do {
      let updated = try await service.setStatus(paused ? .paused : .active, followId: follow.id)
      follow = updated
      store.replace(updated)
      errorMessage = nil
    } catch {
      if PilotsStore.isCancellation(error) { return }
      if PilotsStore.isFeatureOff(error) { return markGone() }
      errorMessage = error.localizedDescription
    }
  }

  /// A 404: say why, and keep the follow in the store until the user has read
  /// it (`acknowledgeGone()`), so the link that opened this screen doesn't
  /// disappear and pop it first.
  private func markGone() {
    isGone = true
    errorMessage = String(localized: "This follow isn't available any more.")
  }

  /// The user dismissed the "isn't available" alert: drop the follow
  /// everywhere. The screen pops right after.
  func acknowledgeGone() {
    guard isGone else { return }
    store.remove(followId: follow.id)
  }

  /// True once the follow is gone, so the screen can pop. A 404 means it was
  /// already stopped elsewhere, or the feature was switched off.
  func stop() async -> Bool {
    guard !isSaving else { return false }
    isSaving = true
    defer { isSaving = false }
    do {
      try await service.stopFollowing(followId: follow.id)
    } catch let error where PilotsStore.isFeatureOff(error) {
      // Nothing left to stop.
    } catch {
      if PilotsStore.isCancellation(error) { return false }
      errorMessage = error.localizedDescription
      return false
    }
    store.remove(followId: follow.id)
    errorMessage = nil
    return true
  }
}
