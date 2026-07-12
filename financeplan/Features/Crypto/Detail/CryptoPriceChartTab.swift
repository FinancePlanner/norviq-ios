import Charts
import SwiftUI

struct CryptoPriceChartTab: View {
    let points: [CryptoChartPoint]
    let selectedRange: CryptoChartRange
    let isLoading: Bool
    let errorMessage: String?
    let onSelectRange: (CryptoChartRange) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var change: Double? {
        guard let first = points.first?.close, let last = points.last?.close, first > 0 else { return nil }
        return (last - first) / first
    }

    private var isPositive: Bool { (change ?? 0) >= 0 }

    private var lineColor: Color { isPositive ? .green : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            rangePicker

            if isLoading && points.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 64)
            } else if let errorMessage, points.isEmpty {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 48)
            } else if points.isEmpty {
                Text("No chart data available for this asset yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 48)
            } else {
                chart
            }
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(CryptoChartRange.allCases) { range in
                Button {
                    onSelectRange(range)
                } label: {
                    Text(range.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(range == selectedRange ? .white : .primary)
                        .frame(maxWidth: .infinity)
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

    private var chart: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Price", point.close)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(lineColor)
            .lineStyle(.init(lineWidth: 2.5))

            AreaMark(
                x: .value("Date", point.date),
                y: .value("Price", point.close)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [lineColor.opacity(0.25), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(height: 240)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4))
        }
    }
}
