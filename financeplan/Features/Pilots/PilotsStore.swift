import Factory
import Foundation
import Observation
import StockPlanShared

/// Whether pilots are switched on, the pilot catalogue, and the viewer's
/// follows. One shared instance, so the workspace row, the portfolio banner
/// and the pilot screens agree the moment a follow starts or stops.
@MainActor
@Observable
final class PilotsStore {
  enum Availability: Equatable {
    /// Not loaded yet, or the last load failed for a reason other than 404.
    case unknown
    case available
    /// The server answered 404: `PILOTS_ENABLED` is off.
    case unavailable
  }

  private(set) var availability: Availability = .unknown
  private(set) var pilots: [PilotSummary] = [] {
    didSet {
      politicians = pilots.filter { $0.kind == .politician }
      funds = pilots.filter { $0.kind == .fund }
    }
  }
  /// `pilots` split by kind once per load, not on every browse-screen body.
  private(set) var politicians: [PilotSummary] = []
  private(set) var funds: [PilotSummary] = []
  private(set) var follows: [PilotFollowResponse] = []
  /// Bumped when a follow is added or removed, so screens can reload what a
  /// follow creates (a new portfolio) with `.task(id:)`.
  private(set) var followsRevision = 0
  private(set) var isLoading = false
  var errorMessage: String?

  private let service: any PilotsServicing

  init(service: any PilotsServicing = Container.shared.pilotsService()) {
    self.service = service
  }

  var isAvailable: Bool { availability == .available }

  /// The load in flight, shared by every caller. It is unstructured on
  /// purpose: a screen that goes away cancels its own wait, not the load the
  /// other screens are waiting on.
  private var loadTask: Task<Void, Never>?

  func load() async {
    if let loadTask {
      await loadTask.value
      return
    }
    let task = Task {
      await performLoad()
      loadTask = nil
    }
    loadTask = task
    await task.value
  }

  private func performLoad() async {
    isLoading = true
    defer { isLoading = false }
    do {
      async let pilots = service.pilots()
      async let follows = service.follows()
      (self.pilots, self.follows) = try await (pilots, follows)
      availability = .available
      errorMessage = nil
    } catch {
      if Task.isCancelled || Self.isCancellation(error) { return }
      if Self.isFeatureOff(error) {
        availability = .unavailable
        pilots = []
        follows = []
        errorMessage = nil
      } else {
        errorMessage = error.localizedDescription
      }
    }
  }

  func insert(_ follow: PilotFollowResponse) {
    follows.removeAll { $0.id == follow.id }
    follows.insert(follow, at: 0)
    followsRevision += 1
  }

  func replace(_ follow: PilotFollowResponse) {
    guard let index = follows.firstIndex(where: { $0.id == follow.id }) else { return }
    follows[index] = follow
  }

  func remove(followId: String) {
    follows.removeAll { $0.id == followId }
    followsRevision += 1
  }

  func follows(forPilot slug: String) -> [PilotFollowResponse] {
    follows.filter { $0.pilot.slug == slug }
  }

  /// The follow that writes into this portfolio, if any. Compared without
  /// case: both sides are UUID strings and must not depend on their casing.
  func follow(forPortfolioId portfolioId: String) -> PilotFollowResponse? {
    follows.first { $0.portfolioListId?.caseInsensitiveCompare(portfolioId) == .orderedSame }
  }

  /// A request that stopped because its caller went away, however it
  /// surfaced: Swift's `CancellationError`, `URLError(.cancelled)`, or the
  /// client's `.cancelled`. Never shown to the user.
  static func isCancellation(_ error: any Error) -> Bool {
    if error is CancellationError { return true }
    if (error as? URLError)?.code == .cancelled { return true }
    if case .cancelled? = error as? PilotsHTTPClient.Error { return true }
    return false
  }

  /// Every pilots route answers 404 while the feature flag is off.
  static func isFeatureOff(_ error: any Error) -> Bool {
    (error as? any HTTPClientError)?.statusCode == 404
  }
}
