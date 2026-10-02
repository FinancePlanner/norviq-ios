import Factory
import Foundation
import Observation
import StockPlanShared

@MainActor
@Observable
final class FollowPilotModel {
  let pilot: PilotSummary
  /// One key per sheet. The backend replays a cached success for the same key,
  /// so a double tap or a retry after a dropped response creates one follow.
  let idempotencyKey: String
  var target: PilotFollowTargetKind
  var capitalText = "10000"
  /// Nil means "let Norviq create a new watchlist".
  var watchlistListId: String?
  private(set) var watchlists: [WatchlistListDTOResponse] = []
  private(set) var isSubmitting = false
  var failure: PilotFollowFailure?

  private let service: any PilotsServicing
  private let store: PilotsStore

  init(
    pilot: PilotSummary,
    isPro: Bool,
    idempotencyKey: String = UUID().uuidString,
    service: any PilotsServicing = Container.shared.pilotsService(),
    store: PilotsStore = Container.shared.pilotsStore()
  ) {
    self.pilot = pilot
    self.idempotencyKey = idempotencyKey
    self.target = isPro ? .portfolio : .watchlist
    self.service = service
    self.store = store
  }

  var capital: Double? { MoneyInputParser.parse(capitalText) }

  /// Why the form can't be sent yet, or nil.
  var formProblem: String? {
    target == .portfolio ? PilotFollowRules.capitalProblem(text: capitalText) : nil
  }

  var failureMessage: String? {
    if case let .message(text)? = failure { return text }
    return nil
  }

  /// Simulated portfolios are Pro; Free follows into a watchlist.
  func requiresPro(isPro: Bool) -> Bool {
    target == .portfolio && !isPro
  }

  func loadWatchlists() async {
    watchlists = (try? await service.watchlists()) ?? []
  }

  func makeRequest() -> PilotFollowCreateRequest? {
    switch target {
    case .portfolio:
      guard PilotFollowRules.capitalProblem(text: capitalText) == nil, let capital else { return nil }
      return PilotFollowCreateRequest(
        pilotSlug: pilot.slug, targetKind: .portfolio,
        portfolioListId: nil, watchlistListId: nil, startingCapital: capital
      )
    case .watchlist:
      return PilotFollowCreateRequest(
        pilotSlug: pilot.slug, targetKind: .watchlist,
        portfolioListId: nil, watchlistListId: watchlistListId, startingCapital: nil
      )
    }
  }

  /// The new follow, or nil with `failure` set.
  func submit(isPro: Bool) async -> PilotFollowResponse? {
    guard !isSubmitting else { return nil }
    if requiresPro(isPro: isPro) {
      failure = .needsPro
      return nil
    }
    guard let request = makeRequest() else {
      failure = formProblem.map(PilotFollowFailure.message)
      return nil
    }
    isSubmitting = true
    defer { isSubmitting = false }
    do {
      let follow = try await service.follow(request, idempotencyKey: idempotencyKey)
      store.insert(follow)
      failure = nil
      return follow
    } catch {
      // A cancelled attempt is not a failure; the same key makes a retry safe.
      if PilotsStore.isCancellation(error) { return nil }
      failure = PilotFollowFailure.from(error, isPro: isPro)
      return nil
    }
  }
}
