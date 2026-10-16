import Foundation
import Observation
import StockPlanShared

/// Hands a push or link to the dashboard's market brief card, which owns its
/// own view model. The card may not exist yet (cold start, another tab), so
/// the request waits here until the card consumes it.
@MainActor
@Observable
final class MarketBriefRouter {
  struct Request: Equatable, Identifiable {
    let id: UUID
    /// Nil shows the latest brief.
    let ref: MarketBriefRef?
  }

  private(set) var pendingRequest: Request?
  /// Bumped on every open, never cleared: the dashboard scrolls to the card on it.
  private(set) var openCount = 0
  /// Bumped when a brief push arrives in the foreground, so a card on screen
  /// can pick up the new brief without a tap.
  private(set) var publishedCount = 0

  func open(_ ref: MarketBriefRef?) {
    pendingRequest = Request(id: UUID(), ref: ref)
    openCount += 1
  }

  func consume() -> Request? {
    defer { pendingRequest = nil }
    return pendingRequest
  }

  func notePublished() {
    publishedCount += 1
  }
}
