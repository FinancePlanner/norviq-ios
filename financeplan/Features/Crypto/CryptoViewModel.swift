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
    
    // New Overview Metrics
    @Published var sentimentValue: Int = 72 // 0-100
    @Published var sentimentLabel: String = "Greed"
    @Published var ethGasGwei: Int = 24
    @Published var dominance: [DominanceData] = [
        .init(symbol: "BTC", percentage: 52.4, color: .orange),
        .init(symbol: "ETH", percentage: 17.2, color: .blue),
        .init(symbol: "SOL", percentage: 4.8, color: .purple),
        .init(symbol: "Others", percentage: 25.6, color: .gray)
    ]
    @Published var topGainers: [CryptoQuoteResponse] = []
    @Published var topLosers: [CryptoQuoteResponse] = []
    
    struct DominanceData: Identifiable {
        let id = UUID()
        let symbol: String
        let percentage: Double
        let color: Color
    }
    
    private let cryptoService: any CryptoServicing = Container.shared.cryptoService()
    private let marketDataService: any MarketDataServicing = Container.shared.marketDataService()
    
    init() {
        // Initial load will be handled by .task or onAppear in view
    }
    
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
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
            
            // Hardcoded refinements for demonstration
            self.sentimentValue = 72
            self.sentimentLabel = "Greed"
            self.ethGasGwei = 24
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
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
            await load() // Refresh
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
            await load() // Refresh
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
            await load() // Refresh
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
