import Charts
import SwiftUI

/// A grouped, scrubbable bar chart over a categorical (period) x-axis.
///
/// Supports any number of grouped series. Drag across the
/// chart to reveal a rule line and a value annotation for the selected period.
struct MetricBarChart: View {
    let points: [MetricSeriesPoint]
    let format: MetricValueFormat
    /// Optional explicit colors keyed by series name. Falls back to theme tints.
    var seriesColors: [String: Color] = [:]

    @State private var selectedLabel: String?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var seriesNames: [String] { points.orderedSeries }

    private func color(for series: String) -> Color {
        if let color = seriesColors[series] { return color }
        let palette: [Color] = [
            AppTheme.Colors.tint(for: colorScheme),
            AppTheme.Colors.secondaryTint(for: colorScheme),
            AppTheme.Colors.warning,
            AppTheme.Colors.success,
            .purple,
            .pink,
            AppTheme.Colors.danger
        ]
        guard let index = seriesNames.firstIndex(of: series) else { return palette[0] }
        return palette[index % palette.count]
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
                BarMark(
                    x: .value("Period", point.label),
                    y: .value("Value", point.value)
                )
                .position(by: .value("Series", point.series))
                .foregroundStyle(by: .value("Series", point.series))
                .accessibilityLabel("\(point.label), \(point.series)")
                .accessibilityValue(format.string(point.value))
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

/// Small floating label shown above the scrub rule line.
struct MetricChartSelectionLabel: View {
    let title: String
    let entries: [MetricChartSelectionEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .typography(.nano, weight: .semibold)
                .foregroundStyle(.secondary)

            ForEach(entries) { entry in
                HStack(spacing: 6) {
                    if !entry.series.isEmpty {
                        Circle()
                            .fill(entry.color)
                            .frame(width: 7, height: 7)
                    }
                    Text(entry.value)
                        .typography(.caption, weight: .bold)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
