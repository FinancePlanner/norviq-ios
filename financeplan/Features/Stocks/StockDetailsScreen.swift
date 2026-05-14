//
//  StockDetailsScreen.swift
//  financeplan
//
//  Created by Fernando Correia on 10.03.26.
//

import Factory
import PostHog
import SwiftUI
import StockPlanShared

struct StockDetailScreen: View {
    let stockId: String
    let initialSymbol: String
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @InjectedObservable(\Container.billingManager) private var billingManager
    @StateObject private var viewModel = StockDetailsViewModel()
    @State private var activeSheet: ActiveSheet?
    @State private var isPaywallPresented = false
    @State private var selectedTab: StockDetailTab = .overview
    @State private var selectedScenario: StockProjectionScenarioKind = .base
    @State private var selectedStatementPeriod: StockFinancialStatementPeriod = .fy
    @State private var pendingDCFValuation: DCFValuationPreset?
    @State private var isConfirmingDCFValuationApply = false

    private enum ActiveSheet: String, Identifiable {
        case editValuation
        case editPosition
        case sellPosition
        case editAnalysis
        case editDCF

        var id: String { rawValue }
    }

    private var isShowingLoadingState: Bool {
        viewModel.isLoading && viewModel.details == nil
    }

    private var loadErrorMessage: String? {
        guard viewModel.details == nil else { return nil }
        return viewModel.errorMessage
    }

    var body: some View {
        rootContent
        .navigationTitle(viewModel.details?.symbol ?? initialSymbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                shareMenu
            }
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .sheet(isPresented: $isPaywallPresented) {
            PaywallView(billingManager: billingManager)
        }
        .confirmationDialog(
            "Replace valuation with DCF values?",
            isPresented: $isConfirmingDCFValuationApply,
            titleVisibility: .visible
        ) {
            Button("Replace with DCF values", role: .destructive) {
                applyPendingDCFValuation()
            }
            Button("Cancel", role: .cancel) {
                pendingDCFValuation = nil
            }
        } message: {
            Text("This replaces the current bear, base, and bull ranges. Rationale and target date stay unchanged.")
        }
        .task {
            await loadStockDetails()
        }
        .task(id: selectedTab) {
            await loadSupplementaryData(for: selectedTab)
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if isShowingLoadingState {
                ProgressView("Loading stock...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if let loadErrorMessage {
            ErrorRetryView(message: loadErrorMessage, onRetry: retryLoad)
        } else {
            content
        }
    }

    private var shareMenu: some View {
        Group {
            if let shareSnapshot = viewModel.shareSnapshot {
                Menu {
                    ShareLink(
                        item: shareSnapshot.body,
                        subject: Text(shareSnapshot.title),
                        message: Text("Shared from financeplan")
                    ) {
                        Label("Snapshot", systemImage: "doc.text")
                    }

                    if let thesisPayload {
                        ShareLink(
                            item: thesisPayload.body,
                            subject: Text(thesisPayload.title),
                            message: Text("Shared from financeplan")
                        ) {
                            Label("Thesis", systemImage: "quote.bubble")
                        }
                    }

                    if let fundamentalsPayload {
                        ShareLink(
                            item: fundamentalsPayload.body,
                            subject: Text(fundamentalsPayload.title),
                            message: Text("Shared from financeplan")
                        ) {
                            Label("Fundamentals", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }

                    if let priceTargetsPayload {
                        ShareLink(
                            item: priceTargetsPayload.body,
                            subject: Text(priceTargetsPayload.title),
                            message: Text("Shared from financeplan")
                        ) {
                            Label("Price targets", systemImage: "scope")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share stock snapshot")
            } else {
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(true)
                .accessibilityLabel("Share stock snapshot")
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                StockDetailHeroCard(
                    details: viewModel.details,
                    companyProfile: viewModel.companyProfile,
                    comparisonProfile: viewModel.primaryComparisonProfile,
                    marketSnapshot: viewModel.marketSnapshot
                )

                StockDetailTabBar(selectedTab: $selectedTab, isPro: billingManager.isPro)

                switch selectedTab {
                case .chart:
                    StockPriceChartTab(
                        series: viewModel.chartSeries,
                        selectedRange: viewModel.selectedChartRange,
                        isLoading: viewModel.isChartLoading,
                        errorMessage: viewModel.chartErrorMessage,
                        onSelectRange: viewModel.switchChartRange
                    )
                case .overview:
                    StockOverviewTab(
                        details: viewModel.details,
                        valuation: viewModel.valuation,
                        marketSnapshot: viewModel.marketSnapshot,
                        analystConsensus: viewModel.analystConsensus,
                        analystConsensusMessage: viewModel.analystConsensusMessage,
                        basicFinancials: viewModel.basicFinancials,
                        errorMessage: viewModel.errorMessage,
                        onEditValuation: presentEditValuation,
                        onEditPosition: presentEditPosition,
                        onSellPosition: presentSellPosition
                    )
                case .statements:
                    ProGateView(billingManager: billingManager) {
                        StockFinancialStatementsTab(
                            statements: viewModel.financialStatements,
                            errorMessage: viewModel.financialStatementsMessage,
                            selectedPeriod: $selectedStatementPeriod
                        )
                    }
                case .analysis:
                    ProGateView(billingManager: billingManager) {
                        StockAnalysisTab(
                            details: viewModel.details,
                            profile: viewModel.primaryComparisonProfile,
                            analysisMetrics: viewModel.analysisMetrics,
                            analysisMetricsMessage: viewModel.analysisMetricsMessage,
                            valuation: viewModel.valuation,
                            onEditAnalysis: presentEditAnalysis,
                            onEditDCF: presentEditDCF,
                            onApplyDCFToValuation: applyDCFToValuation
                        )
                    }
                case .forecast:
                    ProGateView(billingManager: billingManager) {
                        StockForecastTab(
                            profile: viewModel.primaryComparisonProfile,
                            selectedScenario: $selectedScenario,
                            onEditDCF: presentEditDCF,
                            onApplyDCFToValuation: applyDCFToValuation
                        )
                    }
                case .compare:
                    ProGateView(billingManager: billingManager) {
                        StockCompareTab(viewModel: viewModel)
                    }
                case .news:
                    StockNewsTab(news: viewModel.news)
                case .earnings:
                    ProGateView(billingManager: billingManager) {
                        StockEarningsTab(
                            symbol: viewModel.details?.symbol ?? initialSymbol,
                            earnings: viewModel.stockEarnings,
                            isLoading: viewModel.isEarningsLoading,
                            errorMessage: viewModel.stockEarningsMessage,
                            selectedTranscript: viewModel.selectedEarningsTranscript,
                            isTranscriptLoading: viewModel.isEarningsTranscriptLoading,
                            transcriptErrorMessage: viewModel.earningsTranscriptMessage,
                            onSelectTranscript: { event in
                                Task { await viewModel.loadEarningsTranscript(for: event) }
                            },
                            onDismissTranscript: {
                                viewModel.clearEarningsTranscript()
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .accessibilityIdentifier("stockDetailsScreen")
        }
        .background(MeshGradientBackground().ignoresSafeArea())
        .refreshable {
            await viewModel.load(stockId: stockId, force: true)
            await viewModel.loadSupplementaryDataIfNeeded(for: selectedTab)
        }
        .animation(.snappy(duration: 0.24), value: selectedTab)
        .animation(.snappy(duration: 0.24), value: selectedScenario)
        .animation(.snappy(duration: 0.24), value: selectedStatementPeriod)
        .tint(AppTheme.Colors.tint(for: colorScheme))
    }

    @ViewBuilder
    private func sheetContent(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .editPosition:
            if let stock = viewModel.details {
                EditStockPositionSheet(
                    stock: stock,
                    isSaving: viewModel.isSavingPosition,
                    isDeleting: viewModel.isDeletingPosition,
                    allocationImpactProvider: viewModel.allocationImpact(for:),
                    onCancel: dismissActiveSheet,
                    onSave: saveEditedPosition,
                    onDelete: deletePosition
                )
            }
        case .editValuation:
            EditStockValuationView(
                symbol: viewModel.details?.symbol ?? initialSymbol,
                existing: viewModel.valuation,
                onSave: saveValuation
            )
        case .sellPosition:
            if let stock = viewModel.details {
                SellStockSheet(
                    stock: stock,
                    isSelling: viewModel.isSellingPosition,
                    allocationImpactProvider: viewModel.allocationImpact(for:),
                    onCancel: dismissActiveSheet,
                    onSell: sellPosition
                )
            }
        case .editAnalysis:
            if let stock = viewModel.details {
                EditStockAnalysisSheet(stock: stock, onSave: saveAnalysis)
            }
        case .editDCF:
            EditDCFSheet(onSave: reloadAnalysisMetrics)
        }
    }

    private func loadStockDetails() async {
        await viewModel.load(stockId: stockId)
        // PostHog: Track stock detail screen view
        PostHogSDK.shared.capture("stock_detail_viewed", properties: [
            "symbol": initialSymbol,
            "stock_id": stockId,
        ])
    }

    private func loadSupplementaryData(for tab: StockDetailTab) async {
        await viewModel.loadSupplementaryDataIfNeeded(for: tab)
    }

    private func retryLoad() {
        Task { await viewModel.load(stockId: stockId, force: true) }
    }

    private func dismissActiveSheet() {
        activeSheet = nil
    }

    private func presentEditValuation() {
        guard billingManager.isPro else {
            // PostHog: Track paywall shown from stock valuation
            PostHogSDK.shared.capture("paywall_viewed", properties: [
                "source": "stock_valuation",
                "symbol": initialSymbol,
            ])
            isPaywallPresented = true
            return
        }
        activeSheet = .editValuation
    }

    private func presentEditPosition() {
        activeSheet = .editPosition
    }

    private func presentSellPosition() {
        activeSheet = .sellPosition
    }

    private func presentEditAnalysis() {
        guard billingManager.isPro else {
            isPaywallPresented = true
            return
        }
        activeSheet = .editAnalysis
    }

    private func presentEditDCF() {
        guard billingManager.isPro else {
            isPaywallPresented = true
            return
        }
        activeSheet = .editDCF
    }

    private func saveEditedPosition(_ updated: StockResponse) async -> Bool {
        let ok = await viewModel.savePosition(updated)
        if ok {
            dismissActiveSheet()
        }
        return ok
    }

    private func deletePosition() async -> Bool {
        let ok = await viewModel.deletePosition()
        if ok {
            dismissActiveSheet()
            dismiss()
        }
        return ok
    }

    private func saveValuation(_ draft: StockValuationDraft) async -> String? {
        await viewModel.saveValuation(draft)
    }

    private func sellPosition(_ request: SellStockRequest) async -> String? {
        let outcome = await viewModel.sellPosition(request)
        if outcome.shouldDismiss {
            // PostHog: Track successful position sale
            PostHogSDK.shared.capture("position_sold", properties: [
                "symbol": viewModel.details?.symbol ?? initialSymbol,
                "shares_sold": request.sharesToSell,
            ])
            dismissActiveSheet()
            dismiss()
        }
        return outcome.errorMessage
    }

    private func saveAnalysis(_ analysis: String?) async -> String? {
        await viewModel.saveAnalysis(analysis)
    }

    private func reloadAnalysisMetrics() {
        viewModel.reloadAnalysisMetrics()
    }

    private func applyDCFToValuation(bearPrice: Double, basePrice: Double, bullPrice: Double) {
        let preset = DCFValuationPreset(bearPrice: bearPrice, basePrice: basePrice, bullPrice: bullPrice)

        if viewModel.valuation == nil {
            saveDCFValuation(preset)
        } else {
            pendingDCFValuation = preset
            isConfirmingDCFValuationApply = true
        }
    }

    private func applyPendingDCFValuation() {
        guard let pendingDCFValuation else { return }
        self.pendingDCFValuation = nil
        saveDCFValuation(pendingDCFValuation)
    }

    private func saveDCFValuation(_ preset: DCFValuationPreset) {
        Task { @MainActor in
            _ = await viewModel.applyDCFToValuation(
                bearPrice: preset.bearPrice,
                basePrice: preset.basePrice,
                bullPrice: preset.bullPrice
            )
        }
    }

    private var thesisPayload: StockSharePayload? {
        guard let details = viewModel.details else { return nil }
        let text = details.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? viewModel.valuation?.rationale?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { return nil }
        return StockSharePayloadFormatter.thesis(
            symbol: details.symbol,
            thesis: text,
            details: details
        )
    }

    private var fundamentalsPayload: StockSharePayload? {
        guard let profile = viewModel.primaryComparisonProfile else { return nil }
        return StockSharePayloadFormatter.fundamentals(profile: profile)
    }

    private var priceTargetsPayload: StockSharePayload? {
        guard let details = viewModel.details, let valuation = viewModel.valuation else { return nil }
        return StockSharePayloadFormatter.priceTargets(
            symbol: details.symbol,
            valuation: valuation,
            currentPrice: viewModel.marketSnapshot?.currentPrice
        )
    }
}

private struct DCFValuationPreset {
    let bearPrice: Double
    let basePrice: Double
    let bullPrice: Double
}
