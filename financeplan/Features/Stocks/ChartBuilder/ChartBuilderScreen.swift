import StockPlanShared
import SwiftUI

struct ChartBuilderScreen: View {
  @StateObject private var viewModel: ChartBuilderViewModel

  init(symbol: String, companyName: String? = nil) {
    _viewModel = StateObject(
      wrappedValue: ChartBuilderViewModel(symbol: symbol, companyName: companyName)
    )
  }

  var body: some View {
    VStack(spacing: 16) {
      ChartBuilderControlsView(viewModel: viewModel)
      ChartBuilderMetricPickerView(viewModel: viewModel)

      HStack(spacing: 12) {
        Button("Build chart", systemImage: "hammer", action: buildChart)
          .buttonStyle(.borderedProminent)
          .frame(maxWidth: .infinity, minHeight: 44)
          .disabled(!viewModel.canBuild)
          .accessibilityIdentifier("chartBuilder.build")

        Button("Export CSV", systemImage: "square.and.arrow.down", action: exportCSV)
          .buttonStyle(.bordered)
          .frame(maxWidth: .infinity, minHeight: 44)
          .disabled(viewModel.selectedMetricKeys.isEmpty || viewModel.isExporting)
          .accessibilityIdentifier("chartBuilder.exportCSV")
      }

      if viewModel.isLoading || viewModel.isExporting {
        ProgressView(viewModel.isLoading ? "Building chart..." : "Preparing CSV...")
          .frame(maxWidth: .infinity, minHeight: 44)
      }

      if let errorMessage = viewModel.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
          .typography(.small)
          .foregroundStyle(AppTheme.Colors.danger)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(16)
          .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 10))
          .accessibilityIdentifier("chartBuilder.error")
      }

      if let response = viewModel.response {
        ChartBuilderChartView(
          response: response,
          chartType: viewModel.chartType,
          title: viewModel.chartTitle
        )

        if viewModel.showsGrowthTable {
          ChartBuilderGrowthTableView(response: response)
        }
      } else if !viewModel.isLoading {
        ContentUnavailableView(
          "Build a custom chart",
          systemImage: "chart.xyaxis.line",
          description: Text("Choose metrics and press Build chart to compare their history.")
        )
        .frame(maxWidth: .infinity, minHeight: 200)
      }
    }
    .sheet(item: $viewModel.exportItem) { item in
      ShareSheet(items: [item.url])
    }
  }

  private func buildChart() {
    Task { await viewModel.build() }
  }

  private func exportCSV() {
    Task { await viewModel.exportCSV() }
  }
}
