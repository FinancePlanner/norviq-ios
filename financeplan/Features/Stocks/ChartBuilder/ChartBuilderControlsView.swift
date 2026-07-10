import StockPlanShared
import SwiftUI

struct ChartBuilderControlsView: View {
  @ObservedObject var viewModel: ChartBuilderViewModel
  @State private var compareDraft = ""

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        Text("Chart settings")
          .typography(.small, weight: .semibold)

        VStack(alignment: .leading, spacing: 8) {
          Text("Period")
            .typography(.caption, weight: .semibold)
            .foregroundStyle(.secondary)

          Picker("Period", selection: $viewModel.period) {
            Text("Annual").tag(ChartBuilderPeriodKind.annual)
            Text("Quarterly").tag(ChartBuilderPeriodKind.quarter)
            Text("TTM").tag(ChartBuilderPeriodKind.ttm)
          }
          .pickerStyle(.segmented)
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("Chart type")
            .typography(.caption, weight: .semibold)
            .foregroundStyle(.secondary)

          Picker("Chart type", selection: $viewModel.chartType) {
            ForEach(ChartBuilderChartType.allCases) { type in
              Text(type.title).tag(type)
            }
          }
          .pickerStyle(.segmented)
        }

        Toggle("Show growth table", isOn: $viewModel.showsGrowthTable)

        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Compare")
              .typography(.caption, weight: .semibold)
              .foregroundStyle(.secondary)
            Spacer()
            Text("\(viewModel.compareSymbols.count)/\(ChartBuilderViewModel.maxCompareSymbols) peers")
              .typography(.caption)
              .foregroundStyle(.tertiary)
          }

          HStack(spacing: 8) {
            TextField("Add ticker", text: $compareDraft)
              .textInputAutocapitalization(.characters)
              .autocorrectionDisabled()
              .submitLabel(.done)
              .onSubmit(addCompareSymbol)

            Button("Add comparison", systemImage: "plus", action: addCompareSymbol)
              .labelStyle(.iconOnly)
              .buttonStyle(.bordered)
              .frame(minWidth: 44, minHeight: 44)
              .disabled(compareDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }

          if !viewModel.compareSymbols.isEmpty {
            ScrollView(.horizontal) {
              HStack(spacing: 8) {
                ForEach(viewModel.compareSymbols, id: \.self) { symbol in
                  Button {
                    viewModel.removeCompareSymbol(symbol)
                  } label: {
                    Label("Remove \(symbol)", systemImage: "xmark.circle.fill")
                      .labelStyle(.titleAndIcon)
                  }
                  .buttonStyle(.bordered)
                  .accessibilityHint("Removes this comparison from the next chart build")
                }
              }
            }
            .scrollIndicators(.hidden)
          }

          Text("Peer series are aligned to \(viewModel.symbol) by fiscal year.")
            .typography(.caption)
            .foregroundStyle(.tertiary)
        }
      }
    }
  }

  private func addCompareSymbol() {
    viewModel.addCompareSymbol(compareDraft)
    compareDraft = ""
  }
}
