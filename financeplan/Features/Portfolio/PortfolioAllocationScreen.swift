import Charts
import ImageIO
import StockPlanShared
import SwiftUI
import UniformTypeIdentifiers
import SwiftData

@MainActor
struct PortfolioAllocationScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var viewModel: PortfolioViewModel

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
                        item: ShareURLBuilder.app(),
                        subject: Text(text.title),
                        message: Text(text.body),
                        preview: SharePreview(
                            text.title,
                            image: Image(systemName: "chart.pie.fill")
                        )
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
                        GlassCard(backgroundColor: .blue.opacity(0.12)) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("By cost basis")
                                    .typography(.small, weight: .semibold)
                                    .foregroundStyle(.secondary)

                                Text(totalValue.currency)
                                    .typography(.hero, weight: .bold)
                                    .contentTransition(.numericText())

                                Text(
                                    "\(allocationSlices.count) positions · percentages sum to how much each holding contributes to total value."
                                )
                                .typography(.nano)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        GlassCard {
                            VStack(spacing: 20) {
                                AllocationDonutChart(
                                    slices: allocationSlices,
                                    colorScheme: colorScheme
                                )
                                .frame(minHeight: 280)

                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(Array(allocationSlices.enumerated()), id: \.element.id) {
                                        index, slice in
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(AllocationPalette.color(at: index, colorScheme: colorScheme))
                                                .frame(width: 10, height: 10)

                                            Text(slice.symbol)
                                                .typography(.label, weight: .semibold)
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
                                }
                            }
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
