import Charts
import ImageIO
import StockPlanShared
import SwiftUI
import UniformTypeIdentifiers
import SwiftData

private enum PortfolioAllocationMode: String, CaseIterable, Identifiable {
    case positions
    case sectors
    case benchmark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .positions: return "Positions"
        case .sectors: return "Sectors"
        case .benchmark: return "S&P 500"
        }
    }

    var eyebrow: String {
        switch self {
        case .positions: return "By cost basis"
        case .sectors: return "Sector exposure"
        case .benchmark: return "Benchmark exposure"
        }
    }

    func summary(positionCount: Int, sectorCount: Int, benchmarkAsOf: String?) -> String {
        switch self {
        case .positions:
            return "\(positionCount) positions by total portfolio value."
        case .sectors:
            return "\(sectorCount) sectors by invested portfolio value."
        case .benchmark:
            return "Compared with S&P 500 sector weights\(benchmarkAsOf.map { " as of \($0)" } ?? "")."
        }
    }
}

typealias PortfolioAllocationShareFormatter = PortfolioAllocationScreen.PortfolioAllocationShareFormatter

@MainActor
struct PortfolioAllocationScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var viewModel: PortfolioViewModel
    @State private var selectedMode: PortfolioAllocationMode = .positions

    @Query private var stocks: [SDPortfolioStock]

    private var ownedStocks: [SDPortfolioStock] {
        let currentUserId = LocalCacheScope.currentOwnerUserId
        return stocks.filter { LocalCacheScope.isOwnedByCurrentUser($0.ownerUserId, currentUserId: currentUserId) }
    }

    private var scopedStocks: [SDPortfolioStock] {
        guard let selectedListId = viewModel.selectedPortfolioListId else {
            return ownedStocks
        }
        return ownedStocks.filter { ($0.portfolioListId ?? "") == selectedListId }
    }

    private var holdingsValue: Double {
        scopedStocks.reduce(0) { $0 + ($1.shares * $1.buyPrice) }
    }

    private var cashBalance: Double {
        viewModel.cashBalance
    }

    private var totalValue: Double {
        holdingsValue + cashBalance
    }

    /// Cost-basis weights by position value, largest first
    private var allocationSlices: [PortfolioAllocationSlice] {
        let total = totalValue
        guard total > 0 else { return [] }
        var slices = scopedStocks
            .map { stock in
                let value = stock.shares * stock.buyPrice
                return PortfolioAllocationSlice(
                    id: stock.id,
                    symbol: stock.symbol,
                    value: value,
                    percentage: (value / total) * 100
                )
            }
        if cashBalance > 0 {
            slices.append(
                PortfolioAllocationSlice(
                    id: "cash-position",
                    symbol: "CASH",
                    value: cashBalance,
                    percentage: (cashBalance / total) * 100
                )
            )
        }
        return slices.sorted { $0.value > $1.value }
    }

    private var sectorSlices: [PortfolioAllocationSlice] {
        guard let exposure = viewModel.sectorExposure else { return [] }
        return exposure.sectors.map {
            PortfolioAllocationSlice(
                id: $0.sector,
                symbol: $0.sector,
                value: $0.value,
                percentage: $0.weightPercent
            )
        }
    }

    private var displayedTotalValue: Double {
        switch selectedMode {
        case .positions, .benchmark:
            return totalValue
        case .sectors:
            return viewModel.sectorExposure?.investedValue ?? holdingsValue
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && scopedStocks.isEmpty {
                PortfolioAllocationSkeletonView()
                    .transition(.opacity)
            } else if let error = viewModel.errorMessage, scopedStocks.isEmpty {
                ContentUnavailableView {
                    Label("Unable to Load Portfolio", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.load(force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                allocationContent
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.3), value: viewModel.isLoading)
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
        .refreshable { await viewModel.load(force: true) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !allocationSlices.isEmpty {
                    let text = PortfolioAllocationShareFormatter.payload(
                        slices: allocationSlices,
                        totalValue: totalValue
                    )
                    ShareLink(
                        item: text.body,
                        subject: Text(text.title),
                        message: Text(text.body)
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share allocation")
                }
            }
        }
    }

    @ViewBuilder
    private var allocationContent: some View {
            if allocationSlices.isEmpty {
                ContentUnavailableView {
                    Label("No Allocation Yet", systemImage: "chart.pie.fill")
                } description: {
                    Text("Add holdings under Holdings to see how your portfolio is split by cost basis.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        Picker("Allocation view", selection: $selectedMode) {
                            ForEach(PortfolioAllocationMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        GlassCard(backgroundColor: .blue.opacity(0.12)) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(selectedMode.eyebrow)
                                    .typography(.small, weight: .semibold)
                                    .foregroundStyle(.secondary)

                                Text(displayedTotalValue.currency)
                                    .typography(.hero, weight: .bold)
                                    .contentTransition(.numericText())

                                Text(selectedMode.summary(
                                    positionCount: allocationSlices.count,
                                    sectorCount: viewModel.sectorExposure?.sectors.count ?? 0,
                                    benchmarkAsOf: viewModel.sectorExposure?.benchmarkAsOf
                                ))
                                .typography(.nano)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        switch selectedMode {
                        case .positions:
                            GlassCard {
                                allocationChartCard(slices: allocationSlices)
                            }
                        case .sectors:
                            sectorExposureCard
                        case .benchmark:
                            benchmarkComparisonCard
                        }

                        let sharePayload = PortfolioAllocationShareFormatter.payload(
                            slices: allocationSlices,
                            totalValue: totalValue
                        )
                        GlassCard {
                            StockChannelShareActions(payload: sharePayload) { destination in
                                PortfolioAllocationShareFormatter.payload(
                                    slices: allocationSlices,
                                    totalValue: totalValue,
                                    destination: destination
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }

    private func allocationChartCard(slices: [PortfolioAllocationSlice]) -> some View {
        VStack(spacing: 20) {
            AllocationDonutChart(
                slices: slices,
                colorScheme: colorScheme
            )
            .frame(minHeight: 280)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                    allocationLegendRow(index: index, slice: slice)
                }
            }
        }
    }

    private func allocationLegendRow(index: Int, slice: PortfolioAllocationSlice) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AllocationPalette.color(at: index, colorScheme: colorScheme))
                .frame(width: 10, height: 10)

            Text(slice.symbol)
                .typography(.label, weight: .semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(slice.percentage.formatted(.number.precision(.fractionLength(1))) + "%")
                .typography(.label, weight: .semibold)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())

            Text(slice.value.currency)
                .typography(.small)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }

    @ViewBuilder
    private var sectorExposureCard: some View {
        if let exposure = viewModel.sectorExposure, !exposure.sectors.isEmpty {
            GlassCard {
                VStack(spacing: 20) {
                    AllocationDonutChart(
                        slices: sectorSlices,
                        colorScheme: colorScheme
                    )
                    .frame(minHeight: 280)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(exposure.sectors.enumerated()), id: \.element.sector) { index, sector in
                            SectorExposureRow(
                                item: sector,
                                color: AllocationPalette.color(at: index, colorScheme: colorScheme)
                            )
                        }
                    }
                }
            }
        } else {
            ContentUnavailableView {
                Label("No Sector Data Yet", systemImage: "square.grid.2x2")
            } description: {
                Text("Sector exposure appears after portfolio symbols have company profile data.")
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        }
    }

    @ViewBuilder
    private var benchmarkComparisonCard: some View {
        if let exposure = viewModel.sectorExposure, !exposure.sectors.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(exposure.benchmarkName)
                            .typography(.label, weight: .semibold)
                        Spacer()
                        Text("As of \(exposure.benchmarkAsOf)")
                            .typography(.nano)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        ForEach(exposure.sectors) { sector in
                            BenchmarkSectorRow(item: sector)
                        }
                    }

                    if exposure.cashBalance > 0 {
                        Divider()
                        HStack {
                            Text("Cash")
                                .typography(.small, weight: .semibold)
                            Spacer()
                            Text(exposure.cashBalance.currency)
                                .typography(.small)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } else {
            ContentUnavailableView {
                Label("No Benchmark Data Yet", systemImage: "chart.bar.xaxis")
            } description: {
                Text("Benchmark comparison appears after sector exposure is available.")
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        }
    }

    private struct SectorExposureRow: View {
        let item: PortfolioSectorExposureItem
        let color: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)

                    Text(item.sector)
                        .typography(.label, weight: .semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(item.weightPercent.formatted(.number.precision(.fractionLength(1))) + "%")
                        .typography(.label, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Text(item.value.currency)
                        .typography(.small)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    ForEach(item.holdings) { holding in
                        HStack(spacing: 10) {
                            Text(holding.symbol)
                                .typography(.small, weight: .semibold)
                                .frame(width: 64, alignment: .leading)

                            Text(holding.weightPercent.formatted(.number.precision(.fractionLength(1))) + "%")
                                .typography(.nano)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()

                            Spacer()

                            Text(holding.value.currency)
                                .typography(.nano)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 22)
                    }
                }
            }
        }
    }

    private struct BenchmarkSectorRow: View {
        let item: PortfolioSectorExposureItem

        private var benchmarkWeight: Double {
            item.benchmarkWeightPercent ?? 0
        }

        private var overweight: Double {
            item.overweightPercent ?? 0
        }

        private var deltaColor: Color {
            overweight >= 0 ? .orange : .green
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(item.sector)
                        .typography(.small, weight: .semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer()

                    Text(deltaText)
                        .typography(.nano, weight: .semibold)
                        .foregroundStyle(deltaColor)
                        .monospacedDigit()
                }

                HStack(spacing: 10) {
                    benchmarkBar(value: item.weightPercent, color: AppTheme.Colors.tint(for: .light))
                    Text(item.weightPercent.formatted(.number.precision(.fractionLength(1))) + "%")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }

                HStack(spacing: 10) {
                    benchmarkBar(value: benchmarkWeight, color: .secondary.opacity(0.45))
                    Text(benchmarkWeight.formatted(.number.precision(.fractionLength(1))) + "%")
                        .typography(.nano)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            }
        }

        private var deltaText: String {
            guard item.benchmarkWeightPercent != nil else { return "No benchmark" }
            let sign = overweight >= 0 ? "+" : ""
            return "\(sign)\(overweight.formatted(.number.precision(.fractionLength(1)))) pts"
        }

        private func benchmarkBar(value: Double, color: Color) -> some View {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.12))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * min(max(value, 0), 100) / 100)
                }
            }
            .frame(height: 7)
        }
    }

    // MARK: - Chart

    private struct AllocationDonutChart: View {
        let slices: [PortfolioAllocationSlice]
        let colorScheme: ColorScheme

        @State private var animationProgress: Double = 0.0

        var body: some View {
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("Value", slice.value * animationProgress),
                    innerRadius: .ratio(0.56),
                    outerRadius: .ratio(1.0),
                    angularInset: 1.2
                )
                .foregroundStyle(by: .value("Symbol", slice.symbol))
            }
            .chartForegroundStyleScale(
                domain: slices.map(\.symbol),
                range: slices.indices.map { AllocationPalette.color(at: $0, colorScheme: colorScheme) }
            )
            .chartLegend(.hidden)
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                    animationProgress = 1.0
                }
            }
        }
    }

    private enum AllocationPalette {
        static func color(at index: Int, colorScheme: ColorScheme) -> Color {
            let palette: [Color] = [
                AppTheme.Colors.tint(for: colorScheme),
                AppTheme.Colors.secondaryTint(for: colorScheme),
                Color.indigo,
                Color.orange,
                Color.pink,
                Color.mint,
                Color.cyan,
                Color.purple
            ]
            return palette[index % palette.count]
        }
    }

    // MARK: - Formatter

    enum PortfolioAllocationShareFormatter {
        static func payload(
            slices: [PortfolioAllocationSlice],
            totalValue: Double?,
            destination: StockShareDestination? = nil,
            language: AppLanguage = .stored
        ) -> StockSharePayload {
            let limit = destination == .x ? 4 : 8
            let topSlices = slices.prefix(limit)
            let style: StockShareTextStyle = destination == .discord ? .discord : .native
            var lines: [String] = []
            let title: String

            switch language {
            case .english:
                title = "Portfolio allocation"
                lines.append(headline(title, style: style))
                if let totalValue {
                    lines.append(listLine("Total value: \(totalValue.currency)", style: style))
                }
                lines.append(contentsOf: topSlices.map {
                    listLine("\($0.symbol): \($0.percentage.formatted(.number.precision(.fractionLength(1))))% (\($0.value.currency))", style: style)
                })
                if slices.count > limit {
                    lines.append(listLine("+\(slices.count - limit) more positions", style: style))
                }
                lines.append("Not investment advice.")
            case .portuguesePortugal:
                title = "Alocação do portefólio"
                lines.append(headline(title, style: style))
                if let totalValue {
                    lines.append(listLine("Valor total: \(totalValue.currency)", style: style))
                }
                lines.append(contentsOf: topSlices.map {
                    listLine("\($0.symbol): \($0.percentage.formatted(.number.precision(.fractionLength(1))))% (\($0.value.currency))", style: style)
                })
                if slices.count > limit {
                    lines.append(listLine("+\(slices.count - limit) posições", style: style))
                }
                lines.append("Não é aconselhamento financeiro.")
            }

            let body = lines.joined(separator: "\n")
            if destination == .x, body.count > 280 {
                return StockSharePayload(title: title, body: String(body.prefix(277)) + "...")
            }
            return StockSharePayload(title: title, body: body)
        }

        private static func headline(_ text: String, style: StockShareTextStyle) -> String {
            style == .discord ? "**\(text)**" : text
        }

        private static func listLine(_ text: String, style: StockShareTextStyle) -> String {
            style == .discord ? "• \(text)" : text
        }
    }

    // MARK: - Skeleton View
    private struct PortfolioAllocationSkeletonView: View {
        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.gray.opacity(0.12))
                        .frame(minHeight: 110)
                        .shimmer()

                    GlassCard {
                        VStack(spacing: 20) {
                            Circle()
                                .stroke(.gray.opacity(0.12), lineWidth: 50)
                                .frame(minHeight: 200)
                                .padding()
                                .shimmer()

                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(0..<4, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(.gray.opacity(0.12))
                                        .frame(height: 20)
                                        .shimmer()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
}
