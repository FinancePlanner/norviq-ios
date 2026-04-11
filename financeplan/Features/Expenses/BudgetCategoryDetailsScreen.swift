import SwiftUI
import StockPlanShared

struct BudgetCategoryDetailsScreen: View {
  @ObservedObject var viewModel: BudgetPlannerViewModel
  @Binding var isProfilePresented: Bool
  @Binding var isActivitySheetPresented: Bool
  let onAddPlannedItem: (BudgetPillar) -> Void
  let onRecordExpense: (BudgetPillar) -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        ForEach(BudgetPillar.allCases, id: \.self) { pillar in
          let summary = viewModel.selectedMonthSummaries.first { $0.pillar == pillar }
            ?? PillarPlanningSummary(
              pillar: pillar,
              targetAmount: 0,
              plannedAmount: 0,
              actualAmount: 0,
              unplannedActualAmount: 0
            )

          BudgetCategoryCard(
            pillar: pillar,
            summary: summary,
            onAddPlanItem: {
              onAddPlannedItem(pillar)
            },
            onRecordExpense: {
              onRecordExpense(pillar)
            }
          )
        }

        RecordedSpendCard(
          activities: viewModel.selectedMonthActivities,
          onAddTransaction: {
            isActivitySheetPresented = true
          }
        )
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 20)
    }
    .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
    .navigationTitle("Budget Category Details")
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct BudgetCategoryCard: View {
  let pillar: BudgetPillar
  let summary: PillarPlanningSummary
  let onAddPlanItem: () -> Void
  let onRecordExpense: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  private var leftAmount: Double {
    summary.targetAmount - summary.actualAmount
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 12) {
        HStack(alignment: .center, spacing: 12) {
          Image(systemName: pillar.symbol)
            .font(.title2)
            .foregroundStyle(pillar.color(for: colorScheme))
            .frame(width: 24, height: 24)

          VStack(alignment: .leading, spacing: 2) {
            Text(pillar.title)
              .font(.headline)
            Text(pillar.subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()
        HStack(spacing: 8) {
          Button(action: onAddPlanItem) {
            HStack(spacing: 4) {
              Image(systemName: "plus.rectangle.on.folder")
              Text("Plan")
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(pillar.color(for: colorScheme).opacity(0.15))
            .cornerRadius(8)
            .foregroundStyle(pillar.color(for: colorScheme))
          }
          
          Button(action: onRecordExpense) {
            HStack(spacing: 4) {
              Image(systemName: "plus.circle")
              Text("Spend")
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .foregroundStyle(.primary)
          }
        }
      }
      .padding(16)

      Divider()
        .background(Color.white.opacity(0.1))

      VStack(spacing: 12) {
        HStack(spacing: 12) {
          MetricItem(title: "Goal", value: summary.targetAmount.currency, color: .primary)
          MetricItem(title: "Planned", value: summary.plannedAmount.currency, color: .primary)
        }
        
        HStack(spacing: 12) {
          MetricItem(title: "Actual", value: summary.actualAmount.currency, color: .primary)
          MetricItem(
            title: "Left",
            value: leftAmount.currency,
            color: leftAmount >= 0 ? .green : .red
          )
        }
      }
      .padding(16)
    }
    .background(Color(uiColor: .secondarySystemGroupedBackground))
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.05), lineWidth: 1)
    )
  }
}

private struct MetricItem: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
        .tracking(0.5)
      Text(value)
        .font(.headline.weight(.bold))
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color.white.opacity(0.04))
    .cornerRadius(10)
  }
}

private struct RecordedSpendCard: View {
  let activities: [BudgetActivity]
  let onAddTransaction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Recorded Spend")
        .font(.headline)

      if activities.isEmpty {
        VStack(spacing: 16) {
          Image(systemName: "wallet.pass")
            .font(.system(size: 64))
            .foregroundStyle(.gray.opacity(0.5))
            .padding(.top, 16)

          Text("No spending recorded for this month yet.\nStart tracking your expenses.")
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

          Button(action: onAddTransaction) {
            Text("Add First Transaction")
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(Color.green)
              .cornerRadius(12)
              .foregroundStyle(.white)
          }
          .padding(.horizontal, 40)
          .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
      } else {
        VStack(spacing: 0) {
          ForEach(activities.prefix(5)) { activity in
            HStack(spacing: 16) {
              Circle()
                .fill(activity.pillar.color(for: .dark))
                .frame(width: 44, height: 44)
                .overlay(
                  Image(systemName: activity.pillar.symbol)
                    .foregroundStyle(.white)
                    .font(.title3)
                )

              VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                  .font(.headline)
                Text(activity.pillar.title)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }

              Spacer()

              Text("-\(activity.amount.currency)")
                .font(.headline)
            }
            .padding(.vertical, 12)

            if activity.id != activities.prefix(5).last?.id {
              Divider()
                .background(Color.white.opacity(0.1))
                .padding(.leading, 60)
            }
          }
        }
      }
    }
    .padding(16)
    .background(Color(uiColor: .secondarySystemGroupedBackground))
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.05), lineWidth: 1)
    )
  }
}
