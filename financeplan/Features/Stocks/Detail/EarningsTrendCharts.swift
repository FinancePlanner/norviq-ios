import StockPlanShared
import SwiftUI

/// EPS and revenue trend charts (actual vs estimate) shown above the earnings
/// history table. Built entirely from the `[EarningsEvent]` the tab already has.
struct EarningsTrendCharts: View {
    let earnings: [EarningsEvent]

    private static let actualSeries = "Actual"
    private static let estimateSeries = "Estimate"

    /// Oldest-to-newest, capped to the most recent eight quarters for legibility.
    private var chronological: [EarningsEvent] {
        let sorted = earnings.sorted { $0.date < $1.date }
        return Array(sorted.suffix(8))
    }

    private var epsPoints: [MetricSeriesPoint] {
        chronological.flatMap { event -> [MetricSeriesPoint] in
            let label = quarterLabel(event.date)
            var points: [MetricSeriesPoint] = []
            if let actual = event.epsActual {
                points.append(MetricSeriesPoint(label: label, series: Self.actualSeries, value: actual))
            }
            if let estimate = event.epsEstimated {
                points.append(MetricSeriesPoint(label: label, series: Self.estimateSeries, value: estimate))
            }
            return points
        }
    }

    private var revenuePoints: [MetricSeriesPoint] {
        chronological.flatMap { event -> [MetricSeriesPoint] in
            let label = quarterLabel(event.date)
            var points: [MetricSeriesPoint] = []
            if let actual = event.revenueActual {
                points.append(MetricSeriesPoint(label: label, series: Self.actualSeries, value: actual))
            }
            if let estimate = event.revenueEstimated {
                points.append(MetricSeriesPoint(label: label, series: Self.estimateSeries, value: estimate))
            }
            return points
        }
    }

    var body: some View {
        if epsPoints.orderedLabels.count >= 2 || revenuePoints.orderedLabels.count >= 2 {
            VStack(spacing: 16) {
                if epsPoints.orderedLabels.count >= 2 {
                    ChartCard(
                        title: "EPS — actual vs estimate",
                        subtitle: "Quarterly reported earnings per share against analyst estimates."
                    ) {
                        MetricBarChart(points: epsPoints, format: .decimal(2))
                    }
                }

                if revenuePoints.orderedLabels.count >= 2 {
                    ChartCard(
                        title: "Revenue — actual vs estimate",
                        subtitle: "Quarterly reported revenue against analyst estimates."
                    ) {
                        MetricBarChart(points: revenuePoints, format: .currencyCompact)
                    }
                }
            }
        }
    }

    private func quarterLabel(_ rawDate: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: String(rawDate.prefix(10))) else {
            return String(rawDate.prefix(7))
        }
        let display = DateFormatter()
        display.dateFormat = "MMM ''yy"
        return display.string(from: date)
    }
}
