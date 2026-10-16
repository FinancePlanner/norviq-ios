import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class MarketBriefViewModelTests: XCTestCase {
  // MARK: Hidden states

  func testDisabledFeatureHidesCardAndClearsCache() async {
    let cache = MarketBriefCache(directory: nil)
    cache.store(makeBrief(slot: .morning, date: "2026-10-14"), language: "en")
    let service = MarketBriefServiceStub()
    service.latestResult = .success(.empty(language: "en", enabled: false))
    let viewModel = MarketBriefViewModel(language: "en", service: service, cache: cache)

    await viewModel.loadIfNeeded()

    XCTAssertEqual(viewModel.state, .hidden)
    XCTAssertNil(cache.latest(language: "en"), "nothing stale to paint on the next launch")
  }

  func testNothingGeneratedYetHidesCard() async {
    let service = MarketBriefServiceStub()
    service.latestResult = .success(.empty(language: "en", enabled: true))
    let viewModel = MarketBriefViewModel(language: "en", service: service, cache: MarketBriefCache(directory: nil))

    await viewModel.loadIfNeeded()

    XCTAssertEqual(viewModel.state, .hidden)
    XCTAssertFalse(viewModel.showsSelector)
  }

  func testFirstLoadErrorHidesCard() async {
    let service = MarketBriefServiceStub()
    service.latestResult = .failure(URLError(.notConnectedToInternet))
    let viewModel = MarketBriefViewModel(language: "en", service: service, cache: MarketBriefCache(directory: nil))

    await viewModel.loadIfNeeded()

    XCTAssertEqual(viewModel.state, .hidden)
  }

  // MARK: Loaded

  func testLoadedShowsLatestAndWritesThroughToCache() async {
    let cache = MarketBriefCache(directory: nil)
    let brief = makeBrief(slot: .morning, date: "2026-10-15", previous: MarketBriefRef(slot: .evening, tradingDate: "2026-10-14"))
    let service = MarketBriefServiceStub()
    service.latestResult = .success(brief)
    let viewModel = MarketBriefViewModel(language: "en", service: service, cache: cache)

    await viewModel.loadIfNeeded()

    XCTAssertEqual(viewModel.state, .loaded(brief, isLatest: true))
    XCTAssertEqual(viewModel.selection, .latest)
    XCTAssertTrue(viewModel.showsSelector)
    XCTAssertEqual(cache.latest(language: "en"), brief)
    XCTAssertEqual(service.calls, [.init(language: "en", slot: nil, date: nil)])
  }

  func testCachedBriefPaintsFirstAndSurvivesNetworkFailure() async {
    let cache = MarketBriefCache(directory: nil)
    let cached = makeBrief(slot: .evening, date: "2026-10-14")
    cache.store(cached, language: "en")
    let service = MarketBriefServiceStub()
    service.latestResult = .failure(URLError(.timedOut))
    let viewModel = MarketBriefViewModel(language: "en", service: service, cache: cache)

    await viewModel.loadIfNeeded()

    XCTAssertEqual(viewModel.state, .loaded(cached, isLatest: true), "a cached brief stays up offline")
  }

  func testLoadIfNeededFetchesOnce() async {
    let service = MarketBriefServiceStub()
    service.latestResult = .success(makeBrief(slot: .morning, date: "2026-10-15"))
    let viewModel = MarketBriefViewModel(language: "en", service: service, cache: MarketBriefCache(directory: nil))

    await viewModel.loadIfNeeded()
    await viewModel.loadIfNeeded()

    XCTAssertEqual(service.calls.count, 1)
  }

  // MARK: Latest | Previous

  func testShowPreviousRequestsThePreviousSlotAndDate() async {
    let latest = makeBrief(slot: .morning, date: "2026-10-15", previous: MarketBriefRef(slot: .evening, tradingDate: "2026-10-14"))
    let previous = makeBrief(slot: .evening, date: "2026-10-14")
    let service = MarketBriefServiceStub()
    service.latestResult = .success(latest)
    service.exactResults["evening|2026-10-14"] = .success(previous)
    let viewModel = MarketBriefViewModel(language: "pt-PT", service: service, cache: MarketBriefCache(directory: nil))
    await viewModel.loadIfNeeded()

    await viewModel.select(.previous)

    XCTAssertEqual(service.calls.last, .init(language: "pt-PT", slot: .evening, date: "2026-10-14"))
    XCTAssertEqual(viewModel.state, .loaded(previous, isLatest: false))
    XCTAssertEqual(viewModel.selection, .previous)
    XCTAssertTrue(viewModel.showsSelector, "the control stays so the reader can go back")

    await viewModel.select(.latest)

    XCTAssertEqual(viewModel.state, .loaded(latest, isLatest: true))
    XCTAssertEqual(viewModel.selection, .latest)
    XCTAssertEqual(service.calls.count, 2, "going back to the latest needs no request")
  }

  func testSelectingTheSideAlreadyShownDoesNotRefetch() async {
    let latest = makeBrief(slot: .morning, date: "2026-10-15", previous: MarketBriefRef(slot: .evening, tradingDate: "2026-10-14"))
    let service = MarketBriefServiceStub()
    service.latestResult = .success(latest)
    service.exactResults["evening|2026-10-14"] = .success(makeBrief(slot: .evening, date: "2026-10-14"))
    let viewModel = MarketBriefViewModel(language: "en", service: service, cache: MarketBriefCache(directory: nil))
    await viewModel.loadIfNeeded()
    await viewModel.select(.previous)

    await viewModel.select(.previous)

    XCTAssertEqual(service.calls.count, 2)
  }

  func testMissingPreviousFallsBackToLatest() async {
    let latest = makeBrief(slot: .morning, date: "2026-10-15", previous: MarketBriefRef(slot: .evening, tradingDate: "2026-10-14"))
    let service = MarketBriefServiceStub()
    service.latestResult = .success(latest)
    service.exactResults["evening|2026-10-14"] = .failure(MarketBriefHTTPClient.Error.invalidStatus(404))
    let viewModel = MarketBriefViewModel(language: "en", service: service, cache: MarketBriefCache(directory: nil))
    await viewModel.loadIfNeeded()

    viewModel.selection = .previous
    await viewModel.select(.previous)

    XCTAssertEqual(viewModel.state, .loaded(latest, isLatest: true))
    XCTAssertEqual(viewModel.selection, .latest)
  }

  func testNoPreviousHidesSelector() async {
    let service = MarketBriefServiceStub()
    service.latestResult = .success(makeBrief(slot: .morning, date: "2026-10-15"))
    let viewModel = MarketBriefViewModel(language: "en", service: service, cache: MarketBriefCache(directory: nil))

    await viewModel.loadIfNeeded()
    await viewModel.showPrevious()

    XCTAssertFalse(viewModel.showsSelector)
    XCTAssertEqual(service.calls.count, 1, "nothing to fetch without a previous brief")
  }

  // MARK: Push deep link

  func testShowSlotAndDateFetchesThatBrief() async {
    let latest = makeBrief(slot: .evening, date: "2026-10-15")
    let pushed = makeBrief(slot: .morning, date: "2026-10-15")
    let service = MarketBriefServiceStub()
    service.latestResult = .success(latest)
    service.exactResults["morning|2026-10-15"] = .success(pushed)
    let viewModel = MarketBriefViewModel(language: "en", service: service, cache: MarketBriefCache(directory: nil))
    await viewModel.loadIfNeeded()

    await viewModel.show(slot: .morning, date: "2026-10-15")

    XCTAssertEqual(service.calls.last, .init(language: "en", slot: .morning, date: "2026-10-15"))
    XCTAssertEqual(viewModel.state, .loaded(pushed, isLatest: false))
  }

  func testShowingTheLatestBriefNeedsNoRequest() async {
    let latest = makeBrief(slot: .morning, date: "2026-10-15")
    let service = MarketBriefServiceStub()
    service.latestResult = .success(latest)
    let viewModel = MarketBriefViewModel(language: "en", service: service, cache: MarketBriefCache(directory: nil))
    await viewModel.loadIfNeeded()

    await viewModel.handle(MarketBriefRouter.Request(id: UUID(), ref: MarketBriefRef(slot: .morning, tradingDate: "2026-10-15")))

    XCTAssertEqual(service.calls.count, 1)
    XCTAssertEqual(viewModel.state, .loaded(latest, isLatest: true))
  }

  func testPushedBriefBeforeFirstLoadIsMarkedLatestOnceLatestArrives() async {
    let brief = makeBrief(slot: .evening, date: "2026-10-15")
    let service = MarketBriefServiceStub()
    service.latestResult = .success(brief)
    service.exactResults["evening|2026-10-15"] = .success(brief)
    let viewModel = MarketBriefViewModel(language: "en", service: service, cache: MarketBriefCache(directory: nil))

    await viewModel.show(slot: .evening, date: "2026-10-15")
    XCTAssertEqual(viewModel.state, .loaded(brief, isLatest: false))

    await viewModel.loadIfNeeded()
    XCTAssertEqual(viewModel.state, .loaded(brief, isLatest: true))
  }

  // MARK: Language

  func testLanguageIsPassedAndChangeReloadsFromThatLanguage() async {
    let cache = MarketBriefCache(directory: nil)
    let english = makeBrief(slot: .morning, date: "2026-10-15", language: "en")
    let portuguese = makeBrief(slot: .morning, date: "2026-10-15", language: "pt-PT")
    let service = MarketBriefServiceStub()
    service.latestByLanguage = ["en": english, "pt-PT": portuguese]
    let viewModel = MarketBriefViewModel(language: "en", service: service, cache: cache)

    await viewModel.loadIfNeeded(language: "en")
    XCTAssertEqual(viewModel.state, .loaded(english, isLatest: true))

    await viewModel.loadIfNeeded(language: "pt-PT")

    XCTAssertEqual(service.calls.map(\.language), ["en", "pt-PT"])
    XCTAssertEqual(viewModel.language, "pt-PT")
    XCTAssertEqual(viewModel.state, .loaded(portuguese, isLatest: true))
    XCTAssertEqual(cache.latest(language: "en"), english, "each language keeps its own cached brief")
    XCTAssertEqual(cache.latest(language: "pt-PT"), portuguese)
  }

  // MARK: Refresh

  func testRefreshIfStaleSkipsRecentFetch() async {
    var now = Date(timeIntervalSince1970: 1_000_000)
    let service = MarketBriefServiceStub()
    service.latestResult = .success(makeBrief(slot: .morning, date: "2026-10-15"))
    let viewModel = MarketBriefViewModel(
      language: "en",
      service: service,
      cache: MarketBriefCache(directory: nil),
      now: { now }
    )
    await viewModel.loadIfNeeded()

    await viewModel.refreshIfStale(maxAge: 900)
    XCTAssertEqual(service.calls.count, 1)

    now = now.addingTimeInterval(901)
    await viewModel.refreshIfStale(maxAge: 900)
    XCTAssertEqual(service.calls.count, 2)
  }

  func testRefreshKeepsReaderOnOlderBrief() async {
    let latest = makeBrief(slot: .morning, date: "2026-10-15", previous: MarketBriefRef(slot: .evening, tradingDate: "2026-10-14"))
    let previous = makeBrief(slot: .evening, date: "2026-10-14")
    let service = MarketBriefServiceStub()
    service.latestResult = .success(latest)
    service.exactResults["evening|2026-10-14"] = .success(previous)
    let viewModel = MarketBriefViewModel(language: "en", service: service, cache: MarketBriefCache(directory: nil))
    await viewModel.loadIfNeeded()
    await viewModel.showPrevious()

    await viewModel.refresh()

    XCTAssertEqual(viewModel.state, .loaded(previous, isLatest: false))
    XCTAssertEqual(viewModel.latest, latest)
  }
}

// MARK: - Cache

@MainActor
final class MarketBriefCacheTests: XCTestCase {
  func testDiskCacheSurvivesANewInstance() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let brief = makeBrief(slot: .evening, date: "2026-10-14", previous: MarketBriefRef(slot: .morning, tradingDate: "2026-10-14"))

    MarketBriefCache(directory: directory).store(brief, language: "pt-PT")

    XCTAssertEqual(MarketBriefCache(directory: directory).latest(language: "pt-PT"), brief)
    XCTAssertNil(MarketBriefCache(directory: directory).latest(language: "en"))

    MarketBriefCache(directory: directory).remove(language: "pt-PT")
    XCTAssertNil(MarketBriefCache(directory: directory).latest(language: "pt-PT"))
  }
}

// MARK: - Helpers

func makeBrief(
  slot: MarketBriefSlot,
  date: String,
  language: String = "en",
  degraded: Bool = false,
  previous: MarketBriefRef? = nil
) -> MarketBriefResponse {
  MarketBriefResponse(
    enabled: true,
    tradingDate: date,
    slot: slot,
    language: language,
    greeting: "Good morning",
    groups: [
      MarketBriefQuoteGroup(
        id: "eu_open",
        title: "European markets lower",
        tone: .down,
        rows: [
          MarketBriefQuoteRow(symbol: "^GDAXI", flag: "🇩🇪", name: "DAX", level: "25,032", changePercent: "0.77%", direction: .down)
        ]
      )
    ],
    items: [
      MarketBriefItem(kind: .highlight, text: "Chip stocks lead futures.", tickers: ["NVDA"], sourceUrl: "https://www.reuters.com/markets/x")
    ],
    generatedAt: "2026-10-15T07:16:00Z",
    degraded: degraded,
    previous: previous
  )
}

final class MarketBriefServiceStub: MarketBriefServicing, @unchecked Sendable {
  struct Call: Equatable {
    let language: String
    let slot: MarketBriefSlot?
    let date: String?
  }

  var latestResult: Result<MarketBriefResponse, Error> = .success(.empty(language: "en", enabled: true))
  var latestByLanguage: [String: MarketBriefResponse] = [:]
  /// Keyed `slot|date`.
  var exactResults: [String: Result<MarketBriefResponse, Error>] = [:]
  var preferences = MarketBriefNotificationPreferences(enabled: false, language: "en")
  var updateError: Error?
  private(set) var calls: [Call] = []
  private(set) var updates: [MarketBriefNotificationPreferences] = []
  private(set) var preferenceReads = 0

  func brief(language: String, slot: MarketBriefSlot?, date: String?) async throws -> MarketBriefResponse {
    calls.append(Call(language: language, slot: slot, date: date))
    if let slot, let date {
      guard let result = exactResults["\(slot.rawValue)|\(date)"] else {
        throw MarketBriefHTTPClient.Error.invalidStatus(404)
      }
      return try result.get()
    }
    if let byLanguage = latestByLanguage[language] { return byLanguage }
    return try latestResult.get()
  }

  func notificationPreferences() async throws -> MarketBriefNotificationPreferences {
    preferenceReads += 1
    return preferences
  }

  func updateNotificationPreferences(enabled: Bool, language: String) async throws -> MarketBriefNotificationPreferences {
    if let updateError { throw updateError }
    let updated = MarketBriefNotificationPreferences(enabled: enabled, language: language)
    updates.append(updated)
    preferences = updated
    return updated
  }
}
