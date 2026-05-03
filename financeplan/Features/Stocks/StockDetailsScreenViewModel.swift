//
//  StockDetailsScreenViewModel.swift
//  financeplan
//
//  Created by Fernando Correia on 11.03.26.
//

import Combine
import Factory
import Foundation
import OSLog
import StockPlanShared

@MainActor
final class StockDetailsViewModel: ObservableObject {
    struct SellPositionOutcome {
        let shouldDismiss: Bool
        let errorMessage: String?
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
        category: "StockDetailsPerformance"
    )

    private struct AnalystConsensusLoadResult {
        let consensus: StockAnalystConsensus?
        let message: String?
    }

    private struct AnalysisMetricsLoadResult {
        let metrics: StockAnalysisMetrics?
        let message: String?
    }

    private struct FinancialStatementsLoadResult {
        let statements: StockFinancialStatements?
        let message: String?
    }

    private struct FinancialStatementsSectionLoadResult<Value: Sendable>: Sendable {
        let value: Value
        let message: String?
        let isUnsupportedPlan: Bool
    }

    @Published var details: StockDetails?
    @Published var history: [StockHistory] = []
    @Published var news: [StockNews] = []
    @Published var valuation: StockValuationRequest?
    @Published private(set) var portfolioSummary: PortfolioSummaryResponse?
    @Published private(set) var companyProfile: CompanyProfileResponse?
    @Published private(set) var marketSnapshot: StockMarketSnapshot?
    @Published private(set) var analystConsensus: StockAnalystConsensus?
    @Published private(set) var analystConsensusMessage: String?
    @Published private(set) var basicFinancials: StockBasicFinancials?
    @Published private(set) var stockEarnings: [EarningsEvent] = []
    @Published private(set) var stockEarningsMessage: String?
    @Published private(set) var isEarningsLoading = false
    @Published private(set) var analysisMetrics: StockAnalysisMetrics?
    @Published private(set) var analysisMetricsMessage: String?
    @Published private(set) var financialStatements: StockFinancialStatements?
    @Published private(set) var financialStatementsMessage: String?
    @Published private(set) var primaryComparisonProfile: StockComparisonProfile?
    @Published private(set) var comparisonUniverse: [StockComparisonProfile] = []
    @Published private(set) var selectedPeerSymbols: [String] = []
    @Published var isLoading = false
    @Published var isSavingPosition = false
    @Published var isDeletingPosition = false
    @Published var isSellingPosition = false
    @Published var errorMessage: String?

    // Price chart state
    @Published private(set) var chartSeries: PriceChartSeries?
    @Published private(set) var isChartLoading = false
    @Published private(set) var chartErrorMessage: String?
    @Published var selectedChartRange: PriceChartRange = .oneDay

    // Comparison Chart State
    @Published private(set) var comparisonChartResponse: PriceChartComparisonResponse?
    @Published private(set) var isComparisonChartLoading = false
    @Published private(set) var comparisonChartErrorMessage: String?
    @Published var selectedComparisonChartRange: PriceChartRange = .oneYear

    private let service: StockServicing
    private let marketDataService: MarketDataServicing
    private var loadedTabs: Set<StockDetailTab> = []
    private var loadingTabs: Set<StockDetailTab> = []
    private var comparisonRefreshTask: Task<Void, Never>?
    private var loadedStockID: String?

    var shareSnapshot: StockShareSnapshot? {
        guard let details else { return nil }
        return StockShareFormatter.makeSnapshot(
            details: details,
            valuation: valuation,
            history: history,
            news: news
        )
    }

    var selectedPeerProfiles: [StockComparisonProfile] {
        selectedPeerSymbols.compactMap(comparisonProfile(for:))
    }

    var comparisonProfiles: [StockComparisonProfile] {
        guard let primaryComparisonProfile else { return [] }
        return [primaryComparisonProfile] + selectedPeerProfiles
    }

    var availablePeerProfiles: [StockComparisonProfile] {
        guard let primaryComparisonProfile else { return comparisonUniverse }
        return comparisonUniverse.filter { $0.symbol != primaryComparisonProfile.symbol }
    }

    func allocationImpact(for request: SellStockRequest) -> PortfolioAllocationImpact? {
        guard let details, let portfolioSummary else { return nil }
        let symbol = details.symbol.uppercased()

        return PortfolioAllocationImpactCalculator.preview(
            holdings: allocationHoldings(details: details, summary: portfolioSummary),
            cashBalance: portfolioSummary.cashBalance,
            change: .sellPosition(
                id: details.id,
                symbol: symbol,
                remainingShares: max(0, details.shares - request.sharesToSell),
                buyPrice: details.buyPrice,
                cashProceeds: request.sharesToSell * request.sellPrice
            )
        )
    }

    func allocationImpact(for stock: StockResponse) -> PortfolioAllocationImpact? {
        guard let details, let portfolioSummary else { return nil }
        return PortfolioAllocationImpactCalculator.preview(
            holdings: allocationHoldings(details: details, summary: portfolioSummary),
            cashBalance: portfolioSummary.cashBalance,
            change: .replacePosition(
                id: stock.id,
                symbol: stock.symbol,
                shares: stock.shares,
                buyPrice: stock.buyPrice
            )
        )
    }

    init() {
        self.service = Container.shared.stockService()
        self.marketDataService = Container.shared.marketDataService()
    }

    init(service: StockServicing, marketDataService: MarketDataServicing) {
        self.service = service
        self.marketDataService = marketDataService
    }

    init(service: StockServicing) {
        self.service = service
        self.marketDataService = MarketDataServiceStub()
    }

    func savePosition(_ updated: StockResponse) async -> Bool {
        guard !isSavingPosition else { return false }
        isSavingPosition = true
        errorMessage = nil
        defer { isSavingPosition = false }

        do {
            let saved = try await service.updateStock(updated)
            details = saved
            NotificationCenter.default.post(name: .portfolioDataDidChange, object: nil)
            return true
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
            return false
        }
    }

    func deletePosition() async -> Bool {
        guard let current = details else { return false }
        guard !isDeletingPosition else { return false }
        isDeletingPosition = true
        errorMessage = nil
        defer { isDeletingPosition = false }

        do {
            try await service.delete(id: current.id)
            resetLoadedState()
            NotificationCenter.default.post(name: .portfolioDataDidChange, object: nil)
            return true
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
            return false
        }
    }

    func sellPosition(_ request: SellStockRequest) async -> SellPositionOutcome {
        guard let current = details else {
            return SellPositionOutcome(shouldDismiss: false, errorMessage: "Unable to load the stock details for this sale.")
        }
        guard !isSellingPosition else {
            return SellPositionOutcome(shouldDismiss: false, errorMessage: "A sell request is already in progress.")
        }

        isSellingPosition = true
        errorMessage = nil
        defer { isSellingPosition = false }

        let isFullSale = request.sharesToSell >= current.shares
        do {
            let updated = try await service.sellStock(id: current.id, request: request)
            if isFullSale {
                resetLoadedState()
            } else {
                details = updated
            }
            NotificationCenter.default.post(name: .portfolioDataDidChange, object: nil)
            return SellPositionOutcome(shouldDismiss: isFullSale, errorMessage: nil)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
            return SellPositionOutcome(shouldDismiss: false, errorMessage: message)
        }
    }

    func saveValuation(_ draft: StockValuationDraft) async -> String? {
        guard !isLoading else { return "A save is already in progress." }
        guard let symbol = details?.symbol ?? valuation?.symbol else {
            return "Unable to resolve the stock symbol for this valuation."
        }

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

    func applyDCFToValuation(
        bearPrice: Double,
        basePrice: Double,
        bullPrice: Double
    ) async -> String? {
        guard bearPrice.isFinite, basePrice.isFinite, bullPrice.isFinite else {
            return "DCF valuation values are unavailable."
        }

        let draft = StockValuationDraft(
            bearLow: bearPrice,
            bearHigh: bearPrice,
            baseLow: basePrice,
            baseHigh: basePrice,
            bullLow: bullPrice,
            bullHigh: bullPrice,
            rationale: valuation?.rationale,
            targetDate: valuation?.targetDate
        )

        return await saveValuation(draft)
    }

    func load(stockId: String, force: Bool = false) async {
        if !force, loadedStockID == stockId, details != nil { return }
        guard !isLoading else { return }

        let start = ContinuousClock.now
        isLoading = true
        errorMessage = nil
        comparisonRefreshTask?.cancel()
        comparisonRefreshTask = nil
        defer {
            isLoading = false
            Self.logger.info(
                "Stock details load stock_id=\(stockId, privacy: .public) duration_ms=\(Self.durationInMilliseconds(from: start.duration(to: .now)), privacy: .public)"
            )
        }

        do {
            let details = try await service.fetchStockDetails(stockId: stockId)
            let symbol = details.symbol

            async let historyTask = loadHistory(symbol: symbol)
            async let newsTask = loadNews(symbol: symbol)
            async let valuationTask = loadValuation(symbol: symbol)
            async let insightsTask = loadInsights(symbol: symbol)
            async let companyProfileTask = loadCompanyProfile(symbol: symbol)
            async let quoteTask = loadQuote(symbol: symbol)
            async let analystConsensusTask = loadAnalystConsensus(symbol: symbol)
            async let basicFinancialsTask = loadBasicFinancials(symbol: symbol)
            async let portfolioSummaryTask = loadPortfolioSummary()

            self.details = details
            self.history = await historyTask
            self.news = await newsTask
            self.valuation = await valuationTask
            if let insights = await insightsTask {
                applyInsights(insights)
            } else {
                self.primaryComparisonProfile = nil
                self.comparisonUniverse = []
                self.selectedPeerSymbols = []
            }
            self.companyProfile = await companyProfileTask
            self.marketSnapshot = await quoteTask
            let analystConsensusResult = await analystConsensusTask
            self.analystConsensus = analystConsensusResult.consensus
            self.analystConsensusMessage = analystConsensusResult.message
            self.basicFinancials = await basicFinancialsTask
            self.portfolioSummary = await portfolioSummaryTask
            self.stockEarnings = []
            self.stockEarningsMessage = nil
            self.isEarningsLoading = false

            // Heavy sections are loaded lazily when their tabs are selected.
            self.analysisMetrics = nil
            self.analysisMetricsMessage = nil
            self.financialStatements = nil
            self.financialStatementsMessage = nil
            loadedTabs = [.overview, .news]
            loadingTabs = []
            loadedStockID = stockId
        } catch {
            details = nil
            history = []
            news = []
            valuation = nil
            portfolioSummary = nil
            companyProfile = nil
            marketSnapshot = nil
            analystConsensus = nil
            analystConsensusMessage = nil
            basicFinancials = nil
            stockEarnings = []
            stockEarningsMessage = nil
            isEarningsLoading = false
            analysisMetrics = nil
            analysisMetricsMessage = nil
            financialStatements = nil
            financialStatementsMessage = nil
            primaryComparisonProfile = nil
            comparisonUniverse = []
            selectedPeerSymbols = []
            comparisonRefreshTask?.cancel()
            comparisonRefreshTask = nil
            loadedTabs = []
            loadingTabs = []
            loadedStockID = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            Self.logger.error(
                "Stock details load failed stock_id=\(stockId, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func loadSupplementaryDataIfNeeded(for tab: StockDetailTab) async {
        guard let symbol = details?.symbol else { return }

        switch tab {
        case .analysis, .forecast, .compare:
            guard !loadedTabs.contains(.analysis), !loadingTabs.contains(.analysis) else { return }
            loadingTabs.insert(.analysis)
            let result = await loadAnalysisMetrics(symbol: symbol)
            analysisMetrics = result.metrics
            analysisMetricsMessage = result.message
            applyAnalysisMetrics(result.metrics, to: symbol)
            loadedTabs.insert(.analysis)
            loadingTabs.remove(.analysis)
        case .statements:
            guard !loadedTabs.contains(.statements), !loadingTabs.contains(.statements) else { return }
            loadingTabs.insert(.statements)
            let result = await loadFinancialStatements(symbol: symbol)
            financialStatements = result.statements
            financialStatementsMessage = result.message
            loadedTabs.insert(.statements)
            loadingTabs.remove(.statements)
        case .earnings:
            guard !loadedTabs.contains(.earnings), !loadingTabs.contains(.earnings) else { return }
            loadingTabs.insert(.earnings)
            isEarningsLoading = true
            let result = await loadStockEarnings(symbol: symbol)
            stockEarnings = result.events
            stockEarningsMessage = result.message
            isEarningsLoading = false
            loadedTabs.insert(.earnings)
            loadingTabs.remove(.earnings)
        case .chart:
            guard !loadedTabs.contains(.chart), !loadingTabs.contains(.chart) else { return }
            loadingTabs.insert(.chart)
            isChartLoading = true
            await loadPriceChart(symbol: symbol, range: selectedChartRange)
            isChartLoading = false
            loadedTabs.insert(.chart)
            loadingTabs.remove(.chart)
        case .overview, .news:
            return
        }
    }

    func projectionScenario(_ kind: StockProjectionScenarioKind) -> StockProjectionScenario? {
        primaryComparisonProfile?.projectionScenarios[kind]
    }

    func comparisonProfile(for symbol: String) -> StockComparisonProfile? {
        comparisonUniverse.first { $0.symbol == symbol.uppercased() }
    }

    func selectedPeerSymbol(at slot: Int) -> String {
        guard selectedPeerSymbols.indices.contains(slot) else { return "" }
        return selectedPeerSymbols[slot]
    }

    func updatePeerSymbol(_ symbol: String, slot: Int) {
        guard slot >= 0 else { return }

        let normalized = symbol.uppercased()
        guard
            !normalized.isEmpty,
            let primaryComparisonProfile,
            normalized != primaryComparisonProfile.symbol
        else { return }

        var peers = selectedPeerSymbols
        if peers.count <= slot {
            peers.append(contentsOf: Array(repeating: "", count: slot - peers.count + 1))
        }

        if let existingIndex = peers.firstIndex(of: normalized), existingIndex != slot {
            peers.swapAt(existingIndex, slot)
        } else {
            peers[slot] = normalized
        }

        var seen = Set<String>()
        selectedPeerSymbols = peers.filter { symbol in
            !symbol.isEmpty && seen.insert(symbol).inserted
        }

        fillMissingPeers()
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

    func saveAnalysis(_ analysis: String?) async -> String? {
        guard let details else {
            return "Unable to load the stock details for this analysis."
        }

        errorMessage = nil

        do {
            let saved = try await service.updateStock(
                StockResponse(
                    id: details.id,
                    symbol: details.symbol,
                    shares: details.shares,
                    buyPrice: details.buyPrice,
                    buyDate: details.buyDate,
                    notes: analysis
                )
            )
            self.details = saved
            return nil
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
            return message
        }
    }

    func reloadAnalysisMetrics() {
        guard let symbol = details?.symbol else { return }
        Task {
            loadingTabs.insert(.analysis)
            let result = await loadAnalysisMetrics(symbol: symbol)
            
            await MainActor.run {
                self.analysisMetrics = result.metrics
                self.analysisMetricsMessage = result.message
                self.applyAnalysisMetrics(result.metrics, to: symbol)
                self.loadingTabs.remove(.analysis)
            }
        }
    }

    private func loadHistory(symbol: String) async -> [StockHistory] {
        do {
            return try await service.fetchStockHistory(symbol: symbol)
        } catch {
            return []
        }
    }

    private func resetLoadedState() {
        details = nil
        history = []
        news = []
        valuation = nil
        portfolioSummary = nil
        companyProfile = nil
        marketSnapshot = nil
        analystConsensus = nil
        analystConsensusMessage = nil
        basicFinancials = nil
        stockEarnings = []
        stockEarningsMessage = nil
        isEarningsLoading = false
        analysisMetrics = nil
        analysisMetricsMessage = nil
        financialStatements = nil
        financialStatementsMessage = nil
        primaryComparisonProfile = nil
        comparisonUniverse = []
        selectedPeerSymbols = []
        comparisonRefreshTask?.cancel()
        comparisonRefreshTask = nil
        loadedTabs = []
        loadingTabs = []
        loadedStockID = nil
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

    private func loadPortfolioSummary() async -> PortfolioSummaryResponse? {
        do {
            return try await service.fetchPortfolioSummary(portfolioListId: nil)
        } catch {
            Self.logger.error("Portfolio summary load failed for allocation impact: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func allocationHoldings(
        details: StockDetails,
        summary: PortfolioSummaryResponse
    ) -> [PortfolioAllocationImpactCalculator.Holding] {
        let symbol = details.symbol.uppercased()
        return summary.allocation
            .filter { $0.symbol.uppercased() != "CASH" }
            .map { item in
                let itemSymbol = item.symbol.uppercased()
                return PortfolioAllocationImpactCalculator.Holding(
                    id: itemSymbol == symbol ? details.id : itemSymbol,
                    symbol: item.symbol,
                    shares: itemSymbol == symbol ? details.shares : 1,
                    buyPrice: itemSymbol == symbol ? details.buyPrice : item.value
                )
            }
    }

    private func loadInsights(symbol: String) async -> StockInsightsResponse? {
        do {
            return try await service.fetchStockInsights(symbol: symbol)
        } catch {
            Self.logger.error(
                "Stock insights load failed symbol=\(symbol, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func loadCompanyProfile(symbol: String) async -> CompanyProfileResponse? {
        do {
            return try await marketDataService.fetchCompanyProfile(symbol: symbol)
        } catch {
            return nil
        }
    }

    private func loadQuote(symbol: String) async -> StockMarketSnapshot? {
        do {
            return try await marketDataService.fetchQuote(symbol: symbol)
        } catch {
            return nil
        }
    }

    private func loadAnalystConsensus(symbol: String) async -> AnalystConsensusLoadResult {
        guard StockAnalystConsensus.isSupportedTicker(symbol) else {
            return AnalystConsensusLoadResult(
                consensus: nil,
                message: StockAnalystConsensus.unsupportedPlanMessage(for: symbol)
            )
        }

        do {
            let consensus = try await marketDataService.fetchAnalystConsensus(symbol: symbol)
            return AnalystConsensusLoadResult(consensus: consensus, message: nil)
        } catch let error as MarketDataHTTPClient.Error {
            if let message = error.errorDescription,
               message.localizedCaseInsensitiveContains("premium")
                || message.localizedCaseInsensitiveContains("subscription") {
                return AnalystConsensusLoadResult(
                    consensus: nil,
                    message: StockAnalystConsensus.unsupportedPlanMessage(for: symbol)
                )
            }
            return AnalystConsensusLoadResult(consensus: nil, message: nil)
        } catch {
            return AnalystConsensusLoadResult(consensus: nil, message: nil)
        }
    }

    private func loadBasicFinancials(symbol: String) async -> StockBasicFinancials? {
        do {
            return try await marketDataService.fetchBasicFinancials(symbol: symbol)
        } catch {
            return nil
        }
    }

    private func loadStockEarnings(symbol: String) async -> (events: [EarningsEvent], message: String?) {
        do {
            let events = try await marketDataService.fetchStockEarnings(symbol: symbol, limit: 8)
                .sorted { $0.date > $1.date }
            return (events, nil)
        } catch {
            return ([], error.localizedDescription)
        }
    }

    private func loadAnalysisMetrics(symbol: String) async -> AnalysisMetricsLoadResult {
        guard FMPFreeTierCoverage.isSupportedTicker(symbol) else {
            return AnalysisMetricsLoadResult(
                metrics: nil,
                message: FMPFreeTierCoverage.unsupportedAnalysisMessage(for: symbol)
            )
        }

        let defaults = UserDefaults.standard
        let wacc = defaults.object(forKey: "userWACC") as? Double
        let terminalGrowthRate = defaults.object(forKey: "userTerminalGrowthRate") as? Double
        let terminalMargin = defaults.object(forKey: "userTerminalMargin") as? Double
        let fcfMarginAssumption = defaults.object(forKey: "userFCFMarginAssumption") as? Double

        do {
            let metrics = try await marketDataService.fetchAnalysisMetrics(
                symbol: symbol,
                wacc: wacc,
                terminalGrowthRate: terminalGrowthRate,
                terminalMargin: terminalMargin,
                fcfMarginAssumption: fcfMarginAssumption
            )
            return AnalysisMetricsLoadResult(metrics: metrics, message: nil)
        } catch let error as MarketDataHTTPClient.Error {
            if let message = error.errorDescription,
               message.localizedCaseInsensitiveContains("market data coverage")
                || message.localizedCaseInsensitiveContains("free-tier coverage")
                || message.localizedCaseInsensitiveContains("premium")
                || message.localizedCaseInsensitiveContains("subscription") {
                return AnalysisMetricsLoadResult(
                    metrics: nil,
                    message: FMPFreeTierCoverage.unsupportedAnalysisMessage(for: symbol)
                )
            }
            return AnalysisMetricsLoadResult(metrics: nil, message: nil)
        } catch {
            return AnalysisMetricsLoadResult(metrics: nil, message: nil)
        }
    }

    private func loadFinancialStatements(symbol: String) async -> FinancialStatementsLoadResult {
        guard FMPFreeTierCoverage.isSupportedTicker(symbol) else {
            return FinancialStatementsLoadResult(
                statements: nil,
                message: FMPFreeTierCoverage.unsupportedStatementsMessage(for: symbol)
            )
        }

        async let balanceSheetsResult = loadFinancialStatementsSection(emptyValue: [BalanceSheetStatementResponse]()) {
            try await marketDataService.fetchBalanceSheetStatement(symbol: symbol, limit: 10, period: nil)
        }
        async let cashFlowsResult = loadFinancialStatementsSection(emptyValue: [CashFlowStatementResponse]()) {
            try await marketDataService.fetchCashFlowStatement(symbol: symbol, limit: 10, period: nil)
        }
        async let ratiosResult = loadFinancialStatementsSection(emptyValue: [RatiosResponse]()) {
            try await marketDataService.fetchRatios(symbol: symbol, limit: 10, period: nil)
        }
        async let ratiosTTMResult = loadFinancialStatementsSection(emptyValue: [RatiosTTMResponse]()) {
            try await marketDataService.fetchRatiosTTM(symbol: symbol)
        }
        async let growthResult = loadFinancialStatementsSection(emptyValue: [FinancialGrowthResponse]()) {
            try await marketDataService.fetchFinancialGrowth(symbol: symbol, limit: 10, period: nil)
        }
        async let estimatesResult = loadFinancialStatementsSection(emptyValue: [AnalystEstimatesResponse]()) {
            try await marketDataService.fetchAnalystEstimates(symbol: symbol, limit: 10, period: nil)
        }

        let balanceSheets = await balanceSheetsResult
        let cashFlows = await cashFlowsResult
        let ratios = await ratiosResult
        let ratiosTTM = await ratiosTTMResult
        let growth = await growthResult
        let estimates = await estimatesResult

        if [balanceSheets.isUnsupportedPlan, cashFlows.isUnsupportedPlan, ratios.isUnsupportedPlan, ratiosTTM.isUnsupportedPlan, growth.isUnsupportedPlan, estimates.isUnsupportedPlan]
            .contains(true) {
            return FinancialStatementsLoadResult(
                statements: nil,
                message: FMPFreeTierCoverage.unsupportedStatementsMessage(for: symbol)
            )
        }

        let statements = StockFinancialStatements.from(
            symbol: symbol,
            balanceSheets: balanceSheets.value,
            cashFlows: cashFlows.value,
            ratios: ratios.value,
            ratiosTTM: ratiosTTM.value,
            growth: growth.value,
            estimates: estimates.value
        )

        let hasAnyStatementsData =
            !balanceSheets.value.isEmpty
            || !cashFlows.value.isEmpty
            || !ratios.value.isEmpty
            || !ratiosTTM.value.isEmpty
            || !growth.value.isEmpty
            || !estimates.value.isEmpty

        if hasAnyStatementsData {
            return FinancialStatementsLoadResult(statements: statements, message: nil)
        }

        let firstErrorMessage = [
            balanceSheets.message,
            cashFlows.message,
            ratios.message,
            ratiosTTM.message,
            growth.message,
            estimates.message
        ].compactMap { $0 }.first

        if let firstErrorMessage {
            return FinancialStatementsLoadResult(statements: nil, message: firstErrorMessage)
        }

        return FinancialStatementsLoadResult(statements: statements, message: nil)
    }

    private func loadFinancialStatementsSection<Value: Sendable>(
        emptyValue: Value,
        operation: () async throws -> Value
    ) async -> FinancialStatementsSectionLoadResult<Value> {
        do {
            return FinancialStatementsSectionLoadResult(
                value: try await operation(),
                message: nil,
                isUnsupportedPlan: false
            )
        } catch let error as MarketDataHTTPClient.Error {
            let message = error.errorDescription ?? error.localizedDescription
            if isUnsupportedStatementsError(message: message) {
                return FinancialStatementsSectionLoadResult(
                    value: emptyValue,
                    message: nil,
                    isUnsupportedPlan: true
                )
            }
            if isMissingStatementsDataError(error) {
                return FinancialStatementsSectionLoadResult(
                    value: emptyValue,
                    message: nil,
                    isUnsupportedPlan: false
                )
            }
            return FinancialStatementsSectionLoadResult(
                value: emptyValue,
                message: message,
                isUnsupportedPlan: false
            )
        } catch {
            return FinancialStatementsSectionLoadResult(
                value: emptyValue,
                message: error.localizedDescription,
                isUnsupportedPlan: false
            )
        }
    }

    private func isUnsupportedStatementsError(message: String) -> Bool {
        message.localizedCaseInsensitiveContains("market data coverage")
            || message.localizedCaseInsensitiveContains("free-tier coverage")
            || message.localizedCaseInsensitiveContains("premium")
            || message.localizedCaseInsensitiveContains("subscription")
            || message.localizedCaseInsensitiveContains("unsupported symbol")
    }

    private func isMissingStatementsDataError(_ error: MarketDataHTTPClient.Error) -> Bool {
        switch error {
        case .invalidStatus(404):
            return true
        case .invalidStatus:
            return false
        case let .api(message):
            return message.localizedCaseInsensitiveContains("not found")
                || message.localizedCaseInsensitiveContains("no data")
                || message.localizedCaseInsensitiveContains("no financial")
                || message.localizedCaseInsensitiveContains("no analyst estimates")
        case .invalidResponse, .unauthorized:
            return false
        }
    }

    private func applyInsights(_ insights: StockInsightsResponse) {
        let primary = makePrimaryComparisonProfile(from: insights)
        let peers = insights.peers.map(makePeerComparisonProfile)

        primaryComparisonProfile = primary
        comparisonUniverse = [primary] + peers
        selectedPeerSymbols = []
        fillMissingPeers()
    }

    private func makePrimaryComparisonProfile(from insights: StockInsightsResponse) -> StockComparisonProfile {
        let metrics = mapComparisonMetrics(insights.profile.metrics)
        let scenarios = mapProjectionScenarios(
            insights.projectionScenarios,
            currentPrice: insights.profile.currentPrice,
            marketCap: insights.profile.marketCap,
            sharesOutstanding: insights.profile.sharesOutstanding
        )

        return StockComparisonProfile(
            symbol: insights.profile.symbol.uppercased(),
            companyName: insights.profile.companyName,
            currentPrice: insights.profile.currentPrice,
            marketCap: insights.profile.marketCap,
            sharesOutstanding: insights.profile.sharesOutstanding,
            metrics: metrics,
            projectionScenarios: scenarios,
            dcfBasePrice: insights.profile.dcfBasePrice,
            dcfBearPrice: insights.profile.dcfBearPrice,
            dcfBullPrice: insights.profile.dcfBullPrice
        )
    }

    private func makePeerComparisonProfile(from peer: StockInsightPeerDTO) -> StockComparisonProfile {
        StockComparisonProfile(
            symbol: peer.symbol.uppercased(),
            companyName: peer.companyName,
            currentPrice: peer.currentPrice,
            marketCap: peer.marketCap,
            sharesOutstanding: peer.sharesOutstanding,
            metrics: [:],
            projectionScenarios: [:],
            dcfBasePrice: nil,
            dcfBearPrice: nil,
            dcfBullPrice: nil
        )
    }

    private func mapComparisonMetrics(_ raw: [String: Double]) -> [StockComparisonMetric: Double] {
        var mapped: [StockComparisonMetric: Double] = [:]
        for (key, value) in raw {
            guard value.isFinite, let metric = StockComparisonMetric(rawValue: key) else { continue }
            mapped[metric] = value
        }
        return mapped
    }

    private func mapProjectionScenarios(
        _ scenarios: [StockInsightProjectionScenarioDTO],
        currentPrice: Double,
        marketCap: Double,
        sharesOutstanding: Double
    ) -> [StockProjectionScenarioKind: StockProjectionScenario] {
        var mapped: [StockProjectionScenarioKind: StockProjectionScenario] = [:]
        for scenario in scenarios {
            guard let kind = StockProjectionScenarioKind(rawValue: scenario.kind.lowercased()) else { continue }
            mapped[kind] = StockProjectionScenario(
                kind: kind,
                currentPrice: currentPrice,
                marketCap: marketCap,
                sharesOutstanding: sharesOutstanding,
                years: scenario.years.map {
                    StockProjectionYear(
                        year: $0.year,
                        revenue: $0.revenue,
                        revenueGrowth: $0.revenueGrowth,
                        netIncome: $0.netIncome,
                        netIncomeGrowth: $0.netIncomeGrowth,
                        netMargin: $0.netMargin,
                        eps: $0.eps,
                        freeCashFlow: nil,
                        peLowEstimate: $0.peLowEstimate,
                        peHighEstimate: $0.peHighEstimate,
                        sharePriceLow: $0.sharePriceLow,
                        sharePriceHigh: $0.sharePriceHigh,
                        cagrLow: $0.cagrLow,
                        cagrHigh: $0.cagrHigh
                    )
                }
            )
        }
        return mapped
    }

    private func applyAnalysisMetrics(_ metrics: StockAnalysisMetrics?, to symbol: String) {
        guard let metrics else { return }

        let normalizedSymbol = symbol.uppercased()
        if let primaryComparisonProfile, primaryComparisonProfile.symbol == normalizedSymbol {
            self.primaryComparisonProfile = StockComparisonProfile(
                symbol: primaryComparisonProfile.symbol,
                companyName: primaryComparisonProfile.companyName,
                currentPrice: metrics.currentPrice ?? primaryComparisonProfile.currentPrice,
                marketCap: metrics.marketCap ?? primaryComparisonProfile.marketCap,
                sharesOutstanding: metrics.sharesOutstanding ?? primaryComparisonProfile.sharesOutstanding,
                metrics: metrics.comparisonMetrics,
                projectionScenarios: makeProjectionScenarios(metrics: metrics, fallback: primaryComparisonProfile.projectionScenarios),
                dcfBasePrice: metrics.dcfBasePrice,
                dcfBearPrice: metrics.dcfBearPrice,
                dcfBullPrice: metrics.dcfBullPrice
            )
        }
    }

    private func makeProjectionScenarios(
        metrics: StockAnalysisMetrics,
        fallback: [StockProjectionScenarioKind: StockProjectionScenario]
    ) -> [StockProjectionScenarioKind: StockProjectionScenario] {
        guard let baseProjections = metrics.yearlyProjections,
              let currentPrice = metrics.currentPrice,
              let marketCap = metrics.marketCap,
              let shares = metrics.sharesOutstanding,
              let baseYear = metrics.baseYear,
              !baseProjections.isEmpty else {
            return fallback
        }

        let peLow = max((metrics.forwardPE ?? 20) * 0.9, 8)
        let peHigh = max((metrics.ttmPE ?? peLow) * 1.05, peLow + 1)
        let terminalGrowthRate = metrics.terminalGrowthRate ?? 0.025
        let terminalMargin = metrics.terminalMargin ?? 0.22

        let buildScenario = { (kind: StockProjectionScenarioKind, shift: Double, peLowShift: Double, peHighShift: Double) -> StockProjectionScenario in
            var years: [StockProjectionYear] = []

            let ttmRev = baseProjections[0].revenue / (1 + baseProjections[0].revenueGrowth)
            let ttmNetInc = baseProjections[0].netIncome / (1 + baseProjections[0].netIncomeGrowth)

            years.append(StockProjectionYear(
                year: baseYear,
                revenue: ttmRev,
                revenueGrowth: metrics.ttmRevenueGrowth ?? 0,
                netIncome: ttmNetInc,
                netIncomeGrowth: metrics.ttmEPSGrowth ?? 0,
                netMargin: metrics.netMargin ?? 0.1,
                eps: ttmNetInc / shares,
                freeCashFlow: nil,
                peLowEstimate: peLow,
                peHighEstimate: peHigh,
                sharePriceLow: (ttmNetInc / shares) * peLow,
                sharePriceHigh: (ttmNetInc / shares) * peHigh,
                cagrLow: nil,
                cagrHigh: nil
            ))

            var currentRev = ttmRev
            var currentNetInc = ttmNetInc
            let finalNetMargin = metrics.netMargin ?? 0.1

            for (i, proj) in baseProjections.enumerated() {
                let revGrowth = max(proj.revenueGrowth + shift, terminalGrowthRate)
                let niGrowth = max(proj.netIncomeGrowth + shift, terminalGrowthRate)

                currentRev *= (1 + revGrowth)
                currentNetInc *= (1 + niGrowth)
                let targetMargin = min(finalNetMargin + Double(i + 1) * 0.02, terminalMargin)
                let actualNetInc = currentRev * targetMargin
                let actualEps = actualNetInc / shares

                let currentPELow = peLow + peLowShift
                let currentPEHigh = peHigh + peHighShift
                let priceLow = actualEps * currentPELow
                let priceHigh = actualEps * currentPEHigh

                let yearsForward = Double(i + 1)
                let cagrLow = pow(priceLow / currentPrice, 1.0 / yearsForward) - 1
                let cagrHigh = pow(priceHigh / currentPrice, 1.0 / yearsForward) - 1

                years.append(StockProjectionYear(
                    year: proj.year,
                    revenue: currentRev,
                    revenueGrowth: revGrowth,
                    netIncome: actualNetInc,
                    netIncomeGrowth: niGrowth,
                    netMargin: targetMargin,
                    eps: actualEps,
                    freeCashFlow: proj.fcf,
                    peLowEstimate: currentPELow,
                    peHighEstimate: currentPEHigh,
                    sharePriceLow: priceLow,
                    sharePriceHigh: priceHigh,
                    cagrLow: cagrLow,
                    cagrHigh: cagrHigh
                ))
            }

            return StockProjectionScenario(
                kind: kind,
                currentPrice: currentPrice,
                marketCap: marketCap,
                sharesOutstanding: shares,
                years: years
            )
        }

        return [
            .bear: buildScenario(.bear, -0.03, -2, -2),
            .base: buildScenario(.base, 0, 0, 0),
            .bull: buildScenario(.bull, 0.03, 2, 2)
        ]
    }

    private func fillMissingPeers() {
        guard let primaryComparisonProfile else { return }

        var resolved = selectedPeerSymbols.filter { $0 != primaryComparisonProfile.symbol }
        let defaults = comparisonUniverse
            .map(\.symbol)
            .filter { $0 != primaryComparisonProfile.symbol && !resolved.contains($0) }

        resolved.append(contentsOf: defaults.prefix(max(0, 2 - resolved.count)))
        selectedPeerSymbols = Array(resolved.prefix(2))

        comparisonRefreshTask?.cancel()
        comparisonRefreshTask = Task { [weak self] in
            await self?.refreshComparisonMetrics()
            await self?.loadComparisonChart()
        }
    }

    private func refreshComparisonMetrics() async {
        guard !selectedPeerSymbols.isEmpty else { return }
        let symbols = selectedPeerSymbols
        let start = ContinuousClock.now

        do {
            let metricsList = try await marketDataService.fetchMarketCompare(symbols: symbols)
            guard !Task.isCancelled else { return }
            for metrics in metricsList {
                updateUniverseProfile(with: metrics)
            }
            Self.logger.debug(
                "Comparison metrics refresh symbols=\(symbols.joined(separator: ","), privacy: .public) duration_ms=\(Self.durationInMilliseconds(from: start.duration(to: .now)), privacy: .public)"
            )
        } catch {
            guard !Task.isCancelled else { return }
            Self.logger.error(
                "Comparison metrics refresh failed symbols=\(symbols.joined(separator: ","), privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private static func durationInMilliseconds(from duration: Duration) -> Double {
        let components = duration.components
        let millisecondsFromSeconds = Double(components.seconds) * 1_000
        let millisecondsFromAttoseconds = Double(components.attoseconds) / 1_000_000_000_000_000
        return millisecondsFromSeconds + millisecondsFromAttoseconds
    }

    private func updateUniverseProfile(with metrics: StockAnalysisMetrics) {
        if let index = comparisonUniverse.firstIndex(where: { $0.symbol == metrics.symbol }) {
            let existing = comparisonUniverse[index]
            comparisonUniverse[index] = StockComparisonProfile(
                symbol: existing.symbol,
                companyName: existing.companyName,
                currentPrice: metrics.currentPrice ?? existing.currentPrice,
                marketCap: metrics.marketCap ?? existing.marketCap,
                sharesOutstanding: metrics.sharesOutstanding ?? existing.sharesOutstanding,
                metrics: metrics.comparisonMetrics,
                projectionScenarios: makeProjectionScenarios(metrics: metrics, fallback: existing.projectionScenarios),
                dcfBasePrice: metrics.dcfBasePrice,
                dcfBearPrice: metrics.dcfBearPrice,
                dcfBullPrice: metrics.dcfBullPrice
            )
        }
    }

    // MARK: - Price Chart

    func loadPriceChart(symbol: String, range: PriceChartRange) async {
        isChartLoading = true
        chartErrorMessage = nil
        defer { isChartLoading = false }

        do {
            let series = try await marketDataService.fetchPriceChart(
                symbol: symbol, range: range.rawValue
            )
            chartSeries = series
        } catch {
            chartErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            Self.logger.error(
                "Price chart load failed symbol=\(symbol, privacy: .public) range=\(range.rawValue, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func switchChartRange(_ range: PriceChartRange) {
        guard range != selectedChartRange else { return }
        selectedChartRange = range
        guard let symbol = details?.symbol else { return }

        // Always reload when range changes
        Task {
            await loadPriceChart(symbol: symbol, range: range)
        }
    }

    // MARK: - Price Chart Comparison

    private var allComparisonSymbols: [String] {
        var symbols = selectedPeerSymbols
        if let primary = primaryComparisonProfile {
            symbols.append(primary.symbol)
        }
        return symbols.filter { !$0.isEmpty }
    }

    func loadComparisonChart() async {
        let symbols = allComparisonSymbols
        guard !symbols.isEmpty else { return }
        
        isComparisonChartLoading = true
        comparisonChartErrorMessage = nil
        defer { isComparisonChartLoading = false }
        
        do {
            let response = try await marketDataService.fetchPriceChartComparison(
                symbols: symbols, range: selectedComparisonChartRange.rawValue
            )
            guard !Task.isCancelled else { return }
            comparisonChartResponse = response
        } catch {
            guard !Task.isCancelled else { return }
            comparisonChartErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            Self.logger.error("Comparison chart load failed error=\(error.localizedDescription, privacy: .public)")
        }
    }

    func switchComparisonChartRange(_ range: PriceChartRange) {
        guard range != selectedComparisonChartRange else { return }
        selectedComparisonChartRange = range
        
        comparisonRefreshTask?.cancel()
        comparisonRefreshTask = Task { [weak self] in
            await self?.loadComparisonChart()
        }
    }
}
