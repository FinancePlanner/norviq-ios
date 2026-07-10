import Charts
import SwiftUI

/// A single- or multi-series, scrubbable line chart over a categorical
/// (period) x-axis. A gradient area fill is drawn when there is exactly one
/// series. Drag across the chart to reveal a value annotation per series.
struct MetricTrendChart: View {
    let points: [MetricSeriesPoint]
    let format: MetricValueFormat
    /// Optional explicit colors keyed by series name. Falls back to theme tints.
    var seriesColors: [String: Color] = [:]

    @State private var selectedLabel: String?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var seriesNames: [String] { points.orderedSeries }
    private var isSingleSeries: Bool { seriesNames.count <= 1 }

    private func color(for series: String) -> Color {
        if let color = seriesColors[series] { return color }
        let tints: [Color] = [
            AppTheme.Colors.tint(for: colorScheme),
            AppTheme.Colors.secondaryTint(for: colorScheme),
            AppTheme.Colors.warning,
            AppTheme.Colors.success,
            .purple,
            .pink,
            AppTheme.Colors.danger
        ]
        guard let index = seriesNames.firstIndex(of: series) else { return tints[0] }
        return tints[index % tints.count]
    }

    private var selectedEntries: [MetricChartSelectionEntry] {
        guard let selectedLabel else { return [] }
        return points
            .filter { $0.label == selectedLabel }
            .map { point in
                MetricChartSelectionEntry(
                    series: point.series,
                    color: color(for: point.series),
                    value: format.string(point.value)
                )
            }
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Period", point.label),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Series", point.series))
                .interpolationMethod(.catmullRom)
                .lineStyle(.init(lineWidth: 2.5))
                .accessibilityLabel("\(point.label), \(point.series)")
                .accessibilityValue(format.string(point.value))

                if isSingleSeries {
                    AreaMark(
                        x: .value("Period", point.label),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color(for: point.series).opacity(0.22), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }

            if let selectedLabel {
                RuleMark(x: .value("Period", selectedLabel))
                    .foregroundStyle(Color.secondary.opacity(0.25))
                    .annotation(
                        position: .top,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        MetricChartSelectionLabel(
                            title: selectedLabel,
                            entries: selectedEntries
                        )
                    }
            }
        }
        .chartForegroundStyleScale(
            domain: seriesNames,
            range: seriesNames.map { color(for: $0) }
        )
        .chartLegend(seriesNames.count > 1 ? .visible : .hidden)
        .chartXSelection(value: $selectedLabel)
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 240)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selectedLabel)
    }
}
