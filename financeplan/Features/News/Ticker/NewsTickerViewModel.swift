import Factory
import Foundation
import Observation
import StockPlanShared

/// Drives the dashboard strip: cache first for an instant paint, then the
/// network, written through. A failed refresh keeps what is on screen and
/// marks it stale; a disabled response hides the strip and clears the cache.
@MainActor
@Observable
final class NewsTickerViewModel {
    private(set) var items: [NewsTickerItem] = []
    private(set) var isEnabled = true
    private(set) var isStale = false
    private(set) var isLoading = false
    private(set) var lastFetchedAt: Date?
    var errorMessage: String?

    private let service: any NewsTickerServicing
    private let localStore: NewsTickerLocalStore
    private let limit: Int
    private var hasLoadedCache = false

    init(
        service: any NewsTickerServicing = Container.shared.newsTickerService(),
        localStore: NewsTickerLocalStore = NewsTickerLocalStore(),
        limit: Int = 20
    ) {
        self.service = service
        self.localStore = localStore
        self.limit = limit
    }

    /// Paints whatever the device last saw. Safe to call more than once.
    func loadFromCache() async {
        guard !hasLoadedCache else { return }
        hasLoadedCache = true
        guard let cached = try? localStore.load(), !cached.items.isEmpty else { return }
        items = cached.items
        lastFetchedAt = cached.fetchedAt
    }

    /// Fetches from the backend, writing through to the cache.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await service.ticker(limit: limit)
            isEnabled = response.enabled
            isStale = response.stale
            items = response.enabled ? response.items : []
            lastFetchedAt = Date()
            errorMessage = nil
            try? localStore.replace(with: items, fetchedAt: lastFetchedAt ?? Date())
        } catch {
            // Keep the cached strip; say it is old rather than blank it.
            isStale = true
            errorMessage = error.localizedDescription
        }
    }

    /// Refreshes only when the last successful fetch is older than `maxAge`.
    func refreshIfStale(maxAge: TimeInterval) async {
        if let lastFetchedAt, Date().timeIntervalSince(lastFetchedAt) < maxAge {
            return
        }
        await refresh()
    }

    /// Optimistic switch. A failure rolls back and surfaces the error.
    func setEnabled(_ enabled: Bool) async {
        let previous = isEnabled
        isEnabled = enabled
        do {
            _ = try await service.updateSettings(enabled: enabled)
            if enabled {
                await refresh()
            } else {
                items = []
                try? localStore.replace(with: [], fetchedAt: Date())
            }
        } catch {
            isEnabled = previous
            errorMessage = error.localizedDescription
        }
    }

    /// Whether the dashboard should show the strip at all.
    var shouldShow: Bool {
        isEnabled && !items.isEmpty
    }
}
