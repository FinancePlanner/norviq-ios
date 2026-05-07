import Charts
import StockPlanShared
import SwiftUI

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
