import StockPlanShared
import SwiftUI

struct ChartBuilderGrowthTableView: View {
  let response: ChartBuilderResponse

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Growth")
            .typography(.small, weight: .semibold)
          Text("Latest year-over-year change and full-window performance")
            .typography(.caption)
            .foregroundStyle(.secondary)
        }

        if growthSeriesIndices.isEmpty {
          ContentUnavailableView(
            "Growth unavailable",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("More reporting periods are needed to calculate growth.")
          )
        } else {
          ForEach(growthSeriesIndices, id: \.self) { index in
            let series = response.series[index]
            if let growth = series.growth {
              VStack(alignment: .leading, spacing: 12) {
                Text("\(series.symbol) · \(series.label)")
                  .typography(.small, weight: .semibold)

                LabeledContent(
                  "Latest YoY",
                  value: formattedChange(
                    absolute: growth.yoy.last?.absolute,
                    percent: growth.yoy.last?.percent,
                    series: series
                  )
                )

                LabeledContent(
                  "Total change",
                  value: formattedChange(
                    absolute: growth.totalChange,
                    percent: growth.totalChangePercent,
                    series: series
                  )
                )

                LabeledContent(
                  "CAGR",
                  value: growth.cagr.map { StockMetricFormatter.percentText($0) } ?? "—"
                )
              }

              if index != growthSeriesIndices.last {
                Divider()
              }
            }
          }
        }
      }
    }
  }

  private var growthSeriesIndices: [Int] {
    response.series.indices.filter { response.series[$0].growth != nil }
  }

  private func formattedChange(
    absolute: Double?,
    percent: Double?,
    series: ChartBuilderSeries
  ) -> String {
    let values = [
      absolute.map { formattedAbsolute($0, series: series) },
      percent.map { StockMetricFormatter.percentText($0) }
    ].compactMap { $0 }
    return values.isEmpty ? "—" : values.joined(separator: " · ")
  }

  private func formattedAbsolute(_ value: Double, series: ChartBuilderSeries) -> String {
    switch series.format {
    case .currency:
      StockMetricFormatter.compactStatementCurrency(value, code: series.currency)
    case .percent:
      StockMetricFormatter.percentText(value)
    case .ratio:
      StockMetricFormatter.multipleText(value, decimals: 2)
    case .perShare:
      value.formatted(.number.precision(.fractionLength(2)))
    case .shares:
      StockMetricFormatter.compactNumber(value)
    }
  }
}
