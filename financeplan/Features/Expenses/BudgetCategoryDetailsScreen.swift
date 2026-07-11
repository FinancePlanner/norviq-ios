import SwiftUI
import StockPlanShared

struct BudgetCategoryDetailsScreen: View {
  @Bindable var viewModel: BudgetPlannerViewModel
  @Binding var isActivitySheetPresented: Bool
  let onAddPlannedItem: (BudgetPillar) -> Void
  let onRecordExpense: (BudgetPillar) -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        ForEach(viewModel.selectedMonthPillars, id: \.self) { pillar in
          let summary = viewModel.selectedMonthSummaries.first { $0.pillar == pillar }
            ?? PillarPlanningSummary(
              pillar: pillar,
              targetAmount: 0,
              plannedAmount: 0,
              actualAmount: 0,
              unplannedActualAmount: 0
            )
          
          let previousMonthActual = viewModel.previousMonthPillarActual(for: pillar)

          BudgetCategoryCard(
            pillar: pillar,
            summary: summary,
            previousMonthActual: previousMonthActual,
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
  let previousMonthActual: Double?
  let onAddPlanItem: () -> Void
  let onRecordExpense: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  private var leftAmount: Double {
    summary.targetAmount - summary.actualAmount
  }
  
  private var progressPercentage: Double {
    guard summary.targetAmount > 0 else { return 0 }
    return min((summary.actualAmount / summary.targetAmount) * 100, 100)
  }
  
  private var monthOverMonthChange: (amount: Double, percentage: Double)? {
    guard let previous = previousMonthActual, previous > 0 else { return nil }
    let change = summary.actualAmount - previous
    let percentage = (change / previous) * 100
    return (change, percentage)
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
        Menu {
          Button("Plan item", systemImage: "plus.rectangle.on.folder", action: onAddPlanItem)
          Button("Record expense", systemImage: "plus.circle", action: onRecordExpense)
        } label: {
          Label("Add", systemImage: "plus")
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .clipShape(.rect(cornerRadius: 8))
            .foregroundStyle(.white)
        }
      }
      .padding(16)

      Divider()
        .background(Color.white.opacity(0.1))

      VStack(spacing: 16) {
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
        
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Budget usage")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Text("\(Int(progressPercentage))%")
              .font(.caption.weight(.semibold))
              .foregroundStyle(progressPercentage > 100 ? .red : .primary)
          }
          
          ProgressBar(
            value: summary.actualAmount,
            total: summary.targetAmount,
            color: progressPercentage > 100 ? .red : pillar.color(for: colorScheme),
            height: 8
          )
          
          HStack(spacing: 4) {
            Image(systemName: progressPercentage > 90 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill").accessibilityHidden(true)
              .font(.caption2)
              .foregroundStyle(progressPercentage > 100 ? .red : progressPercentage > 90 ? .orange : .green)
            
            Text(statusMessage)
              .font(.caption2)
              .foregroundStyle(.secondary)
            
            if let change = monthOverMonthChange {
              Spacer()
              HStack(spacing: 2) {
                Image(systemName: change.amount >= 0 ? "arrow.up.right" : "arrow.down.right")
                  .accessibilityHidden(true)
                  .font(.caption2)
                Text("\(abs(Int(change.percentage)))% vs last month")
                  .font(.caption2)
              }
              .foregroundStyle(change.amount >= 0 ? .orange : .green)
            }
          }
        }
        .padding(.horizontal, 16)
      }
      .padding(.vertical, 12)
    }
    .background(Color(uiColor: .secondarySystemGroupedBackground))
    .clipShape(.rect(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.05), lineWidth: 1)
    }
  }
  
  private var statusMessage: String {
    if progressPercentage > 100 {
      return "Over budget by \((summary.actualAmount - summary.targetAmount).currency)"
    } else if progressPercentage > 90 {
      return "Approaching limit"
    } else if summary.actualAmount == 0 {
      return "No spending yet"
    } else {
      return "\(leftAmount.currency) remaining"
    }
  }
}

//private struct MetricItem: View {
//  let title: String
//  let value: String
//  let color: Color
//
//  var body: some View {
//    VStack(spacing: 4) {
//      Text(title)
//        .font(.caption)
//        .foregroundStyle(.secondary)
//      Text(value)
//        .font(.subheadline.weight(.semibold))
//        .foregroundStyle(color)
//    }
//    .frame(maxWidth: .infinity)
//  }
//}

private struct RecordedSpendCard: View {
  let activities: [BudgetActivity]
  let onAddTransaction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Recorded Spend")
        .font(.headline)

      if activities.isEmpty {
        ContentUnavailableView {
          Label("No spending recorded", systemImage: "wallet.pass")
        } description: {
          Text("Start tracking your expenses to see where your money goes")
        } actions: {
          Button("Add First Transaction") {
            onAddTransaction()
          }
          .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
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
    .clipShape(.rect(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.05), lineWidth: 1)
    )
  }
}
