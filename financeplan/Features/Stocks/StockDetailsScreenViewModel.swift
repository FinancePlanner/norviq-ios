//
//  StockDetailsScreenViewModel.swift
//  financeplan
//
//  Created by Fernando Correia on 11.03.26.
//

import Combine
import Factory
import Foundation
import StockPlanShared

@MainActor
final class StockDetailsViewModel: ObservableObject {
    @Published var details: StockDetails?
    @Published var history: [StockHistory] = []
    @Published var news: [StockNews] = []
    @Published var valuation: StockValuationRequest?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: StockServicing

    init() {
        self.service = Container.shared.stockService()
    }

    init(service: StockServicing) {
        self.service = service
    }

    func saveValuation(_ draft: StockValuationDraft) async -> String? {
        guard !isLoading else { return "A save is already in progress." }
        guard let symbol = details?.symbol ?? valuation?.symbol else {
            return "Unable to resolve the stock symbol for this valuation."
        }

        print(
            """
            StockDetailsViewModel.saveValuation \
            symbol=\(symbol) \
            bearLow=\(draft.bearLow) bearHigh=\(draft.bearHigh) \
            baseLow=\(draft.baseLow) baseHigh=\(draft.baseHigh) \
            bullLow=\(draft.bullLow) bullHigh=\(draft.bullHigh) \
            rationale=\(draft.rationale ?? "<nil>") \
            targetDate=\(draft.targetDate ?? "<nil>")
            """
        )

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if valuation != nil {
                valuation = try await service.updateValuation(symbol: symbol, draft: draft)
            } else {
                valuation = try await service.createValuation(symbol: symbol, draft: draft)
            }
            return nil
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
            return message
        }
    }

    func load(stockId: String) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let details = try await service.fetchStockDetails(stockId: stockId)
            let symbol = details.symbol

            async let historyTask = loadHistory(symbol: symbol)
            async let newsTask = loadNews(symbol: symbol)
            async let valuationTask = loadValuation(symbol: symbol)

            self.details = details
            self.history = await historyTask
            self.news = await newsTask
            self.valuation = await valuationTask
        } catch {
            details = nil
            history = []
            news = []
            valuation = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func saveValuation(
        bearLow: Double,
        bearHigh: Double,
        baseLow: Double,
        baseHigh: Double,
        bullLow: Double,
        bullHigh: Double,
        rationale: String?,
        targetDate: String?
    ) async -> String? {
        await saveValuation(
            StockValuationDraft(
                bearLow: bearLow,
                bearHigh: bearHigh,
                baseLow: baseLow,
                baseHigh: baseHigh,
                bullLow: bullLow,
                bullHigh: bullHigh,
                rationale: rationale,
                targetDate: targetDate
            )
        )
    }

    private func loadHistory(symbol: String) async -> [StockHistory] {
        do {
            return try await service.fetchStockHistory(symbol: symbol)
        } catch {
            return []
        }
    }

    private func loadNews(symbol: String) async -> [StockNews] {
        do {
            return try await service.fetchStockNews(symbol: symbol)
        } catch {
            return []
        }
    }

    private func loadValuation(symbol: String) async -> StockValuationRequest? {
        do {
            return try await service.getValuation(symbol: symbol)
        } catch let error as StockHTTPClient.Error {
            switch error {
            case .invalidStatus(404):
                return nil
            case let .api(message) where message.localizedCaseInsensitiveContains("valuation not found"):
                return nil
            default:
                errorMessage = error.errorDescription ?? error.localizedDescription
                return nil
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }
}
