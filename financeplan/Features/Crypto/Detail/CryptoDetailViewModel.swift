import Foundation
import StockPlanShared
import Combine
import Factory
import SwiftUI

@MainActor
final class CryptoDetailViewModel: ObservableObject {
    @Published var quote: CryptoQuoteResponse?
    @Published var points: [CryptoChartPoint] = []
    @Published var selectedRange: CryptoChartRange = .day
    @Published var isLoadingQuote = false
    @Published var isLoadingChart = false
    @Published var errorMessage: String?

    let symbol: String
    let name: String

    private let cryptoService: any CryptoServicing
    private var hasLoadedQuote = false

    init(
        symbol: String,
        name: String,
        cryptoService: any CryptoServicing = Container.shared.cryptoService()
    ) {
        self.symbol = symbol
        self.name = name
        self.cryptoService = cryptoService
    }

    func initialLoad() async {
        await loadQuote()
        await loadChart(range: selectedRange)
    }

    func selectRange(_ range: CryptoChartRange) async {
        guard range != selectedRange else { return }
        selectedRange = range
        await loadChart(range: range)
    }

    private func loadQuote() async {
        guard !hasLoadedQuote else { return }
        isLoadingQuote = true
        defer { isLoadingQuote = false }
        do {
            let quotes = try await cryptoService.fetchCryptoQuote(symbols: symbol)
            quote = quotes.first { $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame } ?? quotes.first
            hasLoadedQuote = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadChart(range: CryptoChartRange) async {
        isLoadingChart = true
        errorMessage = nil
        defer { isLoadingChart = false }
        do {
            let raw = try await cryptoService.fetchHistory(
                symbol: symbol,
                resolution: range.resolution,
                from: range.fromDateString(),
                to: range.toDateString()
            )
            // Backend/FMP returns newest-first; sort ascending for charting.
            points = raw
                .compactMap(CryptoChartPoint.init)
                .sorted { $0.date < $1.date }
        } catch {
            errorMessage = error.localizedDescription
            points = []
        }
    }
}
