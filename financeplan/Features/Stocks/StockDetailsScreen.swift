//
//  StockDetailsScreen.swift
//  financeplan
//
//  Created by Fernando Correia on 10.03.26.
//

import SwiftUI
import StockPlanShared

struct StockDetailScreen: View {
    let stockId: String
    let initialSymbol: String
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = StockDetailsViewModel()
    @State private var showEditValuation = false
    @State private var showEditPosition = false
    @State private var showEditAnalysis = false
    @State private var selectedTab: StockDetailTab = .overview
    @State private var selectedScenario: StockProjectionScenarioKind = .base
    @State private var selectedStatementPeriod: StockFinancialStatementPeriod = .fy

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.details == nil {
                ProgressView("Loading stock...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let errorMessage = viewModel.errorMessage, viewModel.details == nil {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task {
                            await viewModel.load(stockId: stockId, force: true)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                content
            }
        }
        .navigationTitle(viewModel.details?.symbol ?? initialSymbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let shareSnapshot = viewModel.shareSnapshot {
                    ShareLink(
                        item: shareSnapshot.body,
                        subject: Text(shareSnapshot.title),
                        message: Text("Shared from financeplan")
                    ) {
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
        .sheet(isPresented: $showEditPosition) {
            if let stock = viewModel.details {
                EditStockPositionSheet(
                    stock: stock,
                    isSaving: viewModel.isSavingPosition,
                    isDeleting: viewModel.isDeletingPosition,
                    onCancel: { showEditPosition = false },
                    onSave: { updated in
                        let ok = await viewModel.savePosition(updated)
                        if ok {
                            showEditPosition = false
                        }
                        return ok
                    },
                    onDelete: {
                        let ok = await viewModel.deletePosition()
                        if ok {
                            showEditPosition = false
                            dismiss()
                        }
                        return ok
                    }
                )
            }
        }
        .sheet(isPresented: $showEditValuation) {
            EditStockValuationView(
                symbol: viewModel.details?.symbol ?? initialSymbol,
                existing: viewModel.valuation
            ) { draft in
                return await viewModel.saveValuation(draft)
            }
        }
        .sheet(isPresented: $showEditAnalysis) {
            if let stock = viewModel.details {
                EditStockAnalysisSheet(stock: stock) { analysis in
                    await viewModel.saveAnalysis(analysis)
                }
            }
        }
        .task {
            await viewModel.load(stockId: stockId)
        }
        .task(id: selectedTab) {
            await viewModel.loadSupplementaryDataIfNeeded(for: selectedTab)
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

                StockDetailTabBar(selectedTab: $selectedTab)

                switch selectedTab {
                case .overview:
                    StockOverviewTab(
                        details: viewModel.details,
                        valuation: viewModel.valuation,
                        marketSnapshot: viewModel.marketSnapshot,
                        analystConsensus: viewModel.analystConsensus,
                        analystConsensusMessage: viewModel.analystConsensusMessage,
                        basicFinancials: viewModel.basicFinancials,
                        errorMessage: viewModel.errorMessage,
                        onEditValuation: { showEditValuation = true },
                        onEditPosition: { showEditPosition = true }
                    )
                case .statements:
                    StockFinancialStatementsTab(
                        statements: viewModel.financialStatements,
                        errorMessage: viewModel.financialStatementsMessage,
                        selectedPeriod: $selectedStatementPeriod
                    )
                case .analysis:
                    StockAnalysisTab(
                        details: viewModel.details,
                        profile: viewModel.primaryComparisonProfile,
                        analysisMetrics: viewModel.analysisMetrics,
                        analysisMetricsMessage: viewModel.analysisMetricsMessage,
                        valuation: viewModel.valuation,
                        onEditAnalysis: { showEditAnalysis = true }
                    )
                case .forecast:
                    StockForecastTab(
                        profile: viewModel.primaryComparisonProfile,
                        selectedScenario: $selectedScenario
                    )
                case .compare:
                    StockCompareTab(viewModel: viewModel)
                case .news:
                    StockNewsTab(news: viewModel.news)
                case .earnings:
                    StockEarningsTab(
                        symbol: viewModel.details?.symbol ?? initialSymbol,
                        earnings: viewModel.stockEarnings,
                        isLoading: viewModel.isEarningsLoading,
                        errorMessage: viewModel.stockEarningsMessage
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
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
}
