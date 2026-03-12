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

    init(service: StockServicing = Container.shared.stockService()) {
        self.service = service
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

    func saveValuation(_ request: StockValuationRequest) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if valuation != nil {
                valuation = try await service.updateValuation(symbol: request.symbol, request: request)
            } else {
                valuation = try await service.createValuation(request: request)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
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
