import Factory
import Foundation
import Observation

/// Friends' recent unlocks, newest first, paged as the list scrolls, with an
/// optimistic 🎉 congrats.
@MainActor
@Observable
final class SocialFeedStore {
  static let pageSize = 20

  private(set) var items: [SocialFeedItem] = []
  private(set) var hasLoaded = false
  private(set) var isLoading = false
  private(set) var loadError: String?
  /// A congrats that failed or whose activity is gone; shown once.
  var actionMessage: String?

  private var nextCursor: String?
  private var isLoadingMore = false
  private var congratsInFlight: Set<String> = []
  private let service: any SocialServicing

  init(service: any SocialServicing) {
    self.service = service
  }

  convenience init() {
    self.init(service: Container.shared.socialService())
  }

  var hasMore: Bool { nextCursor != nil }

  func refresh() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let page = try await service.feed(cursor: nil, limit: Self.pageSize)
      items = page.items
      nextCursor = page.nextCursor
      loadError = nil
    } catch {
      loadError = error.localizedDescription
    }
    hasLoaded = true
  }

  /// Fetches the next page when `item` is the last row and there is one.
  func loadMoreIfNeeded(after item: SocialFeedItem) async {
    guard item.id == items.last?.id, let cursor = nextCursor, !isLoadingMore else { return }
    isLoadingMore = true
    defer { isLoadingMore = false }
    do {
      let page = try await service.feed(cursor: cursor, limit: Self.pageSize)
      let known = Set(items.map(\.id))
      items.append(contentsOf: page.items.filter { !known.contains($0.id) })
      nextCursor = page.nextCursor
    } catch {
      // Paging stays where it was; the next scroll to the end retries.
    }
  }

  func congratulate(_ item: SocialFeedItem) async {
    guard !item.viewerCongratulated, !congratsInFlight.contains(item.id),
          let index = items.firstIndex(where: { $0.id == item.id }) else { return }
    congratsInFlight.insert(item.id)
    defer { congratsInFlight.remove(item.id) }

    items[index].viewerCongratulated = true
    items[index].congratsCount += 1
    do {
      try await service.congratulate(activityId: item.id)
    } catch let error as SocialHTTPClient.Error where error.isNotFound {
      items.removeAll { $0.id == item.id }
      actionMessage = String(localized: "That achievement is no longer available.")
    } catch {
      if let current = items.firstIndex(where: { $0.id == item.id }) {
        items[current].viewerCongratulated = false
        items[current].congratsCount = max(0, items[current].congratsCount - 1)
      }
      actionMessage = String(localized: "Couldn't send your congrats. Try again.")
    }
  }
}
