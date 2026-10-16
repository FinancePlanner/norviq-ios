import Factory
import Foundation
import Observation
import StockPlanShared

/// Drives the dashboard's market brief card. Cache first for an instant paint,
/// then the network, written through (the same shape as `NewsTickerViewModel`).
///
/// Hidden whenever there is nothing worth a card: the feature is off, no brief
/// exists yet, or the first load failed with nothing cached. A failed refresh
/// keeps what is already on screen.
@MainActor
@Observable
final class MarketBriefViewModel {
  enum State: Equatable {
    /// Nothing to show yet. The card renders nothing rather than a placeholder,
    /// so a disabled feature never flashes a skeleton on every launch.
    case loading
    case hidden
    case loaded(MarketBriefResponse, isLatest: Bool)
  }

  /// The Latest | Previous control.
  enum Selection: Hashable {
    case latest
    case previous
  }

  private(set) var state: State = .loading
  /// Bound to the segmented control; `select(_:)` acts on it.
  var selection: Selection = .latest
  /// True while a specific (non-latest) brief is on its way.
  private(set) var isFetching = false
  /// `en` or `pt-PT`.
  private(set) var language: String
  /// The latest brief in `language`, whatever is on screen.
  private(set) var latest: MarketBriefResponse?

  private let service: any MarketBriefServicing
  private let cache: any MarketBriefCaching
  private let now: () -> Date
  private var hasLoaded = false
  private var lastFetchedAt: Date?
  /// Bumped by every explicit "show this brief" request; an answer that comes
  /// back after a newer request is dropped.
  private var displayGeneration = 0

  init(
    language: String = AppLanguage.stored.rawValue,
    service: any MarketBriefServicing = Container.shared.marketBriefService(),
    cache: any MarketBriefCaching = Container.shared.marketBriefCache(),
    now: @escaping () -> Date = Date.init
  ) {
    self.language = language
    self.service = service
    self.cache = cache
    self.now = now
  }

  /// Whether the Latest | Previous control has anything to switch between.
  var showsSelector: Bool {
    if case .loaded(_, isLatest: false) = state { return true }
    return latest?.previous != nil
  }

  // MARK: Loading

  func loadIfNeeded() async {
    await loadIfNeeded(language: language)
  }

  /// Paints the cached brief for `language`, then refreshes. A new language
  /// starts over: the brief is a different document in each.
  func loadIfNeeded(language newLanguage: String) async {
    if newLanguage != language {
      reset(language: newLanguage)
    }
    guard !hasLoaded else { return }
    hasLoaded = true
    if let cached = cache.latest(language: language), Self.isDisplayable(cached) {
      latest = cached
      if case .loading = state {
        display(cached, isLatest: true)
      }
    }
    await refresh()
  }

  /// Fetches the latest brief and writes it through to the cache.
  func refresh() async {
    let requestLanguage = language
    do {
      let response = try await service.latestBrief(language: requestLanguage)
      guard requestLanguage == language else { return }
      lastFetchedAt = now()
      guard Self.isDisplayable(response) else {
        // Off, or nothing generated yet: no card, and nothing stale to paint next launch.
        latest = nil
        cache.remove(language: requestLanguage)
        state = .hidden
        selection = .latest
        return
      }
      latest = response
      cache.store(response, language: requestLanguage)
      applyFreshLatest(response)
    } catch {
      guard requestLanguage == language, !Task.isCancelled else { return }
      // Keep a brief that is already on screen; only a first failure hides the card.
      if case .loaded = state { return }
      if isFetching { return }
      state = .hidden
    }
  }

  /// Refreshes only when the last successful fetch is older than `maxAge`.
  func refreshIfStale(maxAge: TimeInterval) async {
    if let lastFetchedAt, now().timeIntervalSince(lastFetchedAt) < maxAge { return }
    await refresh()
  }

  // MARK: Latest | Previous

  /// Called when the segmented control changes. A no-op when the card already
  /// shows that side, so programmatic changes to `selection` never refetch.
  func select(_ newSelection: Selection) async {
    switch newSelection {
    case .latest:
      if case .loaded(_, isLatest: true) = state { return }
      await showLatest()
    case .previous:
      if case .loaded(_, isLatest: false) = state { return }
      await showPrevious()
    }
  }

  /// The brief before the latest one, e.g. last night's recap behind this
  /// morning's brief.
  func showPrevious() async {
    guard let ref = latest?.previous else {
      selection = .latest
      return
    }
    await show(ref)
  }

  func showLatest() async {
    displayGeneration += 1
    isFetching = false
    if let latest {
      display(latest, isLatest: true)
    } else {
      selection = .latest
      // The first load is already on its way; it will show the latest brief.
      guard hasLoaded else { return }
      await refresh()
    }
  }

  /// One exact brief, e.g. from a push. A missing brief (404) or a failure
  /// leaves the card on the latest one.
  func show(slot: MarketBriefSlot, date: String) async {
    await show(MarketBriefRef(slot: slot, tradingDate: date))
  }

  /// A push or link handed over by `MarketBriefRouter`.
  func handle(_ request: MarketBriefRouter.Request) async {
    if let ref = request.ref {
      await show(ref)
    } else {
      await showLatest()
    }
  }

  // MARK: Private

  private func show(_ ref: MarketBriefRef) async {
    displayGeneration += 1
    let generation = displayGeneration
    if let latest, Self.matches(latest, ref) {
      isFetching = false
      display(latest, isLatest: true)
      return
    }
    let requestLanguage = language
    isFetching = true
    defer {
      if generation == displayGeneration { isFetching = false }
    }
    do {
      let brief = try await service.brief(language: requestLanguage, slot: ref.slot, date: ref.tradingDate)
      guard generation == displayGeneration, requestLanguage == language else { return }
      guard brief.enabled else {
        state = .hidden
        selection = .latest
        return
      }
      guard Self.isDisplayable(brief) else {
        fallBackToLatest()
        return
      }
      let isLatest = latest.map { Self.matches($0, brief) } ?? false
      display(brief, isLatest: isLatest)
    } catch {
      guard generation == displayGeneration, requestLanguage == language, !Task.isCancelled else { return }
      fallBackToLatest()
    }
  }

  private func fallBackToLatest() {
    if let latest {
      display(latest, isLatest: true)
    } else {
      selection = .latest
    }
  }

  /// A fresh latest brief replaces what is on screen unless the reader moved to
  /// an older brief, or asked for one that is still on its way.
  private func applyFreshLatest(_ response: MarketBriefResponse) {
    switch state {
    case .loaded where isFetching:
      return
    case let .loaded(shown, isLatest: false) where !Self.matches(shown, response):
      return
    default:
      display(response, isLatest: true)
    }
  }

  private func display(_ brief: MarketBriefResponse, isLatest: Bool) {
    state = .loaded(brief, isLatest: isLatest)
    selection = isLatest ? .latest : .previous
  }

  private func reset(language newLanguage: String) {
    language = newLanguage
    displayGeneration += 1
    hasLoaded = false
    isFetching = false
    lastFetchedAt = nil
    latest = nil
    selection = .latest
    state = .loading
  }

  static func isDisplayable(_ brief: MarketBriefResponse) -> Bool {
    brief.enabled && brief.tradingDate != nil && brief.slot != nil
  }

  static func matches(_ brief: MarketBriefResponse, _ ref: MarketBriefRef) -> Bool {
    brief.slot == ref.slot && brief.tradingDate == ref.tradingDate
  }

  static func matches(_ lhs: MarketBriefResponse, _ rhs: MarketBriefResponse) -> Bool {
    lhs.slot == rhs.slot && lhs.tradingDate == rhs.tradingDate
  }
}
