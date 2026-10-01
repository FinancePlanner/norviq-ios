import Foundation
import StockPlanShared
import Combine
import Factory
import SwiftUI

@MainActor
final class CryptoViewModel: ObservableObject {
    @Published var topAssets: [CryptoQuoteResponse] = []
    @Published var marketNews: [StockNews] = []
    @Published var userHoldings: [CryptoPortfolioItemResponse] = []
    @Published var watchlist: [CryptoWatchlistItemResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedAsset: CryptoQuoteResponse?

    @Published var sentimentValue: Int = 0
    @Published var sentimentLabel: String = "Unavailable"
    @Published var ethGasGwei: Int = 0
    @Published var dominance: [DominanceData] = []
    @Published var topGainers: [CryptoMarketCoin] = []
    @Published var topLosers: [CryptoMarketCoin] = []
    @Published var btcSparkline: [Double] = []

    struct DominanceData: Identifiable {
        let id = UUID()
        let symbol: String
        let percentage: Double
        let color: Color
    }

    private let cryptoService: any CryptoServicing
    private let marketDataService: any MarketDataServicing
    private var hasLoadedOnce = false

    init(
        cryptoService: any CryptoServicing = Container.shared.cryptoService(),
        marketDataService: any MarketDataServicing = Container.shared.marketDataService()
    ) {
        self.cryptoService = cryptoService
        self.marketDataService = marketDataService
    }

    func load(force: Bool = false) async {
        if !force, hasLoadedOnce { return }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let fetchHoldings = cryptoService.fetchPortfolio()
            async let fetchMarket = cryptoService.fetchCryptoList()
            async let fetchNews = cryptoService.fetchGeneralCryptoNews()
            // Non-fatal: not every backend build serves /v1/crypto/watchlist,
            // and a 404 there must not blank the whole overview.
            async let fetchWatchlist = try? cryptoService.fetchWatchlist()
            // Ranked 24h movers across the whole market. Optional: an older
            // backend has no markets route, and then the quote sample below
            // still fills the cards.
            async let fetchMarkets = try? cryptoService.fetchCryptoMarkets(timeframe: .oneDay, limit: 20)

            let (holdings, market, news) = try await (fetchHoldings, fetchMarket, fetchNews)

            self.userHoldings = holdings
            self.watchlist = await fetchWatchlist ?? []
            self.marketNews = news.map { item in
                StockNews(
                    title: item.headline,
                    url: item.url ?? "",
                    date: item.publishedAt,
                    imageURL: item.imageUrl,
                    source: item.source,
                    summary: item.summary
                )
            }

            // Collect all symbols that need full quotes
            var symbolsToFetch = Set<String>()
            market.prefix(15).forEach { symbolsToFetch.insert($0.symbol) }
            holdings.forEach { symbolsToFetch.insert($0.symbol) }

            let markets = await fetchMarkets

            if !symbolsToFetch.isEmpty {
                let commaSeparated = symbolsToFetch.joined(separator: ",")
                do {
                    let quotes = try await cryptoService.fetchCryptoQuote(symbols: commaSeparated)
                    self.topAssets = quotes
                    self.dominance = Self.makeDominance(from: quotes)
                } catch {
                    // Multi-symbol quotes need a higher FMP plan. With the
                    // markets feed the overview still has movers and breadth.
                    guard markets != nil else { throw error }
                    self.topAssets = []
                }
            } else {
                self.topAssets = []
            }

            let (gainers, losers) = Self.makeMovers(markets: markets, quotes: topAssets)
            self.topGainers = gainers
            self.topLosers = losers
            self.btcSparkline = markets?.coins.first { $0.id == "bitcoin" }?.sparkline7d ?? []

            // Breadth: the whole market when available, else the quote sample.
            let (sentiment, sentimentLabel) = if let summary = markets?.summary, summary.advancers + summary.decliners > 0 {
                Self.makeSentiment(advancers: summary.advancers, total: summary.advancers + summary.decliners)
            } else {
                Self.makeSentiment(from: topAssets)
            }
            self.sentimentValue = sentiment
            self.sentimentLabel = sentimentLabel

            hasLoadedOnce = true

        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func addHolding(symbol: String, name: String, quantity: Double, price: Double) async -> Bool {
        errorMessage = nil
        do {
            let payload = CryptoPortfolioItemRequest(
                symbol: symbol,
                name: name,
                quantity: quantity,
                averageBuyPrice: price
            )
            _ = try await cryptoService.addToPortfolio(payload: payload)
            await load(force: true)
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    func removeHolding(itemId: String) async -> Bool {
        errorMessage = nil
        do {
            try await cryptoService.removeFromPortfolio(itemId: itemId)
            await load(force: true)
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Derived market summary

    private static let dominancePalette: [Color] = [.orange, .blue, .purple, .green, .pink]

    /// Relative market-cap dominance among the fetched major coins (top 5 + "Others").
    static func makeDominance(from quotes: [CryptoQuoteResponse]) -> [DominanceData] {
        let capped = quotes.compactMap { quote -> (String, Double)? in
            guard let cap = quote.marketCap, cap > 0 else { return nil }
            return (quote.symbol, cap)
        }
        let total = capped.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return [] }

        let sorted = capped.sorted { $0.1 > $1.1 }
        let top = sorted.prefix(5)
        var result = top.enumerated().map { index, item in
            DominanceData(
                symbol: item.0.replacingOccurrences(of: "USD", with: ""),
                percentage: item.1 / total * 100,
                color: dominancePalette[index % dominancePalette.count]
            )
        }

        let othersTotal = sorted.dropFirst(5).reduce(0) { $0 + $1.1 }
        if othersTotal > 0 {
            result.append(
                DominanceData(symbol: "Other", percentage: othersTotal / total * 100, color: .gray)
            )
        }
        return result
    }

    /// Top/bottom five 24h movers: the market-wide ranking when the markets
    /// feed answered, else the fetched quote sample.
    static func makeMovers(
        markets: CryptoMarketsResponse?,
        quotes: [CryptoQuoteResponse]
    ) -> (gainers: [CryptoMarketCoin], losers: [CryptoMarketCoin]) {
        if let markets, !markets.gainers.isEmpty || !markets.losers.isEmpty {
            return (Array(markets.gainers.prefix(5)), Array(markets.losers.prefix(5)))
        }
        let coins = quotes.map { quote in
            CryptoMarketCoin(
                id: quote.symbol,
                symbol: quote.symbol.replacingOccurrences(of: "USD", with: ""),
                fmpSymbol: quote.symbol,
                name: quote.name,
                sector: "Other",
                price: quote.price,
                marketCap: quote.marketCap,
                volume24h: quote.volume,
                changePct: quote.changePercentage
            )
        }
        let sorted = coins.sorted { ($0.changePct ?? 0) > ($1.changePct ?? 0) }
        return (
            Array(sorted.filter { ($0.changePct ?? 0) > 0 }.prefix(5)),
            Array(sorted.reversed().filter { ($0.changePct ?? 0) < 0 }.prefix(5))
        )
    }

    /// Fear/greed-style sentiment (0–100) from the share of coins trading up.
    static func makeSentiment(from quotes: [CryptoQuoteResponse]) -> (value: Int, label: String) {
        guard !quotes.isEmpty else { return (50, "Neutral") }
        let positive = quotes.filter { $0.changePercentage >= 0 }.count
        return makeSentiment(advancers: positive, total: quotes.count)
    }

    static func makeSentiment(advancers: Int, total: Int) -> (value: Int, label: String) {
        guard total > 0 else { return (50, "Neutral") }
        let value = Int((Double(advancers) / Double(total) * 100).rounded())
        let label: String
        switch value {
        case ..<25: label = "Extreme Fear"
        case ..<45: label = "Fear"
        case ..<55: label = "Neutral"
        case ..<75: label = "Greed"
        default: label = "Extreme Greed"
        }
        return (value, label)
    }

    func addToWatchlist(symbol: String, name: String, note: String? = nil) async -> Bool {
        errorMessage = nil
        do {
            let payload = CryptoWatchlistItemRequest(symbol: symbol, name: name, note: note, status: nil)
            _ = try await cryptoService.addToWatchlist(payload: payload)
            await load(force: true)
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    func removeFromWatchlist(itemId: String) async -> Bool {
        errorMessage = nil
        do {
            try await cryptoService.removeFromWatchlist(itemId: itemId)
            await load(force: true)
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    func updateHolding(itemId: String, symbol: String, name: String, quantity: Double, price: Double) async -> Bool {
        errorMessage = nil
        do {
            let payload = CryptoPortfolioItemRequest(
                symbol: symbol,
                name: name,
                quantity: quantity,
                averageBuyPrice: price
            )
            _ = try await cryptoService.updatePortfolioItem(itemId: itemId, payload: payload)
            await load(force: true)
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
