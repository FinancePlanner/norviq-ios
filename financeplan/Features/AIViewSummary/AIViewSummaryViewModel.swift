import Factory
import Foundation

/// Drives one summary sheet.
///
/// One instance per screen that adopts the modifier, created lazily with the
/// sheet. Nothing is fetched until the sheet appears, so a screen that is never
/// asked about costs nothing.
@Observable
@MainActor
final class AIViewSummaryViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(AIViewSummaryResponse)
        case failed(String)
    }

    private(set) var state: State = .idle

    @ObservationIgnored
    @Injected(\.aiInsightsService) private var service: any AIInsightsServicing

    /// Fetches once per sheet presentation.
    ///
    /// This departs from `InsightsViewModel`, which deliberately never
    /// auto-loads so that every LLM call is an explicit tap. The reasoning does
    /// not carry over: opening this sheet *is* the explicit tap, and the server
    /// caches for an hour, so only the first open of the hour costs anything.
    /// Making the reader tap twice would buy nothing.
    func loadIfNeeded(scope: AIViewScope) async {
        guard case .idle = state else { return }
        await load(scope: scope, refresh: false)
    }

    func refresh(scope: AIViewScope) async {
        await load(scope: scope, refresh: true)
    }

    private func load(scope: AIViewScope, refresh: Bool) async {
        state = .loading
        do {
            state = .loaded(try await service.viewSummary(scope: scope, refresh: refresh))
        } catch is CancellationError {
            // Dismissing the sheet cancels the task. Returning to idle lets a
            // reopen try again instead of showing a stale error.
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
