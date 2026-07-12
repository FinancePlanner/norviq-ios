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
    @Published var topGainers: [CryptoQuoteResponse] = []
    @Published var topLosers: [CryptoQuoteResponse] = []

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
            async let fetchWatchlist = cryptoService.fetchWatchlist()

            let (holdings, market, news, watchlist) = try await (fetchHoldings, fetchMarket, fetchNews, fetchWatchlist)

            self.userHoldings = holdings
            self.watchlist = watchlist
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

            if !symbolsToFetch.isEmpty {
                let commaSeparated = symbolsToFetch.joined(separator: ",")
                let quotes = try await cryptoService.fetchCryptoQuote(symbols: commaSeparated)
                self.topAssets = quotes

                // Sort for Gainers/Losers
                let sorted = quotes.sorted { $0.changePercentage > $1.changePercentage }
                self.topGainers = Array(sorted.prefix(5))
                self.topLosers = Array(sorted.reversed().prefix(5))

                // Derive market dominance + sentiment from real quote data.
                self.dominance = Self.makeDominance(from: quotes)
                let (sentiment, sentimentLabel) = Self.makeSentiment(from: quotes)
                self.sentimentValue = sentiment
                self.sentimentLabel = sentimentLabel
            } else {
                self.topAssets = []
            }

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

    /// Fear/greed-style sentiment (0–100) from the share of coins trading up.
    static func makeSentiment(from quotes: [CryptoQuoteResponse]) -> (value: Int, label: String) {
        guard !quotes.isEmpty else { return (50, "Neutral") }
        let positive = quotes.filter { $0.changePercentage >= 0 }.count
        let value = Int((Double(positive) / Double(quotes.count) * 100).rounded())
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
