import SwiftUI
import StockPlanShared

struct BudgetCategoryDetailsScreen: View {
  @ObservedObject var viewModel: BudgetPlannerViewModel
  @Binding var isProfilePresented: Bool
  @Binding var isActivitySheetPresented: Bool
  @Binding var itemDraft: BudgetPlanItemDraft?

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        ForEach(BudgetPillar.allCases) { pillar in
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
            onAdd: {
              itemDraft = BudgetPlanItemDraft(
                itemID: nil,
                title: "",
                plannedAmount: 0,
                pillar: pillar,
                splitMode: .personal,
                userSharePercent: 100
              )
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
  let onAdd: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  private var leftAmount: Double {
    summary.plannedAmount - summary.actualAmount
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top) {
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
        Button(action: onAdd) {
          HStack(spacing: 4) {
            Image(systemName: "plus")
            Text("Add")
          }
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.white.opacity(0.1))
          .cornerRadius(8)
          .foregroundStyle(.white)
        }
      }
      .padding(16)

      Divider()
        .background(Color.white.opacity(0.1))

      HStack(spacing: 0) {
        MetricItem(title: "Goal", value: summary.targetAmount.currency, color: .primary)
        Divider().background(Color.white.opacity(0.1))
        MetricItem(title: "Planned", value: summary.plannedAmount.currency, color: .primary)
        Divider().background(Color.white.opacity(0.1))
        MetricItem(title: "Actual", value: summary.actualAmount.currency, color: .primary)
        Divider().background(Color.white.opacity(0.1))
        MetricItem(
          title: "Left",
          value: leftAmount.currency,
          color: leftAmount >= 0 ? .green : .red
        )
      }
      .padding(.vertical, 12)
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
    VStack(spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity)
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
