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
    } catch is CancellationError {
      return
    } catch {
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
      errorMessage = error.localizedDescription
    }
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
      errorMessage = error.localizedDescription
      return false
    }
    store.remove(followId: follow.id)
    errorMessage = nil
    return true
  }
}
