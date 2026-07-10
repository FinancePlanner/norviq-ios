import StockPlanShared
import SwiftUI

struct ChartBuilderMetricPickerView: View {
  @ObservedObject var viewModel: ChartBuilderViewModel
  @State private var searchText = ""

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Metrics")
              .typography(.small, weight: .semibold)
            Text("Select up to \(ChartBuilderViewModel.maxMetrics) series")
              .typography(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Text("\(viewModel.selectedMetricKeys.count) selected")
            .typography(.caption, weight: .semibold)
            .foregroundStyle(.secondary)
        }

        HStack(spacing: 8) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
          TextField("Search metrics", text: $searchText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 10))

        if hasResults {
          LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(ChartMetricGroup.allCases, id: \.rawValue) { group in
              let metrics = filteredMetrics(in: group)
              if !metrics.isEmpty {
                DisclosureGroup {
                  LazyVStack(spacing: 0) {
                    ForEach(metrics) { metric in
                      metricButton(metric)
                      if metric.id != metrics.last?.id {
                        Divider()
                      }
                    }
                  }
                  .padding(.top, 8)
                } label: {
                  HStack {
                    Text(group.title)
                      .typography(.small, weight: .semibold)
                    Spacer()
                    Text("\(metrics.count)")
                      .typography(.caption)
                      .foregroundStyle(.tertiary)
                  }
                }
              }
            }
          }
        } else {
          ContentUnavailableView.search
        }
      }
    }
  }

  private var hasResults: Bool {
    ChartMetricGroup.allCases.contains { !filteredMetrics(in: $0).isEmpty }
  }

  private func filteredMetrics(in group: ChartMetricGroup) -> [ChartMetricDescriptor] {
    let metrics = ChartBuilderMetricCatalog.metrics(in: group)
    let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedSearch.isEmpty else { return metrics }
    guard !group.title.localizedStandardContains(trimmedSearch) else { return metrics }
    return metrics.filter {
      $0.label.localizedStandardContains(trimmedSearch)
        || $0.key.localizedStandardContains(trimmedSearch)
    }
  }

  private func metricButton(_ metric: ChartMetricDescriptor) -> some View {
    let isSelected = viewModel.isSelected(metric)
    let isEnabled = viewModel.isEnabled(metric)

    return Button {
      viewModel.toggleMetric(metric)
    } label: {
      HStack(spacing: 12) {
        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
          .foregroundStyle(isSelected ? Color.accentColor : .secondary)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text(metric.label)
            .typography(.small)
            .foregroundStyle(isEnabled ? .primary : .secondary)

          if !isEnabled {
            Text("Not available for TTM")
              .typography(.caption)
              .foregroundStyle(.tertiary)
          }
        }

        Spacer()
      }
      .frame(minHeight: 44)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .accessibilityLabel(metric.label)
    .accessibilityValue(isSelected ? "Selected" : "Not selected")
    .accessibilityHint(isEnabled ? "Toggles this metric" : "Unavailable for trailing twelve months")
  }
}
