import Factory
import Foundation
import Observation

/// Backs the market-wide retail sentiment board.
///
/// Keeps the previous payload on failure rather than blanking the screen, the
/// same way `MarketsViewModel` does — a transient error should not throw away
/// data the reader was already looking at.
@MainActor
@Observable
final class MarketSentimentViewModel {
  var board: MarketTrendingResponse?
  var isLoading = false
  var errorMessage: String?
  private(set) var hasLoadedOnce = false

  private let client: InsightsHTTPClient

  init(client: InsightsHTTPClient = Container.shared.insightsHTTPClient()) {
    self.client = client
  }

  /// True when the pipeline is configured but has not produced a day yet —
  /// distinct from a request that failed, and worth saying differently.
  var isAwaitingFirstRun: Bool {
    guard let board else { return false }
    return board.asOfDate == nil
  }

  func load(force: Bool = false) async {
    guard force || !hasLoadedOnce else { return }
    isLoading = true
    errorMessage = nil
    defer {
      isLoading = false
      hasLoadedOnce = true
    }

    do {
      board = try await client.getMarketTrendingSentiment(limit: 10)
    } catch {
      if board == nil {
        errorMessage = error.localizedDescription
      }
    }
  }
}
