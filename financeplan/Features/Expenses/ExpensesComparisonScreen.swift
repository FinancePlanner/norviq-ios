import Charts
import SwiftUI

private enum BudgetComparisonMode: String, CaseIterable, Identifiable {
  case monthly
  case yearly

  var id: String { rawValue }

  var title: String {
    switch self {
    case .monthly:
      "Months"
    case .yearly:
      "Years"
    }
  }
}

struct ExpensesComparisonScreen: View {
  @Binding var isSettingsPresented: Bool
  @ObservedObject var viewModel: BudgetPlannerViewModel

  @Environment(\.colorScheme) private var colorScheme
  @State private var mode: BudgetComparisonMode = .monthly
  @State private var isProfilePresented = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          Picker("Comparison mode", selection: $mode) {
            ForEach(BudgetComparisonMode.allCases) { mode in
              Text(mode.title).tag(mode)
            }
          }
          .pickerStyle(.segmented)

          ComparisonOverviewCard(
            highestActual: monthlyHighestActual,
            lowestActual: monthlyLowestActual,
            currentMonth: currentMonthSummary
          )

          if mode == .monthly {
            VStack(spacing: 20) {
              MonthlyCashflowChart(summaries: viewModel.monthlySummaries)
              MonthlyComparisonChart(summaries: viewModel.monthlySummaries)
              PillarStackedChart(
                summaries: viewModel.monthlySummaries,
                colorScheme: colorScheme
              )
              MonthlyComparisonList(summaries: viewModel.monthlySummaries)
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
          } else {
            VStack(spacing: 20) {
              YearlyComparisonChart(
                summaries: viewModel.yearlySummaries,
                colorScheme: colorScheme
              )
              YearlyComparisonList(summaries: viewModel.yearlySummaries)
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
      }
      .background(MeshGradientBackground())
      .navigationTitle("Reports")
      .navigationBarTitleDisplayMode(.large)
      .animation(.snappy(duration: 0.24), value: mode)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button {
            isSettingsPresented = true
          } label: {
            Image(systemName: "gearshape")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
              .padding(6)
              .appGlassEffect(.capsule)
          }
          .accessibilityLabel("Open settings")

          AppTopBarProfileButton(
            isUserMenuPresented: isProfilePresented,
            onTap: { isProfilePresented = true }
          )
          .accessibilityLabel("Open profile")
        }
      }
      .sheet(isPresented: $isProfilePresented) {
        UserProfileView()
      }
    }
  }

  private var currentMonthSummary: BudgetMonthSummary {
    viewModel.monthlySummaries.last
      ?? BudgetMonthSummary(
        monthStart: .now,
        planned: 0,
        actual: 0,
        salary: 0,
        pillarActuals: [:],
        pillarPlans: [:]
      )
  }

  private var monthlyHighestActual: BudgetMonthSummary? {
    viewModel.monthlySummaries.max { $0.actual < $1.actual }
  }

  private var monthlyLowestActual: BudgetMonthSummary? {
    viewModel.monthlySummaries.min { $0.actual < $1.actual }
  }
}

private struct ComparisonOverviewCard: View {
  let highestActual: BudgetMonthSummary?
  let lowestActual: BudgetMonthSummary?
  let currentMonth: BudgetMonthSummary

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        Text("Comparison highlights")
          .typography(.small, weight: .semibold)

        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
          GridRow {
            SummaryBlock(
              title: "Current spend",
              value: currentMonth.actual.currency,
              detail: currentMonth.longLabel
            )
            SummaryBlock(
              title: "Money left",
              value: currentMonth.remainingAfterSpending.currency,
              detail: "After actual spending"
            )
          }

          GridRow {
          SummaryBlock(
              title: "Highest",
              value: highestActual?.actual.currency ?? "$0.00",
              detail: highestActual?.longLabel ?? "No data"
            )
            SummaryBlock(
              title: "Lowest",
              value: lowestActual?.actual.currency ?? "$0.00",
              detail: lowestActual?.longLabel ?? "No data"
            )
          }
        }
      }
    }
  }
}

private struct MonthlyCashflowChart: View {
  let summaries: [BudgetMonthSummary]

  @Environment(\.colorScheme) private var colorScheme
  @State private var chartProgress: Double = 0.0

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        Text("Salary vs money left")
          .typography(.small, weight: .semibold)

        Chart(summaries) { summary in
          LineMark(
            x: .value("Month", summary.shortLabel),
            y: .value("Salary", summary.salary * chartProgress)
          )
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme).opacity(0.35))

          LineMark(
            x: .value("Month", summary.shortLabel),
            y: .value("Remaining", summary.remainingAfterSpending * chartProgress)
          )
          .interpolationMethod(.catmullRom)
          .foregroundStyle(AppTheme.Colors.success)
          .lineStyle(.init(lineWidth: 3))

          AreaMark(
            x: .value("Month", summary.shortLabel),
            y: .value("Remaining", summary.remainingAfterSpending * chartProgress)
          )
          .interpolationMethod(.catmullRom)
          .foregroundStyle(
            LinearGradient(
              colors: [AppTheme.Colors.success.opacity(0.22), .clear],
              startPoint: .top,
              endPoint: .bottom
            )
          )
        }
        .frame(height: 220)
        .chartYAxis {
          AxisMarks(position: .leading)
        }
      }
    }
    .onAppear {
      withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
        chartProgress = 1.0
      }
    }
  }
}

private struct MonthlyComparisonChart: View {
  let summaries: [BudgetMonthSummary]

  @Environment(\.colorScheme) private var colorScheme
  @State private var chartProgress: Double = 0.0

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        Text("Planned vs actual by month")
          .typography(.small, weight: .semibold)

        Chart(summaries) { summary in
          BarMark(
            x: .value("Month", summary.shortLabel),
            y: .value("Amount", summary.planned * chartProgress)
          )
          .position(by: .value("Series", "Planned"))
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme).opacity(0.35))
          .cornerRadius(6)

          BarMark(
            x: .value("Month", summary.shortLabel),
            y: .value("Amount", summary.actual * chartProgress)
          )
          .position(by: .value("Series", "Actual"))
          .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme))
          .cornerRadius(6)
        }
        .frame(height: 220)
        .chartYAxis {
          AxisMarks(position: .leading)
        }
      }
    }
    .onAppear {
      withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
        chartProgress = 1.0
      }
    }
  }
}

private struct PillarStackedChart: View {
  let summaries: [BudgetMonthSummary]
  let colorScheme: ColorScheme
  @State private var chartProgress: Double = 0.0

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        Text("Actual spending by pillar")
          .typography(.small, weight: .semibold)

        Chart {
          ForEach(summaries) { summary in
            ForEach(BudgetPillar.allCases) { pillar in
              BarMark(
                x: .value("Month", summary.shortLabel),
                y: .value("Amount", (summary.pillarActuals[pillar] ?? 0) * chartProgress)
              )
              .foregroundStyle(pillar.color(for: colorScheme))
            }
          }
        }
        .frame(height: 220)
        .chartYAxis {
          AxisMarks(position: .leading)
        }

        HStack(spacing: 12) {
          ForEach(BudgetPillar.allCases) { pillar in
            Label(pillar.title, systemImage: "circle.fill")
              .foregroundStyle(pillar.color(for: colorScheme))
              .typography(.nano)
          }
        }
      }
    }
    .onAppear {
      withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
        chartProgress = 1.0
      }
    }
  }
}

private struct MonthlyComparisonList: View {
  let summaries: [BudgetMonthSummary]

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        Text("Month breakdown")
          .typography(.small, weight: .semibold)

        ForEach(summaries.reversed()) { summary in
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(summary.longLabel)
                .typography(.small, weight: .semibold)
              Text("Salary \(summary.salary.currency) • Planned \(summary.planned.currency)")
                .typography(.nano)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
              Text(summary.actual.currency)
                .typography(.small, weight: .semibold)
                .foregroundStyle(summary.actual <= summary.planned ? AppTheme.Colors.success : AppTheme.Colors.danger)
              Text("Left \(summary.remainingAfterSpending.currency)")
                .typography(.nano)
                .foregroundStyle(.secondary)
            }
          }

          if summary.id != summaries.first?.id {
            Divider()
          }
        }
      }
    }
  }
}

private struct YearlyComparisonChart: View {
  let summaries: [BudgetYearSummary]
  let colorScheme: ColorScheme
  @State private var chartProgress: Double = 0.0

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        Text("Year-over-year comparison")
          .typography(.small, weight: .semibold)

        Chart(summaries) { summary in
          BarMark(
            x: .value("Year", String(summary.year)),
            y: .value("Actual", summary.actual * chartProgress)
          )
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          .cornerRadius(8)

          RuleMark(y: .value("Planned", summary.planned * chartProgress))
            .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme))
            .lineStyle(.init(lineWidth: 2, dash: [6, 4]))
        }
        .frame(height: 220)
        .chartYAxis {
          AxisMarks(position: .leading)
        }
      }
    }
    .onAppear {
      withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
        chartProgress = 1.0
      }
    }
  }
}

private struct YearlyComparisonList: View {
  let summaries: [BudgetYearSummary]

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        Text("Year summary")
          .typography(.small, weight: .semibold)

        ForEach(summaries.reversed()) { summary in
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(String(summary.year))
                .typography(.small, weight: .semibold)
              Text("Salary \(summary.salary.currency)")
                .typography(.nano)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
              Text(summary.actual.currency)
                .typography(.small, weight: .semibold)
              Text("Left \(summary.remainingAfterSpending.currency)")
                .typography(.nano)
                .foregroundStyle(.secondary)
            }
          }

          if summary.id != summaries.first?.id {
            Divider()
          }
        }
      }
    }
  }
}

private struct SummaryBlock: View {
  let title: String
  let value: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .typography(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .typography(.small, weight: .semibold)
        .contentTransition(.numericText())
      Text(detail)
        .typography(.nano)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
