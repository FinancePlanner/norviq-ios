import SwiftUI

/// A single plottable point shared by the reusable metric charts.
///
/// `label` is the categorical x-axis value (e.g. "Q1 2024"), `series`
/// distinguishes lines/bars within one chart (e.g. "Actual" vs "Estimate"),
/// and `value` is the magnitude. Points are expected to arrive already
/// sorted in display order — charts render categories in first-seen order.
struct MetricSeriesPoint: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let series: String
    let value: Double

    init(label: String, series: String = "", value: Double) {
        self.label = label
        self.series = series
        self.value = value
    }
}

/// One row in a scrub-selection annotation: a series swatch + formatted value.
struct MetricChartSelectionEntry: Identifiable {
    let id = UUID()
    let series: String
    let color: Color
    let value: String
}

/// How a metric value is rendered in axis-free annotations and labels.
enum MetricValueFormat: Equatable {
    case currencyCompact   // 1.2M
    case decimal(Int)      // 3.14
    case percentFraction   // 0.23 -> 23%
    case multiple(Int)     // 12.3x

    func string(_ value: Double) -> String {
        switch self {
        case .currencyCompact:
            return value.formatted(.number.notation(.compactName))
        case let .decimal(digits):
            return value.formatted(.number.precision(.fractionLength(digits)))
        case .percentFraction:
            return value.formatted(.percent.precision(.fractionLength(1)))
        case let .multiple(digits):
            return value.formatted(.number.precision(.fractionLength(digits))) + "x"
        }
    }
}

extension Array where Element == MetricSeriesPoint {
    /// Unique series names in first-seen order.
    var orderedSeries: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for point in self where !seen.contains(point.series) {
            seen.insert(point.series)
            result.append(point.series)
        }
        return result
    }

    /// Unique x-axis labels in first-seen order.
    var orderedLabels: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for point in self where !seen.contains(point.label) {
            seen.insert(point.label)
            result.append(point.label)
        }
        return result
    }
}
