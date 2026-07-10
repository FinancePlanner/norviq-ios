import StockPlanShared
import SwiftUI

struct ChartBuilderChartView: View {
  let response: ChartBuilderResponse
  let chartType: ChartBuilderChartType
  let title: String

  var body: some View {
    ChartCard(
      title: title,
      subtitle: "\(response.periods.count) periods · aligned by fiscal year"
    ) {
      if points.isEmpty {
        ContentUnavailableView(
          "No chart data",
          systemImage: "chart.xyaxis.line",
          description: Text("The selected metrics have no values for this period.")
        )
      } else {
        switch chartType {
        case .bar:
          MetricBarChart(points: points, format: valueFormat)
        case .line:
          MetricTrendChart(points: points, format: valueFormat)
        }

        if hasMixedFormats {
          Text("Mixed units use \(primaryFormatLabel) formatting on the shared axis.")
            .typography(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var points: [MetricSeriesPoint] {
    var result: [MetricSeriesPoint] = []
    let usesQualifiedSeriesNames = response.companies.count > 1
      || Set(response.series.map(\.metricKey)).count > 1

    for (index, period) in response.periods.enumerated() {
      for series in response.series {
        guard series.values.indices.contains(index), let value = series.values[index] else { continue }
        let seriesName = usesQualifiedSeriesNames
          ? "\(series.symbol) · \(series.label)"
          : ""
        result.append(
          MetricSeriesPoint(label: period.label, series: seriesName, value: value)
        )
      }
    }
    return result
  }

  private var valueFormat: MetricValueFormat {
    switch response.series.first?.format {
    case .currency, .shares:
      .currencyCompact
    case .percent:
      .percentFraction
    case .ratio:
      .multiple(2)
    case .perShare:
      .decimal(2)
    case nil:
      .decimal(2)
    }
  }

  private var hasMixedFormats: Bool {
    Set(response.series.map { $0.format.rawValue }).count > 1
  }

  private var primaryFormatLabel: String {
    response.series.first?.label ?? "the first metric"
  }
}
