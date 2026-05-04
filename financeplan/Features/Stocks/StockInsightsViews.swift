import Charts
import StockPlanShared
import SwiftUI

struct StockDetailHeroCard: View {
    let details: StockDetails?
    let companyProfile: CompanyProfileResponse?
    let comparisonProfile: StockComparisonProfile?
    let marketSnapshot: StockMarketSnapshot?

    @Environment(\.colorScheme) private var colorScheme

    private var displayPrice: Double? {
        marketSnapshot?.currentPrice ?? comparisonProfile?.currentPrice
    }

    private var positionMarketValue: Double? {
        guard let details, let displayPrice else { return nil }
        return details.shares * displayPrice
    }

    private var costBasis: Double? {
        guard let details else { return nil }
        return details.shares * details.buyPrice
    }

    private var symbolText: String {
        companyProfile?.displayTicker ?? comparisonProfile?.symbol ?? details?.symbol ?? "Stock"
    }

    private var companyNameText: String {
        companyProfile?.displayName ?? comparisonProfile?.companyName ?? "Waiting for company profile"
    }

    private var summaryText: String? {
        var values: [String] = []

        if let exchange = companyProfile?.exchange?.trimmingCharacters(in: .whitespacesAndNewlines),
           !exchange.isEmpty {
            values.append(exchange)
        }

        if let industry = companyProfile?.finnhubIndustry?.trimmingCharacters(in: .whitespacesAndNewlines),
           !industry.isEmpty {
            values.append(industry)
        }

        if let country = companyProfile?.localizedCountryName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !country.isEmpty {
            values.append(country)
        }

        return values.isEmpty ? nil : values.joined(separator: " • ")
    }

    var body: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    StockCompanyAvatarView(
                        companyProfile: companyProfile,
                        fallbackText: symbolText,
                        colorScheme: colorScheme
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(symbolText)
                            .typography(.hero, weight: .bold)

                        Text(companyNameText)
                            .typography(.small)
                            .foregroundStyle(.secondary)

                        if let summaryText {
                            Text(summaryText)
                                .typography(.nano)
                                .foregroundStyle(.secondary)
                        }

                        if let details {
                            Text("Purchased \(details.buyDate) • \(details.shares.formatted(.number.precision(.fractionLength(0...2)))) shares")
                                .typography(.nano)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                HStack(alignment: .top, spacing: 10) {
                    HeroMetricPill(
                        title: "Current price",
                        value: displayPrice?.currency ?? "Pending",
                        tint: AppTheme.Colors.tint(for: colorScheme)
                    )
                    HeroMetricPill(
                        title: "Position",
                        value: positionMarketValue?.currency ?? "Pending",
                        tint: AppTheme.Colors.success
                    )
                    HeroMetricPill(
                        title: "Cost basis",
                        value: costBasis?.currency ?? "Pending",
                        tint: AppTheme.Colors.warning
                    )
                }

                if let companyProfile {
                    Divider()

                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            DetailItem(title: "Exchange", value: companyProfile.exchange ?? "—")
                            DetailItem(title: "Industry", value: companyProfile.finnhubIndustry ?? "—")
                        }

                        GridRow {
                            DetailItem(title: "Country", value: companyProfile.localizedCountryName ?? "—")
                            DetailItem(title: "IPO", value: companyProfile.ipo ?? "—")
                        }

                        GridRow {
                            DetailItem(title: "Currency", value: companyProfile.currency ?? "—")
                            DetailItem(title: "Estimate currency", value: companyProfile.estimateCurrency ?? "—")
                        }

                        GridRow {
                            DetailItem(
                                title: "Market cap",
                                value: companyProfile.marketCapitalizationAmount.map { StockMetricFormatter.compactCurrency($0) } ?? "—"
                                )
                                DetailItem(
                                title: "Shares outstanding",
                                value: companyProfile.sharesOutstandingAmount.map { StockMetricFormatter.compactNumber($0) } ?? "—"
                                )                        }

                        GridRow {
                            DetailItem(title: "Phone", value: companyProfile.phone ?? "—")
                            CompanyProfileWebsiteItem(companyProfile: companyProfile)
                        }
                    }
                }
            }
        }
    }
}

struct StockOverviewTab: View {
    let details: StockDetails?
    let valuation: StockValuationRequest?
    let marketSnapshot: StockMarketSnapshot?
    let analystConsensus: StockAnalystConsensus?
    let analystConsensusMessage: String?
    let basicFinancials: StockBasicFinancials?
    let errorMessage: String?
    let onEditValuation: () -> Void
    let onEditPosition: () -> Void
    let onSellPosition: () -> Void

    var body: some View {
        LazyVStack(spacing: 16) {
            if let details {
                StockPositionOverviewCard(
                    details: details,
                    onEditPosition: onEditPosition,
                    onSellPosition: onSellPosition
                )
            }

            if let marketSnapshot {
                StockMarketSnapshotCard(snapshot: marketSnapshot)
            } else {
                GlassCard {
                    Text("No live quote data is available for this stock right now.")
                        .typography(.small)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let analystConsensus {
                StockConsensusCard(consensus: analystConsensus)
            } else {
                StockConsensusPlaceholderCard(
                    message: analystConsensusMessage,
                    isWarning: analystConsensusMessage != nil
                )
            }

            if let basicFinancials {
                StockBasicFinancialsCard(financials: basicFinancials)
            } else {
                StockBasicFinancialsPlaceholderCard()
            }

            StockValuationSummaryCard(
                symbol: details?.symbol,
                currentPrice: marketSnapshot?.currentPrice,
                valuation: valuation,
                onEditValuation: onEditValuation
            )

            if let errorMessage {
                GlassCard {
                    Text(errorMessage)
                        .typography(.small)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct StockFinancialStatementsTab: View {
    let statements: StockFinancialStatements?
    let errorMessage: String?
    @Binding var selectedPeriod: StockFinancialStatementPeriod

    var body: some View {
        LazyVStack(spacing: 16) {
            if let statements {
                FinancialStatementsIntroCard(symbol: statements.symbol)
                FinancialStatementPeriodPicker(selectedPeriod: $selectedPeriod)
                FinancialStatementTableCard(
                    title: "Balance sheet",
                    subtitle: "Review assets, liabilities, and equity across the selected filing period.",
                    statements: statements.balanceSheets(for: selectedPeriod),
                    emptyText: "No balance sheet filings are available for \(selectedPeriod.title)."
                )
                FinancialStatementTableCard(
                    title: "Cash flow",
                    subtitle: "Review operating, investing, and financing cash movements across the selected filing period.",
                    statements: statements.cashFlows(for: selectedPeriod),
                    emptyText: "No cash flow filings are available for \(selectedPeriod.title)."
                )
                FinancialMetricTableCard(
                    title: "Ratios",
                    subtitle: "Review valuation, capital efficiency, returns, and working-capital metrics across the selected filing period.",
                    snapshots: statements.ratios(for: selectedPeriod),
                    emptyText: "No ratio snapshots are available for \(selectedPeriod.title)."
                )
                FinancialMetricTableCard(
                    title: "Financial growth",
                    subtitle: "Review revenue, EPS, cash flow, share count, and long-term per-share growth across the selected filing period.",
                    snapshots: statements.growth(for: selectedPeriod),
                    emptyText: "No growth snapshots are available for \(selectedPeriod.title)."
                )
                FinancialMetricTableCard(
                    title: "Financial estimates",
                    subtitle: "Review forward revenue, EBITDA, EBIT, net income, SG&A, EPS, and analyst-count ranges.",
                    snapshots: statements.estimates,
                    emptyText: "No financial estimates are available right now."
                )
            } else if let errorMessage {
                ResearchPlaceholderCard(
                    title: "Financial statements",
                    bodyText: errorMessage
                )
            } else {
                ResearchPlaceholderCard(
                    title: "Financial statements",
                    bodyText: "Financial statement data is currently unavailable for this symbol."
                )
            }
        }
    }
}

struct StockPriceChartTab: View {
    let series: PriceChartSeries?
    let selectedRange: PriceChartRange
    let isLoading: Bool
    let errorMessage: String?
    let onSelectRange: (PriceChartRange) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LazyVStack(spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Share price chart")
                            .typography(.small, weight: .semibold)

                        Text("Track price movement across intraday and long-range windows.")
                            .typography(.nano)
                            .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PriceChartRange.allCases, id: \.rawValue) { range in
                                Button {
                                    onSelectRange(range)
                                } label: {
                                    Text(range.title)
                                        .typography(.caption, weight: .semibold)
                                        .foregroundStyle(range == selectedRange ? .white : .primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            range == selectedRange
                                                ? AppTheme.Colors.tint(for: colorScheme)
                                                : Color.secondary.opacity(0.10),
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if isLoading && series == nil {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .typography(.small)
                            .foregroundStyle(AppTheme.Colors.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let series, !series.points.isEmpty {
                        StockPriceChart(series: series)
                    } else {
                        Text("No price chart data is available for this symbol yet.")
                            .typography(.small)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 32)
                    }
                }
            }
        }
    }
}

private struct StockPriceChart: View {
    let series: PriceChartSeries

    @Environment(\.colorScheme) private var colorScheme

    private var latestPoint: PriceChartPoint? {
        series.points.last
    }

    private var firstPoint: PriceChartPoint? {
        series.points.first
    }

    private var change: Double? {
        guard let first = firstPoint?.close, let latest = latestPoint?.close, first > 0 else { return nil }
        return (latest - first) / first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(latestPoint?.close.currency ?? "Pending")
                            .typography(.title, weight: .bold)
                            .monospacedDigit()

                        Text("\(series.symbol.uppercased()) · \(series.range)")
                            .typography(.nano, weight: .semibold)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(change.map { StockMetricFormatter.signedPercentText($0) } ?? "—")
                        .typography(.caption, weight: .bold)
                        .foregroundStyle((change ?? 0) >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.10), in: Capsule())
                }

            Chart(Array(series.points.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Close", point.close)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                .lineStyle(.init(lineWidth: 3))

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Close", point.close)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.tint(for: colorScheme).opacity(0.22),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(height: 260)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
        }
    }
}
struct StockAnalysisTab: View {
    let details: StockResponse?
    let profile: StockComparisonProfile?
    let analysisMetrics: StockAnalysisMetrics?
    let analysisMetricsMessage: String?
    let valuation: StockValuationRequest?
    let onEditAnalysis: () -> Void
    let onEditDCF: () -> Void
    let onApplyDCFToValuation: (_ bearPrice: Double, _ basePrice: Double, _ bullPrice: Double) -> Void

    private var resolvedProfile: StockComparisonProfile? {
        if let profile {
            return profile
        }

        guard let analysisMetrics else { return nil }
        return StockComparisonProfile(
            symbol: analysisMetrics.symbol.uppercased(),
            companyName: analysisMetrics.symbol.uppercased(),
            currentPrice: analysisMetrics.currentPrice ?? 0,
            marketCap: analysisMetrics.marketCap ?? 0,
            sharesOutstanding: analysisMetrics.sharesOutstanding ?? 0,
            metrics: analysisMetrics.comparisonMetrics,
            projectionScenarios: [:],
            dcfBasePrice: analysisMetrics.dcfBasePrice,
            dcfBearPrice: analysisMetrics.dcfBearPrice,
            dcfBullPrice: analysisMetrics.dcfBullPrice
        )
    }

    var body: some View {
        LazyVStack(spacing: 16) {
            if let resolvedProfile, analysisMetrics != nil {
                if let intrinsicValue = resolvedProfile.dcfBasePrice ?? resolvedProfile.metrics[.dcfFairValue] {
                    SharePriceIntrinsicValueCard(
                        currentPrice: resolvedProfile.currentPrice,
                        intrinsicValue: intrinsicValue,
                        bearValue: resolvedProfile.dcfBearPrice,
                        bullValue: resolvedProfile.dcfBullPrice,
                        onEdit: onEditDCF,
                        onApplyToValuation: dcfApplyAction(
                            bearPrice: resolvedProfile.dcfBearPrice,
                            basePrice: intrinsicValue,
                            bullPrice: resolvedProfile.dcfBullPrice
                        )
                    )
                }

                StockCurrentMetricsCard(profile: resolvedProfile)
                StockFundamentalsCard(profile: resolvedProfile)
            } else {
                StockAnalysisPlaceholderCard(
                    message: analysisMetricsMessage,
                    isWarning: analysisMetricsMessage != nil
                )
            }

            StockThesisCard(
                symbol: details?.symbol,
                details: details,
                analysis: details?.notes,
                valuationRationale: valuation?.rationale,
                canEdit: details != nil,
                onEdit: onEditAnalysis
            )
        }
    }

    private func dcfApplyAction(
        bearPrice: Double?,
        basePrice: Double?,
        bullPrice: Double?
    ) -> (() -> Void)? {
        guard let bearPrice, let basePrice, let bullPrice else { return nil }
        return {
            onApplyDCFToValuation(bearPrice, basePrice, bullPrice)
        }
    }
}

struct StockForecastTab: View {
    let profile: StockComparisonProfile?
    @Binding var selectedScenario: StockProjectionScenarioKind
    let onEditDCF: () -> Void
    let onApplyDCFToValuation: (_ bearPrice: Double, _ basePrice: Double, _ bullPrice: Double) -> Void

    private var scenario: StockProjectionScenario? {
        profile?.projectionScenarios[selectedScenario]
    }

    var body: some View {
        if let profile, let scenario {
            LazyVStack(spacing: 16) {
                ProjectionScenarioHeaderCard(
                    profile: profile,
                    scenario: scenario,
                    selectedScenario: $selectedScenario
                )

                ForecastGrowthChartCard(scenario: scenario)

                ProjectionHighlightsCard(
                    profile: profile,
                    scenario: scenario,
                    scenarioKind: selectedScenario
                )

                if let dcfBase = profile.dcfBasePrice,
                   let dcfBear = profile.dcfBearPrice,
                   let dcfBull = profile.dcfBullPrice {
                    DCFValuationCard(
                        basePrice: dcfBase,
                        bearPrice: dcfBear,
                        bullPrice: dcfBull,
                        currentPrice: profile.currentPrice,
                        onEdit: onEditDCF,
                        onApplyToValuation: {
                            onApplyDCFToValuation(dcfBear, dcfBase, dcfBull)
                        }
                    )
                }

                ProjectionTableCard(scenario: scenario)

                ProjectionRangeChartCard(scenario: scenario)
            }
        } else {
            GlassCard {
                Text("Projection data is unavailable for this symbol right now.")
                    .typography(.small)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct StockCompareTab: View {
    @ObservedObject var viewModel: StockDetailsViewModel

    @Environment(\.colorScheme) private var colorScheme

    private var primaryProfile: StockComparisonProfile? {
        viewModel.primaryComparisonProfile
    }

    private var peerOptions: [StockComparisonProfile] {
        viewModel.availablePeerProfiles
    }

    private var comparisonProfiles: [StockComparisonProfile] {
        viewModel.comparisonProfiles
    }

    var body: some View {
        if let primaryProfile {
            LazyVStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Peer comparison")
                            .typography(.small, weight: .semibold)

                        Text("Compare valuation, growth, and profitability side by side against two peers.")
                            .typography(.nano)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            ComparisonPeerPicker(
                                title: "Peer 1",
                                selectedSymbol: viewModel.selectedPeerSymbol(at: 0),
                                options: peerOptions
                            ) { symbol in
                                viewModel.updatePeerSymbol(symbol, slot: 0)
                            }

                            ComparisonPeerPicker(
                                title: "Peer 2",
                                selectedSymbol: viewModel.selectedPeerSymbol(at: 1),
                                options: peerOptions
                            ) { symbol in
                                viewModel.updatePeerSymbol(symbol, slot: 1)
                            }
                        }

                        HStack(spacing: 10) {
                            HeroMetricPill(
                                title: primaryProfile.symbol,
                                value: primaryProfile.currentPrice.currency,
                                tint: AppTheme.Colors.tint(for: colorScheme)
                            )

                            ForEach(viewModel.selectedPeerProfiles) { peer in
                                HeroMetricPill(
                                    title: peer.symbol,
                                    value: peer.currentPrice.currency,
                                    tint: AppTheme.Colors.secondaryTint(for: colorScheme)
                                )
                            }
                        }
                    }
                }

                PriceComparisonChartCard(
                    response: viewModel.comparisonChartResponse,
                    primarySymbol: primaryProfile.symbol,
                    selectedRange: viewModel.selectedComparisonChartRange,
                    isLoading: viewModel.isComparisonChartLoading,
                    errorMessage: viewModel.comparisonChartErrorMessage,
                    onSelectRange: viewModel.switchComparisonChartRange
                )

                ForEach(StockComparisonMetricGroup.allCases) { group in
                    ComparisonMetricTableCard(
                        group: group,
                        profiles: comparisonProfiles
                    )
                }
            }
        } else {
            GlassCard {
                Text("Comparison data will appear after the stock loads.")
                    .typography(.small)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct PriceComparisonChartCard: View {
    let response: PriceChartComparisonResponse?
    let primarySymbol: String
    let selectedRange: PriceChartRange
    let isLoading: Bool
    let errorMessage: String?
    let onSelectRange: (PriceChartRange) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private struct NormalizedChartPoint: Identifiable {
        let id = UUID()
        let symbol: String
        let date: String
        let percentChange: Double
    }

    private var normalizedData: [NormalizedChartPoint] {
        guard let response else { return [] }
        var result: [NormalizedChartPoint] = []
        for series in response.series {
            let symbol = series.symbol.uppercased()
            guard let firstPrice = series.points.first?.close, firstPrice > 0 else { continue }
            for point in series.points {
                let change = (point.close - firstPrice) / firstPrice
                result.append(NormalizedChartPoint(
                    symbol: symbol,
                    date: point.date,
                    percentChange: change
                ))
            }
        }
        return result
    }

    private var chartStyleScale: KeyValuePairs<String, Color> {
        let dict: KeyValuePairs<String, Color> = [
            primarySymbol.uppercased(): AppTheme.Colors.tint(for: colorScheme)
        ]
        
        // KeyValuePairs is a bit tedious to build dynamically in Swift.
        // Let's just use dictionary mapping in the chart instead.
        return dict
    }

    private func symbolColor(for symbol: String) -> Color {
        let normalized = symbol.uppercased()
        if normalized == primarySymbol.uppercased() {
            return AppTheme.Colors.tint(for: colorScheme)
        }
        
        let otherSymbols = Set((response?.series ?? []).map { $0.symbol.uppercased() })
            .filter { $0 != primarySymbol.uppercased() }
            .sorted()
            
        guard let index = otherSymbols.firstIndex(of: normalized) else {
            return .gray
        }
        
        let colors = [
            AppTheme.Colors.secondaryTint(for: colorScheme),
            AppTheme.Colors.warning,
            AppTheme.Colors.danger,
            AppTheme.Colors.success
        ]
        return colors[index % colors.count]
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Performance comparison")
                        .typography(.small, weight: .semibold)

                    Text("Compare relative price movement across the selected timeframe.")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PriceChartRange.allCases, id: \.rawValue) { range in
                            Button {
                                onSelectRange(range)
                            } label: {
                                Text(range.title)
                                    .typography(.caption, weight: .semibold)
                                    .foregroundStyle(range == selectedRange ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        range == selectedRange
                                            ? AppTheme.Colors.tint(for: colorScheme)
                                            : Color.secondary.opacity(0.10),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if isLoading && response == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if let errorMessage {
                    Text(errorMessage)
                        .typography(.small)
                        .foregroundStyle(AppTheme.Colors.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if !normalizedData.isEmpty {
                    Chart(normalizedData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Change", point.percentChange)
                        )
                        .foregroundStyle(symbolColor(for: point.symbol))
                        .lineStyle(.init(lineWidth: point.symbol == primarySymbol.uppercased() ? 3 : 2))
                        .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 260)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text(doubleValue, format: .percent.precision(.fractionLength(0)))
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4))
                    }
                } else {
                    Text("No comparison chart data is available.")
                        .typography(.small)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 32)
                }
            }
        }
    }
}

struct StockNewsTab: View {
    let news: [StockNews]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            if news.isEmpty {
                ResearchPlaceholderCard(
                    title: "No recent news",
                    bodyText: "Stay tuned for updates and market shifts."
                )
            } else {
                // 1. Featured Story (Text-only prominent card)
                if let first = news.first {
                    FeaturedNewsHero(news: first)
                }

                // 2. The Feed
                VStack(spacing: 16) {
                    ForEach(news.dropFirst(), id: \.url) { item in
                        NewsFeedRow(news: item)
                    }
                }
            }
        }
    }
}

private struct FeaturedNewsHero: View {
    let news: StockNews
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Link(destination: URL(string: news.url) ?? URL(string: "https://google.com")!) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(news.source?.uppercased() ?? "LATEST NEWS")
                        .typography(.nano, weight: .bold)
                        .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme))

                    Spacer()

                    Image(systemName: "newspaper.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.5))
                        .accessibilityLabel("News icon")
                }

                Text(news.title)
                    .typography(.label, weight: .bold)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                if let summary = news.summary, !summary.isEmpty {
                    Text(summary)
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }

                HStack {
                    Text(formatRelativeDate(news.date))
                        .typography(.nano)
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Read full article")
                            .typography(.nano, weight: .semibold)
                        Image(systemName: "arrow.up.right")
                            .typography(.nano, weight: .bold)
                            .accessibilityLabel("Open external link")
                    }
                    .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                }
                .padding(.top, 4)
            }
            .padding(20)
            .appGlassEffect(.rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private func formatRelativeDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else { return dateString }

        let now = Date()
        let diff = now.timeIntervalSince(date)

        if diff < 60 {
            return "Just now"
        } else if diff < 3600 {
            return "\(Int(diff / 60))m ago"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))h ago"
        } else {
            let days = Int(diff / 86400)
            return "\(days)d ago"
        }
    }
}

private struct NewsFeedRow: View {
    let news: StockNews
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Link(destination: URL(string: news.url) ?? URL(string: "https://google.com")!) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(news.source ?? "Source")
                            .typography(.nano, weight: .bold)
                            .foregroundStyle(.secondary)

                        Circle()
                            .fill(.secondary.opacity(0.5))
                            .frame(width: 3, height: 3)

                        Text(formatRelativeDate(news.date))
                            .typography(.nano)
                            .foregroundStyle(.secondary)
                    }

                    Text(news.title)
                        .typography(.small, weight: .semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let summary = news.summary, !summary.isEmpty {
                        Text(summary)
                            .typography(.nano)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                // Thumbnail
                AsyncImage(url: URL(string: news.imageURL ?? "")) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.Colors.tertiaryFill(for: colorScheme))
                        .overlay(Image(systemName: "photo").font(.caption).foregroundStyle(.secondary))
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(12)
            .appGlassEffect(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func formatRelativeDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else { return dateString }

        let now = Date()
        let diff = now.timeIntervalSince(date)

        if diff < 60 {
            return "Just now"
        } else if diff < 3600 {
            return "\(Int(diff / 60))m ago"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))h ago"
        } else {
            let days = Int(diff / 86400)
            return "\(days)d ago"
        }
    }
}

struct StockEarningsTab: View {
    let symbol: String
    let earnings: [EarningsEvent]
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            if isLoading && earnings.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if let errorMessage {
                ResearchPlaceholderCard(title: "Earnings error", bodyText: errorMessage)
            } else if earnings.isEmpty {
                ResearchPlaceholderCard(title: "No earnings data", bodyText: "No data found for \(symbol).")
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Earnings History")
                        .typography(.label, weight: .bold)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        EarningsTableHeader()

                        ForEach(Array(earnings.enumerated()), id: \.element.id) { index, event in
                            EarningsTableRow(
                                event: event,
                                isLast: index == earnings.count - 1
                            )
                        }
                    }
                    .appGlassEffect(.rect(cornerRadius: 24))
                }
            }
        }
    }
}

// MARK: - Components

private struct EarningsTableHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Date")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("EPS")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Revenue")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Surprise")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .typography(.nano, weight: .semibold)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
}

private struct EarningsTableRow: View {
    let event: EarningsEvent
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDisplayDate(event.date))
                        .typography(.caption, weight: .bold)
                    if event.hasTranscript == true {
                        Label("Transcript", systemImage: "text.page")
                            .typography(.nano, weight: .semibold)
                            .foregroundStyle(.secondary)
                            .labelStyle(.titleAndIcon)
                            .accessibilityLabel("Transcript available")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                EarningsMetricCell(
                    primary: formattedEPS(event.epsActual),
                    secondary: "Est \(formattedEPS(event.epsEstimated))"
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                EarningsMetricCell(
                    primary: formattedRevenue(event.revenueActual),
                    secondary: "Est \(formattedRevenue(event.revenueEstimated))"
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formattedSurprisePercent)
                        .typography(.caption, weight: .bold)
                        .foregroundStyle(statusColor)
                    Text(surpriseText)
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .padding(.horizontal, 20)
            }
        }
    }

    private var statusColor: Color {
        guard let surprisePercent = resolvedSurprisePercent else { return .secondary }
        return surprisePercent >= 0 ? .green : .red
    }

    private var surpriseText: String {
        guard let surprisePercent = resolvedSurprisePercent else { return "Reported" }
        return surprisePercent >= 0 ? "Beat" : "Miss"
    }

    private var formattedSurprisePercent: String {
        guard let surprisePercent = resolvedSurprisePercent else { return "—" }
        let formatted = abs(surprisePercent).formatted(.number.precision(.fractionLength(1)))
        return surprisePercent >= 0 ? "+\(formatted)%" : "-\(formatted)%"
    }

    private var resolvedSurprisePercent: Double? {
        if let surprisePercent = event.surprisePercent {
            return surprisePercent
        }
        guard let act = event.epsActual, let est = event.epsEstimated, est != 0 else { return nil }
        return ((act - est) / abs(est)) * 100
    }

    private func formatDisplayDate(_ rawDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: String(rawDate.prefix(10))) else { return rawDate }
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formattedEPS(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    private func formattedRevenue(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.notation(.compactName))
    }
}

private struct EarningsMetricCell: View {
    let primary: String
    let secondary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(primary)
                .typography(.caption, weight: .semibold)
            Text(secondary)
                .typography(.nano)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FinancialStatementsIntroCard: View {
    let symbol: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "building.columns")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Financial statements")
                            .typography(.small, weight: .semibold)

                        Text("Review balance sheet strength and cash generation for \(symbol) when statement data is available.")
                            .typography(.small)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct FinancialStatementPeriodPicker: View {
    @Binding var selectedPeriod: StockFinancialStatementPeriod
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var selectionNamespace

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Statement period")
                    .typography(.small, weight: .semibold)

                Text("Switch between single filings or grouped annual and quarterly views.")
                    .typography(.nano)
                    .foregroundStyle(.secondary)

                GlassEffectContainer(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(StockFinancialStatementPeriod.allCases) { period in
                                Button {
                                    withAnimation(.snappy(duration: 0.22)) {
                                        selectedPeriod = period
                                    }
                                } label: {
                                    Text(period.title)
                                        .typography(.caption, weight: .semibold)
                                        .foregroundStyle(selectedPeriod == period ? .primary : .secondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .glassEffect(
                                            selectedPeriod == period
                                                ? .regular.tint(AppTheme.Colors.tint(for: colorScheme)).interactive()
                                                : .regular.interactive(),
                                            in: .capsule
                                        )
                                        .glassEffectID(period.id, in: selectionNamespace)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct StockDetailTabBar: View {
    @Binding var selectedTab: StockDetailTab
    var isPro: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var selectionNamespace

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StockDetailTab.allCases) { tab in
                        Button {
                            withAnimation(.snappy(duration: 0.22)) {
                                selectedTab = tab
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(tab.title)
                                    .typography(.caption, weight: .semibold)
                                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                                if tab.isProOnly && !isPro {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .glassEffect(
                                selectedTab == tab
                                    ? .regular.tint(AppTheme.Colors.tint(for: colorScheme)).interactive()
                                    : .regular.interactive(),
                                in: .capsule
                            )
                            .glassEffectID(tab.id, in: selectionNamespace)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("stockDetail.tab.\(tab.rawValue)")
                    }
                }
                .padding(4)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stock detail sections")
    }
}

private struct FinancialStatementTableCard: View {
    let title: String
    let subtitle: String
    let statements: [StockFinancialStatement]
    let emptyText: String

    private var visibleEntries: [StockFinancialStatementEntry] {
        statements.first?.entries ?? []
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .typography(.small, weight: .semibold)

                    Text(subtitle)
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }

                if let latest = statements.first {
                    HStack(spacing: 8) {
                        StatementMetaPill(text: "Reported in \(latest.reportedCurrency)")
                        StatementMetaPill(text: "\(statements.count) filing\(statements.count == 1 ? "" : "s")")
                    }
                }

                if statements.isEmpty {
                    Text(emptyText)
                        .typography(.small)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(spacing: 0) {
                            FinancialStatementHeaderRow(statements: statements)
                            Divider()

                            ForEach(visibleEntries) { entry in
                                FinancialStatementMetricRow(
                                    entry: entry,
                                    statements: statements
                                )
                                Divider()
                            }
                        }
                        .frame(minWidth: financialStatementTableMinWidth(statementCount: statements.count), alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct StatementMetaPill: View {
    let text: String

    var body: some View {
        Text(text)
            .typography(.caption, weight: .semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08), in: Capsule())
    }
}

private struct FinancialStatementHeaderRow: View {
    let statements: [StockFinancialStatement]

    var body: some View {
        HStack(spacing: 0) {
            Text("Metric")
                .typography(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
                .frame(width: 190, alignment: .leading)

            ForEach(statements) { statement in
                VStack(alignment: .trailing, spacing: 2) {
                    Text(statement.displayColumnTitle)
                        .typography(.caption, weight: .semibold)
                        .foregroundStyle(.secondary)

                    Text(statement.formattedDate)
                        .typography(.nano)
                        .foregroundStyle(.secondary)

                    Text("Filed \(statement.formattedFilingDate)")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 146, alignment: .trailing)
                .padding(.vertical, 10)
            }
        }
    }
}

private struct FinancialStatementMetricRow: View {
    let entry: StockFinancialStatementEntry
    let statements: [StockFinancialStatement]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Text(entry.title)
                .typography(.nano, weight: .semibold)
                .foregroundStyle(.primary)
                .frame(width: 190, alignment: .leading)
                .padding(.vertical, 10)

            ForEach(Array(statements.enumerated()), id: \.element.id) { index, statement in
                Text(
                    statement.value(for: entry.id).map {
                        formattedFinancialStatementValue($0, currencyCode: statement.reportedCurrency)
                    } ?? "—"
                )
                .typography(.nano, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(width: 146, alignment: .trailing)
                .padding(.vertical, 10)
                .background(
                    index == 0
                        ? AppTheme.Colors.tint(for: colorScheme).opacity(0.08)
                        : Color.clear
                )
            }
        }
    }
}

private struct FinancialMetricTableCard: View {
    let title: String
    let subtitle: String
    let snapshots: [StockFinancialMetricSnapshot]
    let emptyText: String

    private var sortedSnapshots: [StockFinancialMetricSnapshot] {
        snapshots.sorted { $0.date > $1.date }
    }

    private var visibleEntries: [StockFinancialMetricEntry] {
        sortedSnapshots.first?.entries ?? []
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .typography(.small, weight: .semibold)

                    Text(subtitle)
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }

                if let latest = sortedSnapshots.first {
                    HStack(spacing: 8) {
                        if let reportedCurrency = latest.reportedCurrency, !reportedCurrency.isEmpty {
                            StatementMetaPill(text: "Reported in \(reportedCurrency)")
                        }
                        StatementMetaPill(text: "\(sortedSnapshots.count) snapshot\(sortedSnapshots.count == 1 ? "" : "s")")
                    }
                }

                if sortedSnapshots.isEmpty {
                    Text(emptyText)
                        .typography(.small)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(spacing: 0) {
                            FinancialMetricHeaderRow(snapshots: sortedSnapshots)
                            Divider()

                            ForEach(visibleEntries) { entry in
                                FinancialMetricRow(
                                    entry: entry,
                                    snapshots: sortedSnapshots
                                )
                                Divider()
                            }
                        }
                        .frame(minWidth: financialStatementTableMinWidth(statementCount: sortedSnapshots.count), alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct FinancialMetricHeaderRow: View {
    let snapshots: [StockFinancialMetricSnapshot]

    var body: some View {
        HStack(spacing: 0) {
            Text("Metric")
                .typography(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
                .frame(width: 190, alignment: .leading)

            ForEach(snapshots) { snapshot in
                VStack(alignment: .trailing, spacing: 2) {
                    Text(snapshot.displayColumnTitle)
                        .typography(.caption, weight: .semibold)
                        .foregroundStyle(.secondary)

                    Text(snapshot.formattedDate)
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 146, alignment: .trailing)
                .padding(.vertical, 10)
            }
        }
    }
}

private struct FinancialMetricRow: View {
    let entry: StockFinancialMetricEntry
    let snapshots: [StockFinancialMetricSnapshot]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Text(entry.title)
                .typography(.nano, weight: .semibold)
                .foregroundStyle(.primary)
                .frame(width: 190, alignment: .leading)
                .padding(.vertical, 10)

            ForEach(Array(snapshots.enumerated()), id: \.element.id) { index, snapshot in
                let valueText = snapshot.entries.first(where: { $0.id == entry.id }).map {
                    formattedFinancialMetricValue($0, currencyCode: snapshot.reportedCurrency)
                } ?? "—"

                Text(valueText)
                    .typography(.nano, weight: .semibold)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: 146, alignment: .trailing)
                    .padding(.vertical, 10)
                    .background(
                        index == 0
                            ? AppTheme.Colors.tint(for: colorScheme).opacity(0.08)
                            : Color.clear
                    )
            }
        }
    }
}

private struct HeroMetricPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .typography(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .typography(.small, weight: .semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ProjectionSummaryBlock: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .typography(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .typography(.headline, weight: .bold)

            Text(detail)
                .typography(.nano)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProjectionScenarioHeaderCard: View {
    let profile: StockComparisonProfile
    let scenario: StockProjectionScenario
    @Binding var selectedScenario: StockProjectionScenarioKind

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("5-year forecast")
                        .typography(.small, weight: .semibold)

                    Text("Review the operating path, valuation range, and expected return using a bear, base, or bull scenario.")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }

                Picker("Projection scenario", selection: $selectedScenario) {
                    ForEach(StockProjectionScenarioKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                Text(selectedScenario.subtitle)
                    .typography(.nano)
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 14) {
                    GridRow {
                        ProjectionSummaryBlock(
                            title: "Stock price",
                            value: profile.currentPrice.currency,
                            detail: "Current market price"
                        )
                        ProjectionSummaryBlock(
                            title: "Market cap",
                            value: StockMetricFormatter.compactCurrency(profile.marketCap),
                            detail: "Current size"
                        )
                    }

                    GridRow {
                        ProjectionSummaryBlock(
                            title: "Shares outstanding",
                            value: StockMetricFormatter.compactNumber(profile.sharesOutstanding),
                            detail: "Used to derive EPS"
                        )
                        ProjectionSummaryBlock(
                            title: "Terminal range",
                            value: projectionRangeText(for: scenario.years.last),
                            detail: "Latest forecast year"
                        )
                    }
                }
            }
        }
    }
}

private struct StockMarketSnapshotCard: View {
    let snapshot: StockMarketSnapshot

    private var sessionChange: Double {
        snapshot.resolvedChange
    }

    private var changeTint: Color {
        sessionChange >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger
    }

    private var timestampText: String {
        Date(timeIntervalSince1970: snapshot.timestamp)
            .formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Market snapshot")
                        .typography(.small, weight: .semibold)

                    Text("Live quote for \(snapshot.symbol) in \(snapshot.currency). Current price, session move, and today's range.")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(snapshot.currentPrice.currency)
                        .typography(.hero, weight: .bold)
                        .monospacedDigit()

                    Text(StockMetricFormatter.signedCurrencyText(sessionChange))
                        .typography(.small, weight: .semibold)
                        .monospacedDigit()
                        .foregroundStyle(changeTint)

                    Text(StockMetricFormatter.signedPercentText(snapshot.resolvedPercentChange ?? 0))
                        .typography(.small, weight: .semibold)
                        .foregroundStyle(changeTint)
                        .monospacedDigit()
                }

                StockSessionRangeBar(snapshot: snapshot, tint: changeTint)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        DetailItem(title: "Symbol", value: snapshot.symbol)
                        DetailItem(title: "Currency", value: snapshot.currency)
                    }

                    GridRow {
                        DetailItem(title: "Open", value: snapshot.open?.currency ?? "—")
                        DetailItem(title: "Prev close", value: snapshot.previousClose?.currency ?? "—")
                    }

                    GridRow {
                        DetailItem(title: "Day high", value: snapshot.high?.currency ?? "—")
                        DetailItem(title: "Day low", value: snapshot.low?.currency ?? "—")
                    }
                }

                Text("Updated \(timestampText)")
                    .typography(.nano)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StockSessionRangeBar: View {
    let snapshot: StockMarketSnapshot
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Day range")
                    .typography(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(snapshot.low?.currency ?? "—") - \(snapshot.high?.currency ?? "—")")
                    .typography(.caption, weight: .semibold)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                let markerX = proxy.size.width * snapshot.rangeProgress

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 10)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.25), tint.opacity(0.65)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(18, markerX), height: 10)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: Color.black.opacity(0.14), radius: 6, y: 2)
                        .overlay(
                            Circle()
                                .stroke(tint, lineWidth: 3)
                        )
                        .offset(x: min(max(0, markerX - 8), max(0, proxy.size.width - 16)))
                }
            }
            .frame(height: 18)

            HStack {
                Text("Low")
                    .typography(.nano)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Current")
                    .typography(.nano)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("High")
                    .typography(.nano)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StockBasicFinancialsCard: View {
    let financials: StockBasicFinancials

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Basic financials")
                        .typography(.small, weight: .semibold)

                    Text("Core valuation, profitability, balance-sheet, and 52-week context for \(financials.symbol).")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }

                if financials.overviewItems.isEmpty && financials.annualSeriesItems.isEmpty {
                    Text("No basic financial metrics are available for this stock right now.")
                        .typography(.small)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    if !financials.overviewItems.isEmpty {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(financials.overviewItems) { item in
                                BasicFinancialMetricTile(
                                    title: item.title,
                                    value: formattedBasicFinancialValue(
                                        item,
                                        currencyCode: financials.currencyCode
                                    ),
                                    detail: item.detail
                                )
                            }
                        }
                    }

                    if !financials.annualSeriesItems.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Latest annual series")
                                .typography(.caption, weight: .semibold)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(financials.annualSeriesItems) { item in
                                    BasicFinancialMetricTile(
                                        title: item.title,
                                        value: formattedBasicFinancialValue(
                                            item,
                                            currencyCode: financials.currencyCode
                                        ),
                                        detail: item.detail
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct StockConsensusCard: View {
    let consensus: StockAnalystConsensus

    @Environment(\.colorScheme) private var colorScheme

    private var totalRatingsText: String {
        "\(consensus.totalRatings)"
    }

    private var bullishShareText: String {
        StockMetricFormatter.percentText(consensus.bullishShare)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Consensus")
                        .typography(.small, weight: .semibold)

                    Text("Analyst recommendation mix for \(consensus.symbol), based on the wrapped grades-consensus market data endpoint.")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    HeroMetricPill(
                        title: "Consensus",
                        value: consensus.consensus,
                        tint: consensusTint(for: consensus.consensus, colorScheme: colorScheme)
                    )
                    HeroMetricPill(
                        title: "Ratings",
                        value: totalRatingsText,
                        tint: AppTheme.Colors.secondaryTint(for: colorScheme)
                    )
                    HeroMetricPill(
                        title: "Bullish",
                        value: bullishShareText,
                        tint: AppTheme.Colors.success
                    )
                }

                VStack(spacing: 12) {
                    ForEach(consensus.buckets) { bucket in
                        ConsensusDistributionRow(
                            title: bucket.kind.title,
                            count: bucket.count,
                            total: consensus.totalRatings,
                            tint: consensusBucketTint(for: bucket.kind, colorScheme: colorScheme)
                        )
                    }
                }
            }
        }
    }
}

private struct StockConsensusPlaceholderCard: View {
    let message: String?
    let isWarning: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                if isWarning {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.Colors.warning)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Consensus")
                                .typography(.small, weight: .semibold)

                            Text(message ?? "Analyst consensus is limited by the current market data coverage.")
                                .typography(.small)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    Text("Consensus")
                        .typography(.small, weight: .semibold)

                    Text("This section is ready for analyst recommendation trends once the wrapped endpoint is available.")
                        .typography(.small)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct ConsensusDistributionRow: View {
    let title: String
    let count: Int
    let total: Int
    let tint: Color

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .typography(.caption, weight: .semibold)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(count)")
                    .typography(.caption, weight: .semibold)
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                Text(StockMetricFormatter.percentText(progress))
                    .typography(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 10)

                    Capsule()
                        .fill(tint)
                        .frame(
                            width: count == 0 ? 0 : max(12, proxy.size.width * progress),
                            height: 10
                        )
                }
            }
            .frame(height: 10)
        }
    }
}

private struct StockBasicFinancialsPlaceholderCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Basic financials")
                    .typography(.small, weight: .semibold)

                Text("This section is ready for P/E, margins, current ratio, beta, 52-week range, and annual series once the wrapped endpoint is available.")
                    .typography(.small)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct BasicFinancialMetricTile: View {
    let title: String
    let value: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .typography(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .typography(.small, weight: .semibold)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .typography(.nano)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StockCurrentMetricsCard: View {
    let profile: StockComparisonProfile

    private var keyMetrics: [StockComparisonMetric] {
        [
            .ttmPE,
            .forwardPE,
            .twoYearForwardPE,
            .ttmEPSGrowth,
            .currentYearExpectedEPSGrowth,
            .nextYearEPSGrowth,
            .ttmRevenueGrowth,
            .currentYearExpectedRevenueGrowth,
            .nextYearRevenueGrowth,
            .grossMargin,
            .netMargin,
            .ttmPEGRatio
        ]
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current metrics")
                        .typography(.small, weight: .semibold)

                    Text("A current snapshot of valuation, growth, and profitability before moving into forecasts or peer comparison.")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(keyMetrics.enumerated()), id: \.element.id) { index, metric in
                    CurrentMetricRow(
                        title: metric.title,
                        value: StockMetricFormatter.formattedValue(for: metric, value: profile.metrics[metric]),
                        detail: metric.benchmarkText
                    )

                    if index < keyMetrics.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct StockAnalysisPlaceholderCard: View {
    let message: String?
    let isWarning: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                if isWarning {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.Colors.warning)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Current metrics")
                                .typography(.small, weight: .semibold)

                            Text(message ?? "Current metrics are limited by the current market data coverage.")
                                .typography(.small)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    Text("Current metrics")
                        .typography(.small, weight: .semibold)

                    Text("Current metrics are unavailable for this symbol right now.")
                        .typography(.small)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct StockFundamentalsCard: View {
    let profile: StockComparisonProfile

    private var sharePayload: StockSharePayload {
        StockSharePayloadFormatter.fundamentals(profile: profile)
    }

    private func sharePayload(for destination: StockShareDestination) -> StockSharePayload {
        StockSharePayloadFormatter.fundamentals(
            profile: profile,
            style: shareStyle(for: destination)
        )
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fundamentals")
                        .typography(.small, weight: .semibold)

                    Text("A compact read on growth and profitability powered by live market analysis data.")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        DetailItem(
                            title: "TTM Rev Growth",
                            value: StockMetricFormatter.formattedValue(for: .ttmRevenueGrowth, value: profile.metrics[.ttmRevenueGrowth])
                        )
                        DetailItem(
                            title: "Next Yr Rev Growth",
                            value: StockMetricFormatter.formattedValue(for: .nextYearRevenueGrowth, value: profile.metrics[.nextYearRevenueGrowth])
                        )
                    }

                    GridRow {
                        DetailItem(
                            title: "Gross Margin",
                            value: StockMetricFormatter.formattedValue(for: .grossMargin, value: profile.metrics[.grossMargin])
                        )
                        DetailItem(
                            title: "Net Margin",
                            value: StockMetricFormatter.formattedValue(for: .netMargin, value: profile.metrics[.netMargin])
                        )
                    }

                    GridRow {
                        DetailItem(
                            title: "TTM EPS Growth",
                            value: StockMetricFormatter.formattedValue(for: .ttmEPSGrowth, value: profile.metrics[.ttmEPSGrowth])
                        )
                        DetailItem(
                            title: "Next Yr EPS Growth",
                            value: StockMetricFormatter.formattedValue(for: .nextYearEPSGrowth, value: profile.metrics[.nextYearEPSGrowth])
                        )
                    }
                }

                StockChannelShareActions(
                    payload: sharePayload,
                    destinationPayload: sharePayload(for:)
                )
            }
        }
    }
}

private struct StockThesisCard: View {
    let symbol: String?
    let details: StockDetails?
    let analysis: String?
    let valuationRationale: String?
    let canEdit: Bool
    let onEdit: () -> Void

    private var normalizedAnalysis: String? {
        analysis?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private var normalizedValuationRationale: String? {
        valuationRationale?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private var thesisText: String {
        if let normalizedAnalysis {
            return normalizedAnalysis
        }

        if let normalizedValuationRationale {
            return normalizedValuationRationale
        }

        return "Add your thesis, key risks, and the signals that would make you add, trim, or exit the position."
    }

    private var supportingText: String {
        if normalizedAnalysis != nil {
            return "Your saved analysis for this position."
        }

        if normalizedValuationRationale != nil {
            return "Using the saved valuation rationale until you add position-specific analysis."
        }

        return "Capture your own view on the business, risks, and what would change your mind."
    }

    private var editLabel: String {
        normalizedAnalysis == nil && normalizedValuationRationale == nil ? "Add" : "Edit"
    }

    private var sharePayload: StockSharePayload? {
        guard let symbol, let text = normalizedAnalysis ?? normalizedValuationRationale else { return nil }
        return StockSharePayloadFormatter.thesis(
            symbol: symbol,
            thesis: text,
            details: details
        )
    }

    private func destinationSharePayload(for destination: StockShareDestination) -> StockSharePayload? {
        guard let symbol, let text = normalizedAnalysis ?? normalizedValuationRationale else { return nil }
        return StockSharePayloadFormatter.thesis(
            symbol: symbol,
            thesis: text,
            details: details,
            style: shareStyle(for: destination)
        )
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Analysis")
                            .typography(.small, weight: .semibold)

                        Text(supportingText)
                            .typography(.nano)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if canEdit {
                        Button(editLabel, action: onEdit)
                            .typography(.small, weight: .semibold)
                            .buttonStyle(.plain)
                    }
                }

                Text(thesisText)
                    .typography(.small)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let sharePayload {
                    StockChannelShareActions(
                        payload: sharePayload,
                        destinationPayload: { destination in
                            destinationSharePayload(for: destination) ?? sharePayload
                        }
                    )
                }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private struct CurrentMetricRow: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .typography(.nano, weight: .semibold)
                    .foregroundStyle(.primary)

                Text(detail)
                    .typography(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text(value)
                .typography(.small, weight: .semibold)
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }
}

private struct ProjectionHighlightsCard: View {
    let profile: StockComparisonProfile
    let scenario: StockProjectionScenario
    let scenarioKind: StockProjectionScenarioKind

    private var firstProjectedYear: StockProjectionYear? {
        scenario.years.dropFirst().first
    }

    private var terminalYear: StockProjectionYear? {
        scenario.years.last
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scenario highlights")
                            .typography(.small, weight: .semibold)

                        Text("A compact read on the near-term setup and the longer-term valuation path.")
                            .typography(.nano)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(scenarioKind.title)
                        .typography(.caption, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.10), in: Capsule())
                }

                HStack(spacing: 10) {
                    ProjectionHighlightTile(
                        title: firstProjectedYear.map { String($0.year) } ?? "Next year",
                        value: projectionRangeText(for: firstProjectedYear),
                        detail: firstProjectedYear.map {
                            "Rev growth \(StockMetricFormatter.percentText($0.revenueGrowth))"
                        } ?? "Awaiting data"
                    )

                    ProjectionHighlightTile(
                        title: terminalYear.map { String($0.year) } ?? "Terminal",
                        value: projectionRangeText(for: terminalYear),
                        detail: terminalYear.map {
                            upsideText(
                                currentPrice: profile.currentPrice,
                                projectedLow: $0.sharePriceLow,
                                projectedHigh: $0.sharePriceHigh
                            )
                        } ?? "Awaiting data"
                    )
                }

                HStack(spacing: 10) {
                    ProjectionHighlightTile(
                        title: "Terminal CAGR",
                        value: cagrRangeText(for: terminalYear),
                        detail: "Annualized return range"
                    )

                    ProjectionHighlightTile(
                        title: "Terminal margins",
                        value: terminalYear.map { StockMetricFormatter.percentText($0.netMargin) } ?? "—",
                        detail: terminalYear.map {
                            "PE \(StockMetricFormatter.multipleText($0.peLowEstimate)) to \(StockMetricFormatter.multipleText($0.peHighEstimate))"
                        } ?? "Awaiting data"
                    )
                }
            }
        }
    }
}

private struct ProjectionHighlightTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .typography(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .typography(.small, weight: .semibold)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .typography(.nano)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ForecastGrowthChartCard: View {
    let scenario: StockProjectionScenario

    @Environment(\.colorScheme) private var colorScheme

    private var terminalYear: StockProjectionYear? {
        scenario.years.last
    }

    private var usesFreeCashFlow: Bool {
        scenario.years.contains { $0.freeCashFlow != nil }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Earnings & revenue growth forecasts")
                        .typography(.small, weight: .semibold)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                    Text("Indexed forecast path for revenue, earnings, and \(usesFreeCashFlow ? "free cash flow" : "estimated EBITDA") in the selected scenario.")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    ForecastMetricSummaryTile(
                        title: terminalYear.map { "\($0.year) revenue" } ?? "Revenue",
                        value: terminalYear.map { StockMetricFormatter.compactCurrency($0.revenue) } ?? "Pending",
                        color: AppTheme.Colors.tint(for: colorScheme)
                    )

                    ForecastMetricSummaryTile(
                        title: terminalYear.map { "\($0.year) earnings" } ?? "Earnings",
                        value: terminalYear.map { StockMetricFormatter.compactCurrency($0.netIncome) } ?? "Pending",
                        color: AppTheme.Colors.secondaryTint(for: colorScheme)
                    )

                    ForecastMetricSummaryTile(
                        title: terminalYear.map { "\($0.year) \(cashFlowTitle)" } ?? cashFlowTitle,
                        value: terminalYear.map { StockMetricFormatter.compactCurrency(cashFlowValue(for: $0)) } ?? "Pending",
                        color: AppTheme.Colors.warning
                    )
                }

                Chart {
                    ForEach(ForecastGrowthSeries.allCases) { series in
                        ForEach(points(for: series)) { point in
                            LineMark(
                                x: .value("Year", point.year),
                                y: .value("Indexed value", point.indexedValue)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(series.color(colorScheme: colorScheme))
                            .lineStyle(.init(lineWidth: 3))

                            PointMark(
                                x: .value("Year", point.year),
                                y: .value("Indexed value", point.indexedValue)
                            )
                            .foregroundStyle(series.color(colorScheme: colorScheme))
                        }
                    }
                }
                .frame(height: 230)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }

                HStack(spacing: 8) {
                    ForEach(ForecastGrowthSeries.allCases) { series in
                        ForecastLegendChip(
                            title: series.title(cashFlowTitle: cashFlowTitle),
                            color: series.color(colorScheme: colorScheme)
                        )
                    }
                }
            }
        }
    }

    private var cashFlowTitle: String {
        usesFreeCashFlow ? "FCF" : "EBITDA est."
    }

    private func points(for series: ForecastGrowthSeries) -> [ForecastGrowthPoint] {
        let values = scenario.years.map { year in
            switch series {
            case .revenue:
                return year.revenue
            case .earnings:
                return year.netIncome
            case .cashFlow:
                return cashFlowValue(for: year)
            }
        }

        guard let baseValue = values.first, baseValue > 0 else { return [] }

        return zip(scenario.years, values).map { year, value in
            ForecastGrowthPoint(
                series: series,
                year: year.year,
                indexedValue: (value / baseValue) * 100
            )
        }
    }

    private func cashFlowValue(for year: StockProjectionYear) -> Double {
        if let freeCashFlow = year.freeCashFlow {
            return freeCashFlow
        }

        let estimatedMargin = min(max(year.netMargin + 0.10, 0.12), 0.42)
        return year.revenue * estimatedMargin
    }
}

private struct ForecastMetricSummaryTile: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .typography(.nano)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .typography(.caption, weight: .bold)
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ForecastLegendChip: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .typography(.nano, weight: .semibold)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08), in: Capsule())
    }
}

private enum ForecastGrowthSeries: String, CaseIterable, Identifiable {
    case revenue
    case earnings
    case cashFlow

    var id: String { rawValue }

    func title(cashFlowTitle: String) -> String {
        switch self {
        case .revenue:
            return "Revenue"
        case .earnings:
            return "Earnings"
        case .cashFlow:
            return cashFlowTitle
        }
    }

    func color(colorScheme: ColorScheme) -> Color {
        switch self {
        case .revenue:
            return AppTheme.Colors.tint(for: colorScheme)
        case .earnings:
            return AppTheme.Colors.secondaryTint(for: colorScheme)
        case .cashFlow:
            return AppTheme.Colors.warning
        }
    }
}

private struct ForecastGrowthPoint: Identifiable {
    let series: ForecastGrowthSeries
    let year: Int
    let indexedValue: Double

    var id: String {
        "\(series.rawValue)-\(year)"
    }
}

private struct ProjectionRangeChartCard: View {
    let scenario: StockProjectionScenario

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Projected share-price range")
                    .typography(.small, weight: .semibold)

                Text("The band shows the low and high valuation outputs for each year in the selected scenario.")
                    .typography(.nano)
                    .foregroundStyle(.secondary)

                Chart(scenario.years) { point in
                    AreaMark(
                        x: .value("Year", point.year),
                        yStart: .value("Low", point.sharePriceLow),
                        yEnd: .value("High", point.sharePriceHigh)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.secondaryTint(for: colorScheme).opacity(0.20),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Year", point.year),
                        y: .value("Low", point.sharePriceLow)
                    )
                    .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                    .lineStyle(.init(lineWidth: 2.5))

                    LineMark(
                        x: .value("Year", point.year),
                        y: .value("High", point.sharePriceHigh)
                    )
                    .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme))
                    .lineStyle(.init(lineWidth: 2.5))
                }
                .frame(height: 240)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
    }
}

private struct StockValuationSummaryCard: View {
    let symbol: String?
    let currentPrice: Double?
    let valuation: StockValuationRequest?
    let onEditValuation: () -> Void

    private var sharePayload: StockSharePayload? {
        guard let symbol, let valuation else { return nil }
        return StockSharePayloadFormatter.priceTargets(
            symbol: symbol,
            valuation: valuation,
            currentPrice: currentPrice
        )
    }

    private func destinationSharePayload(for destination: StockShareDestination) -> StockSharePayload? {
        guard let symbol, let valuation else { return nil }
        return StockSharePayloadFormatter.priceTargets(
            symbol: symbol,
            valuation: valuation,
            currentPrice: currentPrice,
            style: shareStyle(for: destination)
        )
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Valuation")
                        .typography(.small, weight: .semibold)

                    Spacer()

                    Button("Edit", action: onEditValuation)
                        .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 10) {
                    ValuationCaseTile(title: "Bear", range: valuation?.bearCase)
                    ValuationCaseTile(title: "Base", range: valuation?.baseCase)
                    ValuationCaseTile(title: "Bull", range: valuation?.bullCase)
                }

                if let targetDate = valuation?.targetDate, !targetDate.isEmpty {
                    Text("Target date \(targetDate)")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }

                if let rationale = valuation?.rationale, !rationale.isEmpty {
                    Text(rationale)
                        .typography(.small)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let sharePayload {
                    StockChannelShareActions(
                        payload: sharePayload,
                        destinationPayload: { destination in
                            destinationSharePayload(for: destination) ?? sharePayload
                        }
                    )
                }
            }
        }
    }
}

private func shareStyle(for destination: StockShareDestination) -> StockShareTextStyle {
    switch destination {
    case .x:
        .x
    case .discord:
        .discord
    }
}

private struct ValuationCaseTile: View {
    let title: String
    let range: PriceRange?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .typography(.caption, weight: .semibold)
                .foregroundStyle(.secondary)

            Text(range.map { "\($0.low.currency) - \($0.high.currency)" } ?? "Not set")
                .typography(.nano, weight: .semibold)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StockPositionOverviewCard: View {
    let details: StockDetails
    let onEditPosition: () -> Void
    let onSellPosition: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var costBasis: Double {
        details.shares * details.buyPrice
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Position details")
                        .typography(.small, weight: .semibold)
                    Spacer()
                    HStack(spacing: 10) {
                        Button("Sell", action: onSellPosition)
                            .typography(.small, weight: .semibold)
                            .foregroundStyle(.orange)
                        Button("Edit", action: onEditPosition)
                            .typography(.small, weight: .semibold)
                            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        DetailItem(title: "Symbol", value: details.symbol)
                        DetailItem(
                            title: "Shares",
                            value: details.shares.formatted(.number.precision(.fractionLength(0...2)))
                        )
                    }

                    GridRow {
                        DetailItem(title: "Buy price", value: details.buyPrice.currency)
                        DetailItem(title: "Cost basis", value: costBasis.currency)
                    }

                    GridRow {
                        DetailItem(title: "Buy date", value: details.buyDate)
                        DetailItem(title: "Notes", value: details.notes?.isEmpty == false ? "Added" : "None")
                    }
                }

                if let notes = details.notes, !notes.isEmpty {
                    Text(notes)
                        .typography(.small)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct DetailItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .typography(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .typography(.small, weight: .semibold)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StockCompanyAvatarView: View {
    let companyProfile: CompanyProfileResponse?
    let fallbackText: String
    let colorScheme: ColorScheme

    private var logoURL: URL? {
        guard let logo = companyProfile?.logo?.trimmingCharacters(in: .whitespacesAndNewlines), !logo.isEmpty else {
            return nil
        }
        return URL(string: logo)
    }

    private var placeholderText: String {
        String(fallbackText.prefix(1)).uppercased()
    }

    var body: some View {
        ZStack {
            if let logoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppTheme.Colors.pageBackground(for: colorScheme), lineWidth: 2)
        )
    }

    private var placeholder: some View {
        LinearGradient(
            colors: AppTheme.avatarGradient(for: colorScheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(placeholderText)
                .typography(.small, weight: .bold)
                .foregroundStyle(.white)
        )
    }
}

private struct CompanyProfileWebsiteItem: View {
    let companyProfile: CompanyProfileResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Website")
                .typography(.caption)
                .foregroundStyle(.secondary)

            if let websiteURL = companyProfile.websiteURL, let weburl = companyProfile.weburl {
                Link(destination: websiteURL) {
                    Text(weburl)
                        .typography(.small, weight: .semibold)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                Text("—")
                    .typography(.small, weight: .semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StockHistoryCard: View {
    let history: [StockHistory]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Price history")
                    .typography(.small, weight: .semibold)

                if history.isEmpty {
                    Text("No price history available yet.")
                        .typography(.small)
                        .foregroundStyle(.secondary)
                } else {
                    Chart(Array(history.prefix(10).enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Close", point.close)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                        .lineStyle(.init(lineWidth: 3))
                    }
                    .frame(height: 180)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }

                    ForEach(Array(history.prefix(4).enumerated()), id: \.offset) { _, point in
                        HStack {
                            Text(point.date)
                                .typography(.nano)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(point.close.currency)
                                .typography(.small, weight: .semibold)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }
}

private struct StockNewsCard: View {
    let news: [StockNews]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recent news")
                    .typography(.small, weight: .semibold)

                if news.isEmpty {
                    Text("No recent news available yet.")
                        .typography(.small)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(news.prefix(6).enumerated()), id: \.offset) { _, item in
                        if let url = URL(string: item.url) {
                            Link(destination: url) {
                                NewsRow(item: item)
                            }
                        } else {
                            NewsRow(item: item)
                        }
                    }
                }
            }
        }
    }
}

private struct NewsRow: View {
    let item: StockNews

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .typography(.small, weight: .semibold)
                .foregroundStyle(.primary)

            Text(item.date)
                .typography(.nano)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SharePriceIntrinsicValueCard: View {
    let currentPrice: Double
    let intrinsicValue: Double
    let bearValue: Double?
    let bullValue: Double?
    var onEdit: (() -> Void)? = nil
    var onApplyToValuation: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var upside: Double? {
        guard currentPrice > 0 else { return nil }
        return (intrinsicValue - currentPrice) / currentPrice
    }

    private var valuationTitle: String {
        guard let upside else { return "Valuation pending" }
        if upside > 0.20 {
            return "Undervalued"
        } else if upside < -0.20 {
            return "Overvalued"
        }
        return "About right"
    }

    private var valuationColor: Color {
        guard let upside else { return .secondary }
        if upside > 0.20 {
            return AppTheme.Colors.success
        } else if upside < -0.20 {
            return AppTheme.Colors.danger
        }
        return AppTheme.Colors.warning
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Share price vs intrinsic value (DCF)")
                            .typography(.small, weight: .semibold)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(upside.map { StockMetricFormatter.signedPercentText($0) } ?? "Pending")
                                .typography(.title, weight: .bold)
                                .foregroundStyle(valuationColor)

                            Text(valuationTitle)
                                .typography(.caption, weight: .semibold)
                                .foregroundStyle(valuationColor)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if let onApplyToValuation {
                            Button(action: onApplyToValuation) {
                                Text("Apply")
                                    .typography(.caption, weight: .semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                            .accessibilityLabel("Apply DCF values to valuation")
                        }

                        if let onEdit {
                            Button(action: onEdit) {
                                Text("Edit")
                                    .typography(.caption, weight: .semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }

                IntrinsicValueRangeBar(
                    currentPrice: currentPrice,
                    intrinsicValue: intrinsicValue,
                    bearValue: bearValue,
                    bullValue: bullValue
                )

                HStack(spacing: 10) {
                    IntrinsicValueTile(
                        title: "Current price",
                        value: currentPrice.currency,
                        color: AppTheme.Colors.tint(for: colorScheme)
                    )

                    IntrinsicValueTile(
                        title: "DCF fair value",
                        value: intrinsicValue.currency,
                        color: valuationColor
                    )
                }

                if let bearValue, let bullValue {
                    Text("DCF scenario range: \(bearValue.currency) bear case to \(bullValue.currency) bull case.")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct IntrinsicValueRangeBar: View {
    let currentPrice: Double
    let intrinsicValue: Double
    let bearValue: Double?
    let bullValue: Double?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                if let bearValue = bearValue, let bullValue = bullValue {
                    BarMark(
                        xStart: .value("Bear Scenario", bearValue),
                        xEnd: .value("Bull Scenario", bullValue),
                        y: .value("Series", "Valuation")
                    )
                    .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme).opacity(0.15))
                    .cornerRadius(4)
                }

                PointMark(
                    x: .value("Intrinsic Value", intrinsicValue),
                    y: .value("Series", "Valuation")
                )
                .foregroundStyle(Color.primary)
                .symbol(.diamond)
                .symbolSize(120)
                .annotation(position: .top, alignment: .center) {
                    Text("DCF")
                        .typography(.nano, weight: .bold)
                        .foregroundStyle(.primary)
                }

                PointMark(
                    x: .value("Current Price", currentPrice),
                    y: .value("Series", "Valuation")
                )
                .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                .symbol(.circle)
                .symbolSize(120)
                .annotation(position: .bottom, alignment: .center) {
                    Text("Price")
                        .typography(.nano, weight: .bold)
                        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                }
            }
            .frame(height: 70)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(position: .bottom) {
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
    }
}

private struct IntrinsicValueTile: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .typography(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .typography(.label, weight: .bold)
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ProjectionTableCard: View {
    let scenario: StockProjectionScenario

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Scenario assumptions and outputs")
                        .typography(.small, weight: .semibold)

                    Text("Use the actual year as the base, then review how revenue, margins, EPS, valuation multiples, and price targets evolve across the forecast.")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ProjectionTableHeader(years: scenario.years)
                        Divider()

                        ForEach(projectionGroups) { group in
                            ProjectionTableGroupHeader(title: group.title)
                            Divider()

                            ForEach(group.rows) { row in
                                ProjectionTableRowView(row: row)
                                Divider()
                            }
                        }
                    }
                    .frame(minWidth: 720, alignment: .leading)
                }
            }
        }
    }

    private var projectionGroups: [ProjectionTableGroup] {
        [
            ProjectionTableGroup(
                title: "Operating assumptions",
                rows: [
                    ProjectionTableRow(title: "Revenue", values: scenario.years.map { StockMetricFormatter.compactCurrency($0.revenue) }),
                    ProjectionTableRow(title: "Rev Growth", values: scenario.years.map { StockMetricFormatter.percentText($0.revenueGrowth) }),
                    ProjectionTableRow(title: "Net Income", values: scenario.years.map { StockMetricFormatter.compactCurrency($0.netIncome) }),
                    ProjectionTableRow(title: "Net Inc. Growth", values: scenario.years.map { StockMetricFormatter.percentText($0.netIncomeGrowth) }),
                    ProjectionTableRow(title: "Net Margins", values: scenario.years.map { StockMetricFormatter.percentText($0.netMargin) }),
                    ProjectionTableRow(title: "EPS", values: scenario.years.map { $0.eps.currency }),
                    ProjectionTableRow(title: "PE Low Est", values: scenario.years.map { StockMetricFormatter.multipleText($0.peLowEstimate) }),
                    ProjectionTableRow(title: "PE High Est", values: scenario.years.map { StockMetricFormatter.multipleText($0.peHighEstimate) })
                ]
            ),
            ProjectionTableGroup(
                title: "Valuation outputs",
                rows: [
                    ProjectionTableRow(
                        title: "Share Price Low",
                        values: scenario.years.map { $0.sharePriceLow.currency },
                        isEmphasized: true
                    ),
                    ProjectionTableRow(
                        title: "Share Price High",
                        values: scenario.years.map { $0.sharePriceHigh.currency },
                        isEmphasized: true
                    ),
                    ProjectionTableRow(
                        title: "CAGR Low",
                        values: scenario.years.map { StockMetricFormatter.percentText($0.cagrLow) },
                        isEmphasized: true
                    ),
                    ProjectionTableRow(
                        title: "CAGR High",
                        values: scenario.years.map { StockMetricFormatter.percentText($0.cagrHigh) },
                        isEmphasized: true
                    )
                ]
            )
        ]
    }
}

private struct ProjectionTableHeader: View {
    let years: [StockProjectionYear]

    var body: some View {
        HStack(spacing: 0) {
            Text("Metric")
                .typography(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            ForEach(years) { year in
                Text(String(year.year))
                    .typography(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 114, alignment: .trailing)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct ProjectionTableGroupHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .typography(.caption, weight: .semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
    }
}

private struct ProjectionTableRowView: View {
    let row: ProjectionTableRow

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Text(row.title)
                .typography(.nano, weight: .semibold)
                .foregroundStyle(.primary)
                .frame(width: 150, alignment: .leading)

            ForEach(Array(row.values.enumerated()), id: \.offset) { index, value in
                Text(value)
                    .typography(.nano, weight: row.isEmphasized ? .semibold : .regular)
                    .foregroundStyle(.primary)
                    .frame(width: 114, alignment: .trailing)
                    .padding(.vertical, 10)
                    .background(
                        ProjectionValueCellBackground(
                            isActualYear: index == 0,
                            isEmphasized: row.isEmphasized,
                            colorScheme: colorScheme
                        )
                    )
            }
        }
    }
}

private struct ProjectionValueCellBackground: View {
    let isActualYear: Bool
    let isEmphasized: Bool
    let colorScheme: ColorScheme

    var body: some View {
        Group {
            if isActualYear {
                AppTheme.Colors.tertiaryFill(for: colorScheme)
            } else if isEmphasized {
                AppTheme.Colors.tintSoft(for: colorScheme).opacity(0.55)
            } else {
                Color.clear
            }
        }
    }
}

private struct ProjectionTableGroup: Identifiable {
    let id = UUID()
    let title: String
    let rows: [ProjectionTableRow]
}

private struct ProjectionTableRow: Identifiable {
    let id = UUID()
    let title: String
    let values: [String]
    var isEmphasized: Bool = false
}

private struct ComparisonPeerPicker: View {
    let title: String
    let selectedSymbol: String
    let options: [StockComparisonProfile]
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button(option.symbol) {
                    onSelect(option.symbol)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .typography(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(selectedSymbol.isEmpty ? "Select" : selectedSymbol)
                        .typography(.small, weight: .semibold)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ComparisonMetricTableCard: View {
    let group: StockComparisonMetricGroup
    let profiles: [StockComparisonProfile]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(group.title)
                    .typography(.small, weight: .semibold)

                if profiles.count < 3 {
                    Text("Choose two peers to unlock comparison metrics.")
                        .typography(.small)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ComparisonHeaderRow(profiles: profiles)
                            Divider()

                            ForEach(group.metrics) { metric in
                                ComparisonMetricRow(metric: metric, profiles: profiles)
                                Divider()
                            }
                        }
                        .frame(minWidth: 920, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct ComparisonHeaderRow: View {
    let profiles: [StockComparisonProfile]

    var body: some View {
        HStack(spacing: 0) {
            Text("Metric")
                .typography(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
                .frame(width: 190, alignment: .leading)

            ForEach(profiles) { profile in
                Text(profile.symbol)
                    .typography(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .trailing)
            }

            Text("Benchmark")
                .typography(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
                .frame(width: 300, alignment: .leading)
        }
        .padding(.vertical, 10)
    }
}

private struct ComparisonMetricRow: View {
    let metric: StockComparisonMetric
    let profiles: [StockComparisonProfile]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Text(metric.title)
                .typography(.nano, weight: .semibold)
                .foregroundStyle(.primary)
                .frame(width: 190, alignment: .leading)
                .padding(.vertical, 10)

            ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                Text(formattedMetricValue(metric, value: profile.metrics[metric]))
                    .typography(.nano, weight: .semibold)
                    .foregroundStyle(.primary)
                    .frame(width: 110, alignment: .trailing)
                    .padding(.vertical, 10)
                    .background(
                        index == 0
                            ? AppTheme.Colors.tint(for: colorScheme).opacity(0.08)
                            : Color.clear
                    )
            }

            Text(metric.benchmarkText)
                .typography(.nano)
                .foregroundStyle(.secondary)
                .frame(width: 300, alignment: .leading)
                .padding(.leading, 12)
        }
    }
}

private func formattedMetricValue(_ metric: StockComparisonMetric, value: Double?) -> String {
    StockMetricFormatter.formattedValue(for: metric, value: value)
}

private func projectionRangeText(for year: StockProjectionYear?) -> String {
    guard let year else { return "Pending" }
    return "\(year.sharePriceLow.currency) - \(year.sharePriceHigh.currency)"
}

struct DCFValuationCard: View {
    let basePrice: Double
    let bearPrice: Double
    let bullPrice: Double
    let currentPrice: Double
    var onEdit: (() -> Void)? = nil
    var onApplyToValuation: (() -> Void)? = nil

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Intrinsic valuation (DCF)")
                            .typography(.small, weight: .semibold)

                        Text("Discounted cash flow (DCF) fair value estimates based on the projected explicit cash flows and the Gordon Growth terminal value.")
                            .typography(.nano)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if let onApplyToValuation {
                            Button(action: onApplyToValuation) {
                                Text("Apply")
                                    .typography(.caption, weight: .semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                            .accessibilityLabel("Apply DCF values to valuation")
                        }

                        if let onEdit {
                            Button(action: onEdit) {
                                Text("Edit")
                                    .typography(.caption, weight: .semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    dcfBlock(title: "Bear case", value: bearPrice)
                    dcfBlock(title: "Base case", value: basePrice)
                    dcfBlock(title: "Bull case", value: bullPrice)
                }
            }
        }
    }

    private func dcfBlock(title: String, value: Double) -> some View {
        let isUpside = value > currentPrice
        let color: Color = isUpside ? .green : .red

        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .typography(.caption, weight: .semibold)
                .foregroundStyle(.secondary)

            Text(value.currency)
                .typography(.label, weight: .bold)

            HStack(spacing: 2) {
                Image(systemName: isUpside ? "arrow.up.right" : "arrow.down.right")
                Text(StockMetricFormatter.percentText((value - currentPrice) / currentPrice))
            }
            .typography(.caption, weight: .semibold)
            .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private func cagrRangeText(for year: StockProjectionYear?) -> String {
    guard let year else { return "—" }
    return "\(StockMetricFormatter.percentText(year.cagrLow)) to \(StockMetricFormatter.percentText(year.cagrHigh))"
}

private func upsideText(
    currentPrice: Double,
    projectedLow: Double,
    projectedHigh: Double
) -> String {
    guard currentPrice > 0 else { return "Awaiting data" }
    let lowUpside = (projectedLow / currentPrice) - 1
    let highUpside = (projectedHigh / currentPrice) - 1
    return "\(StockMetricFormatter.percentText(lowUpside)) to \(StockMetricFormatter.percentText(highUpside)) vs today"
}

private func consensusTint(for consensus: String, colorScheme: ColorScheme) -> Color {
    switch consensus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "strong buy":
        return AppTheme.Colors.success
    case "buy":
        return AppTheme.Colors.tint(for: colorScheme)
    case "hold":
        return AppTheme.Colors.warning
    case "sell", "strong sell":
        return AppTheme.Colors.danger
    default:
        return AppTheme.Colors.secondaryTint(for: colorScheme)
    }
}

private func consensusBucketTint(
    for kind: StockAnalystConsensusBucketKind,
    colorScheme: ColorScheme
) -> Color {
    switch kind {
    case .strongBuy:
        return AppTheme.Colors.success
    case .buy:
        return AppTheme.Colors.tint(for: colorScheme)
    case .hold:
        return AppTheme.Colors.warning
    case .sell:
        return Color.orange
    case .strongSell:
        return AppTheme.Colors.danger
    }
}

private func formattedBasicFinancialValue(
    _ item: StockBasicFinancialMetricItem,
    currencyCode: String?
) -> String {
    switch item.format {
    case .price:
        return StockMetricFormatter.currencyText(item.value, code: currencyCode)
    case .multiple:
        return StockMetricFormatter.multipleText(item.value)
    case .percentFraction:
        return StockMetricFormatter.percentText(item.value)
    case .percentPoints:
        return StockMetricFormatter.percentText(item.value / 100)
    case let .plain(decimals):
        return item.value.formatted(.number.precision(.fractionLength(decimals)))
    case .volume:
        return StockMetricFormatter.compactNumber(item.value)
    }
}

private func formattedFinancialStatementValue(_ value: Double, currencyCode: String?) -> String {
    StockMetricFormatter.compactStatementCurrency(value, code: currencyCode)
}

private func formattedFinancialMetricValue(
    _ entry: StockFinancialMetricEntry,
    currencyCode: String?
) -> String {
    guard let value = entry.value else { return "—" }

    switch entry.format {
    case .currencyCompact:
        return StockMetricFormatter.compactStatementCurrency(value, code: currencyCode)
    case let .currency(decimals):
        return StockMetricFormatter.currencyText(value, code: currencyCode, decimals: decimals)
    case let .multiple(decimals):
        return StockMetricFormatter.multipleText(value, decimals: decimals)
    case .percentFraction:
        return StockMetricFormatter.percentText(value)
    case let .plain(decimals):
        return value.formatted(.number.precision(.fractionLength(decimals)))
    case .count:
        return value.formatted(.number.precision(.fractionLength(0)))
    }
}

private func financialStatementTableMinWidth(statementCount: Int) -> CGFloat {
    CGFloat(190 + max(1, statementCount) * 146)
}

struct EditDCFSheet: View {
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("userWACC") private var userWACC: Double = 0.09
    @AppStorage("userTerminalGrowthRate") private var userTerminalGrowthRate: Double = 0.025
    @AppStorage("userTerminalMargin") private var userTerminalMargin: Double = 0.22
    @AppStorage("userFCFMarginAssumption") private var userFCFMarginAssumption: Double = 1.10

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Discount Rate")) {
                    VStack(alignment: .leading) {
                        Text("WACC (Weighted Average Cost of Capital)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Slider(value: $userWACC, in: 0.05...0.20, step: 0.005)
                            Text(userWACC, format: .percent.precision(.fractionLength(1)))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
                
                Section(header: Text("Terminal Value Assumptions")) {
                    VStack(alignment: .leading) {
                        Text("Terminal Growth Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Slider(value: $userTerminalGrowthRate, in: 0.01...0.05, step: 0.005)
                            Text(userTerminalGrowthRate, format: .percent.precision(.fractionLength(1)))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Terminal Margin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Slider(value: $userTerminalMargin, in: 0.05...0.50, step: 0.01)
                            Text(userTerminalMargin, format: .percent.precision(.fractionLength(0)))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
                
                Section(header: Text("Cash Flow Assumptions")) {
                    VStack(alignment: .leading) {
                        Text("FCF to Net Income Ratio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Slider(value: $userFCFMarginAssumption, in: 0.5...2.0, step: 0.05)
                            Text(userFCFMarginAssumption, format: .number.precision(.fractionLength(2)))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        userWACC = 0.09
                        userTerminalGrowthRate = 0.025
                        userTerminalMargin = 0.22
                        userFCFMarginAssumption = 1.10
                    }) {
                        Text("Reset to Defaults")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit DCF Parameters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
