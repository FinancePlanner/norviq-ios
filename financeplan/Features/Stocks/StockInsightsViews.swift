import Charts
import StockPlanShared
import SwiftUI

struct StockDetailHeroCard: View {
    let details: StockDetails?
    let profile: StockComparisonProfile?

    @Environment(\.colorScheme) private var colorScheme

    private var positionMarketValue: Double? {
        guard let details, let profile else { return nil }
        return details.shares * profile.currentPrice
    }

    private var costBasis: Double? {
        guard let details else { return nil }
        return details.shares * details.buyPrice
    }

    var body: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile?.symbol ?? details?.symbol ?? "Stock")
                            .typography(.hero, weight: .bold)

                        Text(profile?.companyName ?? "Waiting for market data")
                            .typography(.small)
                            .foregroundStyle(.secondary)

                        if let details {
                            Text("Purchased \(details.buyDate) • \(details.shares.formatted(.number.precision(.fractionLength(0...2)))) shares")
                                .typography(.nano)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                        .padding(12)
                        .background(
                            AppTheme.Colors.tintSoft(for: colorScheme),
                            in: Circle()
                        )
                }

                HStack(spacing: 10) {
                    HeroMetricPill(
                        title: "Current price",
                        value: profile?.currentPrice.currency ?? "Pending",
                        tint: AppTheme.Colors.tint(for: colorScheme)
                    )
                    HeroMetricPill(
                        title: "Market cap",
                        value: profile.map { compactCurrency($0.marketCap) } ?? "Pending",
                        tint: AppTheme.Colors.secondaryTint(for: colorScheme)
                    )
                }

                HStack(spacing: 10) {
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
            }
        }
    }
}

struct StockOverviewTab: View {
    let details: StockDetails?
    let profile: StockComparisonProfile?
    let valuation: StockValuationRequest?
    let history: [StockHistory]
    let news: [StockNews]
    let errorMessage: String?
    let onEditValuation: () -> Void
    let onEditPosition: () -> Void

    var body: some View {
        LazyVStack(spacing: 16) {
            StockValuationSummaryCard(
                valuation: valuation,
                onEditValuation: onEditValuation
            )

            if let details {
                StockPositionOverviewCard(details: details, onEditPosition: onEditPosition)
            }

            if let profile {
                StockCurrentMetricsCard(profile: profile)
            }

            StockHistoryCard(history: history)
            StockNewsCard(news: news)

            ResearchPlaceholderCard(
                title: "Thesis",
                bodyText: "Use this section for the long-form why now, key risks, and what must happen for the position to work."
            )

            // to fill from endpoint later
            ResearchPlaceholderCard(
                title: "Earnings",
                bodyText: "Wire the future earnings API here for quarter dates, analyst estimates, and surprises versus expectations."
            )

            // to fill from endpoint later
            ResearchPlaceholderCard(
                title: "Fundamentals",
                bodyText: "Wire the fundamentals API here for balance sheet strength, cash generation, and capital allocation signals."
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

struct StockProjectionsTab: View {
    let profile: StockComparisonProfile?
    @Binding var selectedScenario: StockProjectionScenarioKind

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

                ProjectionHighlightsCard(
                    profile: profile,
                    scenario: scenario,
                    scenarioKind: selectedScenario
                )

                ProjectionTableCard(scenario: scenario)

                ProjectionRangeChartCard(scenario: scenario)
            }
        } else {
            GlassCard {
                Text("Projection data will appear after the stock loads.")
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

private struct HeroMetricPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .typography(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .typography(.small, weight: .semibold)
                .foregroundStyle(.primary)
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
                            value: compactCurrency(profile.marketCap),
                            detail: "Current size"
                        )
                    }

                    GridRow {
                        ProjectionSummaryBlock(
                            title: "Shares outstanding",
                            value: compactNumber(profile.sharesOutstanding),
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
            .ttmPEGRatio,
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
                        value: formattedMetricValue(metric, value: profile.metrics[metric]),
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
                            "Rev growth \(percentText($0.revenueGrowth))"
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
                        value: terminalYear.map { percentText($0.netMargin) } ?? "—",
                        detail: terminalYear.map {
                            "PE \(multipleText($0.peLowEstimate)) to \(multipleText($0.peHighEstimate))"
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
                                .clear,
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
    let valuation: StockValuationRequest?
    let onEditValuation: () -> Void

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
            }
        }
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
                    Button("Edit", action: onEditPosition)
                        .typography(.small, weight: .semibold)
                        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
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

private struct ResearchPlaceholderCard: View {
    let title: String
    let bodyText: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .typography(.small, weight: .semibold)

                Text(bodyText)
                    .typography(.small)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
                    ProjectionTableRow(title: "Revenue", values: scenario.years.map { compactCurrency($0.revenue) }),
                    ProjectionTableRow(title: "Rev Growth", values: scenario.years.map { percentText($0.revenueGrowth) }),
                    ProjectionTableRow(title: "Net Income", values: scenario.years.map { compactCurrency($0.netIncome) }),
                    ProjectionTableRow(title: "Net Inc. Growth", values: scenario.years.map { percentText($0.netIncomeGrowth) }),
                    ProjectionTableRow(title: "Net Margins", values: scenario.years.map { percentText($0.netMargin) }),
                    ProjectionTableRow(title: "EPS", values: scenario.years.map { $0.eps.currency }),
                    ProjectionTableRow(title: "PE Low Est", values: scenario.years.map { multipleText($0.peLowEstimate) }),
                    ProjectionTableRow(title: "PE High Est", values: scenario.years.map { multipleText($0.peHighEstimate) }),
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
                        values: scenario.years.map { percentText($0.cagrLow) },
                        isEmphasized: true
                    ),
                    ProjectionTableRow(
                        title: "CAGR High",
                        values: scenario.years.map { percentText($0.cagrHigh) },
                        isEmphasized: true
                    ),
                ]
            ),
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
    guard let value else { return "N/A" }

    switch metric.format {
    case .multiple:
        return multipleText(value)
    case .percent:
        return percentText(value)
    case .plain:
        return value.formatted(.number.precision(.fractionLength(2)))
    }
}

private func projectionRangeText(for year: StockProjectionYear?) -> String {
    guard let year else { return "Pending" }
    return "\(year.sharePriceLow.currency) - \(year.sharePriceHigh.currency)"
}

private func cagrRangeText(for year: StockProjectionYear?) -> String {
    guard let year else { return "—" }
    return "\(percentText(year.cagrLow)) to \(percentText(year.cagrHigh))"
}

private func upsideText(
    currentPrice: Double,
    projectedLow: Double,
    projectedHigh: Double
) -> String {
    guard currentPrice > 0 else { return "Awaiting data" }
    let lowUpside = (projectedLow / currentPrice) - 1
    let highUpside = (projectedHigh / currentPrice) - 1
    return "\(percentText(lowUpside)) to \(percentText(highUpside)) vs today"
}

private func compactCurrency(_ value: Double) -> String {
    let absolute = abs(value)
    switch absolute {
    case 1_000_000_000_000...:
        return String(format: "$%.2fT", value / 1_000_000_000_000)
    case 1_000_000_000...:
        return String(format: "$%.1fB", value / 1_000_000_000)
    case 1_000_000...:
        return String(format: "$%.1fM", value / 1_000_000)
    default:
        return value.currency
    }
}

private func compactNumber(_ value: Double) -> String {
    let absolute = abs(value)
    switch absolute {
    case 1_000_000_000...:
        return String(format: "%.2fB", value / 1_000_000_000)
    case 1_000_000...:
        return String(format: "%.1fM", value / 1_000_000)
    default:
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

private func percentText(_ value: Double?) -> String {
    guard let value else { return "—" }
    return value.formatted(.percent.precision(.fractionLength(1)))
}

private func multipleText(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1))) + "x"
}
