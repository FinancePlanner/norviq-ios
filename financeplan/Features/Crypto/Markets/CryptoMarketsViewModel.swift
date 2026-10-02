import Combine
import Factory
import Foundation
import StockPlanShared
import SwiftUI

/// The one call the markets view needs; `CryptoServicing` inherits it.
@MainActor
protocol CryptoMarketsFetching: Sendable {
    func fetchCryptoMarkets(timeframe: CryptoMarketsTimeframe, limit: Int) async throws -> CryptoMarketsResponse
}

/// Shared by the Market segment and the bubbles screen so both show the same
/// timeframe. Responses are cached per timeframe for a minute, which makes
/// flicking between windows instant without hammering the backend (which
/// itself only refreshes every few minutes).
@MainActor
final class CryptoMarketsViewModel: ObservableObject {
    static let coinLimit = 100
    static let freshness: TimeInterval = 60
    private static let timeframeKey = "crypto.markets.timeframe"

    @Published private(set) var timeframe: CryptoMarketsTimeframe
    @Published private(set) var response: CryptoMarketsResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let fetcher: any CryptoMarketsFetching
    private let defaults: UserDefaults
    private let now: () -> Date
    private var cache: [CryptoMarketsTimeframe: (response: CryptoMarketsResponse, fetchedAt: Date)] = [:]

    init(
        fetcher: any CryptoMarketsFetching = Container.shared.cryptoService(),
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.fetcher = fetcher
        self.defaults = defaults
        self.now = now
        timeframe = defaults.string(forKey: Self.timeframeKey)
            .flatMap(CryptoMarketsTimeframe.init(rawValue:)) ?? .oneDay
    }

    /// Before the first response every window is offered; afterwards only the
    /// ones the backend's current source can answer.
    func isEnabled(_ candidate: CryptoMarketsTimeframe) -> Bool {
        guard let supported = response?.supportedTimeframes else { return true }
        return supported.contains(candidate) || candidate == timeframe
    }

    func select(_ newTimeframe: CryptoMarketsTimeframe) async {
        guard newTimeframe != timeframe || response == nil else { return }
        timeframe = newTimeframe
        defaults.set(newTimeframe.rawValue, forKey: Self.timeframeKey)
        await load()
    }

    func load(force: Bool = false) async {
        let requested = timeframe
        if !force, let cached = cache[requested], now().timeIntervalSince(cached.fetchedAt) < Self.freshness {
            response = cached.response
            errorMessage = nil
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await fetcher.fetchCryptoMarkets(timeframe: requested, limit: Self.coinLimit)
            cache[requested] = (fresh, now())
            // A slower request for a window the user already left must not
            // overwrite the one they are looking at.
            guard requested == timeframe else { return }
            response = fresh
            errorMessage = nil
        } catch {
            guard requested == timeframe else { return }
            // Keep showing the last good numbers; say why they did not change.
            errorMessage = error.localizedDescription
        }
    }
}

/// Server-driven colour ramp so iOS and web colour a given move the same way.
enum CryptoHeatColor {
    /// -1 (full red) … 0 (neutral) … 1 (full green).
    static func fraction(_ pct: Double, scaleMax: Double, mode: CryptoMarketsColorMode) -> Double {
        let scale = scaleMax > 0 ? scaleMax : 5
        switch mode {
        case .athDistance:
            // 0 = at the high (good), -scale = deep below it.
            return 1 + 2 * max(-scale, min(0, pct)) / scale
        case .change:
            return max(-scale, min(scale, pct)) / scale
        }
    }

    static func color(_ pct: Double, scaleMax: Double, mode: CryptoMarketsColorMode) -> Color {
        let t = fraction(pct, scaleMax: scaleMax, mode: mode)
        return MarketsPalette.neutral.blended(with: t >= 0 ? MarketsPalette.gain : MarketsPalette.loss, fraction: abs(t))
    }
}

extension CryptoMarketCoin {
    /// Detail screen route, or nil when FMP has no history for the coin.
    var detailRoute: CryptoDetailRoute? {
        fmpSymbol.map { CryptoDetailRoute(symbol: $0, name: name) }
    }
}

/// Signed percentage with explicit sign, e.g. "+4.20%". Inputs are percent
/// points, not fractions.
func formatCryptoPercent(_ pct: Double, digits: Int = 2) -> String {
    "\(pct >= 0 ? "+" : "")\(String(format: "%.\(digits)f", pct))%"
}
