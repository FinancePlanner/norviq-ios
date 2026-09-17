import Foundation
import StockPlanShared
import SwiftData
import XCTest
@testable import financeplan

@MainActor
final class NewsTickerViewModelTests: XCTestCase {
  func testLoadPaintsCacheFirstThenNetworkAndWritesThrough() async throws {
    let container = try makeInMemoryContainer()
    let store = NewsTickerLocalStore(container: container)
    try store.replace(with: [makeItem(id: "old", title: "Cached headline")], fetchedAt: Date())

    let service = NewsTickerServiceStub()
    service.tickerResult = .success(makeResponse(items: [makeItem(id: "new", title: "Fresh headline")]))
    let viewModel = NewsTickerViewModel(service: service, localStore: store)

    await viewModel.loadFromCache()
    XCTAssertEqual(viewModel.items.map(\.id), ["old"])

    await viewModel.refresh()
    XCTAssertEqual(viewModel.items.map(\.id), ["new"])
    XCTAssertTrue(viewModel.isEnabled)
    XCTAssertFalse(viewModel.isStale)
    XCTAssertEqual(try store.load().items.map(\.id), ["new"], "network result is written through to the cache")
  }

  func testNetworkFailureKeepsCacheAndMarksStale() async throws {
    let container = try makeInMemoryContainer()
    let store = NewsTickerLocalStore(container: container)
    try store.replace(with: [makeItem(id: "old", title: "Cached headline")], fetchedAt: Date())

    let service = NewsTickerServiceStub()
    service.tickerResult = .failure(URLError(.notConnectedToInternet))
    let viewModel = NewsTickerViewModel(service: service, localStore: store)

    await viewModel.loadFromCache()
    await viewModel.refresh()

    XCTAssertEqual(viewModel.items.map(\.id), ["old"])
    XCTAssertTrue(viewModel.isStale)
    XCTAssertTrue(viewModel.isEnabled, "a cached strip stays visible offline")
  }

  func testDisabledResponseHidesStripAndClearsCache() async throws {
    let container = try makeInMemoryContainer()
    let store = NewsTickerLocalStore(container: container)
    try store.replace(with: [makeItem(id: "old", title: "Cached headline")], fetchedAt: Date())

    let service = NewsTickerServiceStub()
    service.tickerResult = .success(NewsTickerResponse(enabled: false, items: [], generatedAt: "2026-09-17T12:00:00Z", stale: false))
    let viewModel = NewsTickerViewModel(service: service, localStore: store)

    await viewModel.loadFromCache()
    await viewModel.refresh()

    XCTAssertFalse(viewModel.isEnabled)
    XCTAssertTrue(viewModel.items.isEmpty)
    XCTAssertTrue(try store.load().items.isEmpty)
  }

  func testRefreshIfStaleSkipsRecentFetch() async throws {
    let container = try makeInMemoryContainer()
    let service = NewsTickerServiceStub()
    service.tickerResult = .success(makeResponse(items: [makeItem(id: "a", title: "A")]))
    let viewModel = NewsTickerViewModel(service: service, localStore: NewsTickerLocalStore(container: container))

    await viewModel.refresh()
    await viewModel.refreshIfStale(maxAge: 300)
    XCTAssertEqual(service.tickerCalls, 1)

    await viewModel.refreshIfStale(maxAge: 0)
    XCTAssertEqual(service.tickerCalls, 2)
  }

  func testSetEnabledIsOptimisticAndRollsBackOnFailure() async throws {
    let container = try makeInMemoryContainer()
    let service = NewsTickerServiceStub()
    service.tickerResult = .success(makeResponse(items: [makeItem(id: "a", title: "A")]))
    service.updateSettingsResult = .failure(URLError(.badServerResponse))
    let viewModel = NewsTickerViewModel(service: service, localStore: NewsTickerLocalStore(container: container))
    await viewModel.refresh()

    await viewModel.setEnabled(false)

    XCTAssertTrue(viewModel.isEnabled, "rolled back")
    XCTAssertNotNil(viewModel.errorMessage)
  }

  // MARK: - Helpers

  private func makeInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: LocalNewsTickerItem.self, configurations: configuration)
  }

  private func makeItem(id: String, title: String) -> NewsTickerItem {
    NewsTickerItem(id: id, title: title, url: "https://pub.example/\(id)", source: "CNBC", sourceUrl: nil, publishedAt: "2026-09-17T11:00:00Z")
  }

  private func makeResponse(items: [NewsTickerItem]) -> NewsTickerResponse {
    NewsTickerResponse(enabled: true, items: items, generatedAt: "2026-09-17T12:00:00Z", stale: false)
  }
}

final class NewsTickerServiceStub: NewsTickerServicing, @unchecked Sendable {
  var tickerResult: Result<NewsTickerResponse, Error> = .success(NewsTickerResponse(enabled: true, items: [], generatedAt: "", stale: false))
  var updateSettingsResult: Result<NewsTickerSettings, Error> = .success(NewsTickerSettings(enabled: true))
  private(set) var tickerCalls = 0

  func ticker(limit: Int) async throws -> NewsTickerResponse {
    tickerCalls += 1
    return try tickerResult.get()
  }

  func settings() async throws -> NewsTickerSettings { NewsTickerSettings(enabled: true) }
  func updateSettings(enabled: Bool) async throws -> NewsTickerSettings { try updateSettingsResult.get() }
  func listFeeds() async throws -> NewsTickerFeedsResponse { NewsTickerFeedsResponse(feeds: [], maxFeeds: 10) }
  func addFeed(url: String) async throws -> NewsTickerFeed { NewsTickerFeed(id: UUID().uuidString, url: url, title: nil) }
  func removeFeed(id: String) async throws {}
}
