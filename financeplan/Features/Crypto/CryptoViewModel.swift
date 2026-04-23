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

            let (holdings, market, news) = try await (fetchHoldings, fetchMarket, fetchNews)

            self.userHoldings = holdings
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
