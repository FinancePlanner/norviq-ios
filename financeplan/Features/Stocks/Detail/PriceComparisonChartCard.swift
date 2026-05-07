import Charts
import StockPlanShared
import SwiftUI

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
