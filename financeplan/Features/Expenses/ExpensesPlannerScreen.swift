import Charts
import SwiftUI
import StockPlanShared

struct ExpensesPlannerScreen: View {
  @Binding var isSettingsPresented: Bool
  @ObservedObject var viewModel: BudgetPlannerViewModel

  @Environment(\.colorScheme) private var colorScheme
  @State private var isProfilePresented = false
  @State private var isSalaryEditorPresented = false
  @State private var isTargetEditorPresented = false
  @State private var isActivitySheetPresented = false
  @State private var isPartnerEditorPresented = false
  @State private var itemDraft: BudgetPlanItemDraft?
  @State private var presentedPlanItemDraft: BudgetPlanItemDraft?
  @State private var didSavePresentedPlanItemDraft = false
  @State private var itemToDelete: BudgetPlanItem?
  @State private var recordSpendInitialPillar: BudgetPillar = .fundamentals
  @State private var destructiveFeedbackTrigger = 0

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          ExpensesCircularOverviewCard(
            leftAmount: viewModel.selectedMonthLeftAfterSpending,
            totalAmount: viewModel.selectedMonthSnapshot?.netSalary ?? 0
          )
          .padding(.top, 10)

          if (viewModel.selectedMonthSnapshot?.netSalary ?? 0) <= 0 {
            GlassCard(cornerRadius: 18) {
              HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(AppTheme.Colors.warning)

                VStack(alignment: .leading, spacing: 6) {
                  Text("Set your monthly budget")
                    .typography(.small, weight: .semibold)
                  Text("Your monthly budget is currently 0. Add salary and side income so spending insights can calculate correctly.")
                    .typography(.nano)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Set") {
                  isSalaryEditorPresented = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
              }
            }
            .padding(.horizontal, 16)
          }

          ExpensesYearOverviewCard(
            selectedYear: selectedYearBinding,
            availableYears: viewModel.availableYears,
            totalSpent: viewModel.selectedYearActualTotal,
            averageSpent: viewModel.selectedYearAverageActual,
            lastMonthLabel: viewModel.selectedYearLastMonthLabel,
            chartPoints: viewModel.selectedYearChartPoints
          )
          .padding(.horizontal, 16)

          PlannerSalaryCard(
            monthTitle: viewModel.selectedMonthDisplayTitle,
            netSalary: viewModel.selectedMonthSnapshot?.netSalary ?? 0,
            allocated: viewModel.selectedMonthPlannedTotal,
            spent: viewModel.selectedMonthActualTotal,
            myPlanned: viewModel.selectedMonthMyPlannedTotal,
            partnerPlanned: viewModel.selectedMonthPartnerPlannedTotal,
            mySpent: viewModel.selectedMonthMyActualTotal,
            partnerSpent: viewModel.selectedMonthPartnerActualTotal,
            partnerName: viewModel.partnerDisplayName,
            leftToAllocate: viewModel.selectedMonthAvailableAfterPillarPlan,
            leftAfterSpending: viewModel.selectedMonthLeftAfterSpending,
            onEditMonthlyBudget: { isSalaryEditorPresented = true }
          )
          .padding(.horizontal, 16)

          PillarAllocationTableCard(
            monthTitle: viewModel.selectedMonthDisplayTitle,
            summaries: viewModel.selectedMonthSummaries
          )
          .padding(.horizontal, 16)

          SmartSuggestionsCard(
            suggestion: viewModel.topReportSuggestion,
            isLoading: viewModel.isSuggestionsLoading,
            isUnavailable: viewModel.suggestionsUnavailable,
            onDismiss: { suggestion in
              viewModel.dismissSuggestion(suggestion)
            }
          )
            .padding(.horizontal, 16)

          RecentTransactionsList(activities: viewModel.selectedMonthActivities)
            .padding(.horizontal, 16)
            
          NavigationLink {
            BudgetCategoryDetailsScreen(
              viewModel: viewModel,
              isProfilePresented: $isProfilePresented,
              isActivitySheetPresented: $isActivitySheetPresented,
              onAddPlannedItem: { pillar in
                presentNewPlanItemDraft(pillar: pillar)
              },
              onRecordExpense: { pillar in
                recordSpendInitialPillar = pillar
                isActivitySheetPresented = true
              }
            )
          } label: {
            HStack {
              Image(systemName: "square.grid.2x2.fill")
                .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
              Text("Budget Category Details")
                .font(.headline)
                .foregroundStyle(.primary)
              Spacer()
              Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 40)
        }
        .padding(.vertical, 10)
      }
      .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
      .navigationTitle("Expenses and Budgeting")
      .navigationBarTitleDisplayMode(.inline)
      .overlay(alignment: .top) {
        if let errorMessage = viewModel.errorMessage {
          Text(errorMessage)
            .font(.caption)
            .foregroundStyle(.white)
            .padding()
            .background(Color.red)
            .cornerRadius(8)
            .padding()
        }
      }
      .task {
        await viewModel.load()
      }
      .toolbarTitleMenu {

        Picker("Month", selection: selectedMonthBinding) {
          ForEach(viewModel.availableMonths, id: \.self) { date in
            Text(date.formatted(.dateTime.month(.wide).year())).tag(date)
          }
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          HStack(spacing: 8) {
            Button {
              recordSpendInitialPillar = .fundamentals
              isActivitySheetPresented = true
            } label: {
              Image(systemName: "plus.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                .padding(6)
                .appGlassEffect(.capsule)
            }
            .accessibilityLabel("Record spend")

            Menu {
              Button("Plan next month", systemImage: "calendar.badge.plus") {
                viewModel.createNextMonthPlan()
              }

              Button("Adjust monthly budget", systemImage: "eurosign.circle") {
                isSalaryEditorPresented = true
              }

              Button("Adjust pillar targets", systemImage: "slider.horizontal.3") {
                isTargetEditorPresented = true
              }

              Button("Add planned item", systemImage: "plus.rectangle.on.folder") {
                presentNewPlanItemDraft(pillar: .fundamentals)
              }

              Button("Record spend", systemImage: "plus.circle") {
                recordSpendInitialPillar = .fundamentals
                isActivitySheetPresented = true
              }

              Button("Household partner", systemImage: "person.2") {
                isPartnerEditorPresented = true
              }
              
              Divider()
              
              Button("Delete this month plan", systemImage: "trash", role: .destructive) {
                viewModel.deleteCurrentSnapshot()
              }
            } label: {
              Image(systemName: "ellipsis.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                .padding(6)
                .appGlassEffect(.capsule)
            }
            .accessibilityLabel("Expense actions")

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
          }
        }
      }
      .sheet(isPresented: $isProfilePresented) {
        UserProfileView()
      }
      .sheet(isPresented: $isSalaryEditorPresented) {
        NetSalaryEditorSheet(
          currentValue: viewModel.selectedMonthSnapshot?.netSalary ?? 0,
          monthTitle: viewModel.selectedMonthDisplayTitle,
          onSave: viewModel.updateNetSalary
        )
      }
      .sheet(isPresented: $isTargetEditorPresented) {
        PillarTargetsEditorSheet(
          monthTitle: viewModel.selectedMonthDisplayTitle,
          currentShares: viewModel.selectedMonthSnapshot?.targetShares ?? [:],
          onSave: viewModel.updateTargetShares
        )
      }
      .sheet(
        item: $itemDraft,
        onDismiss: {
          if !didSavePresentedPlanItemDraft, let draft = presentedPlanItemDraft {
            viewModel.cancelPlanItemDraft(draft)
          }
          didSavePresentedPlanItemDraft = false
          presentedPlanItemDraft = nil
        }
      ) { draft in
        PlanItemEditorSheet(draft: draft) { updatedDraft in
          didSavePresentedPlanItemDraft = true
          viewModel.addOrUpdatePlanItem(updatedDraft)
        }
      }
      .sheet(isPresented: $isActivitySheetPresented, onDismiss: {
        recordSpendInitialPillar = .fundamentals
      }) {
        RecordSpendSheet(
          monthTitle: viewModel.selectedMonthDisplayTitle,
          selectedMonthStart: viewModel.selectedMonthStart,
          initialPillar: recordSpendInitialPillar,
          availableItems: viewModel.selectedMonthSnapshot?.items ?? []
        ) { draft in
          viewModel.recordExpense(draft)
        }
      }
      .sheet(isPresented: $isPartnerEditorPresented) {
        HouseholdPartnerEditorSheet(
          currentName: viewModel.partnerDisplayName == "Partner" ? "" : viewModel.partnerDisplayName
        ) { name in
          viewModel.updatePartnerDisplayName(name)
        }
      }
      .confirmationDialog(
        "Delete planned item?",
        isPresented: Binding(
          get: { itemToDelete != nil },
          set: { if !$0 { itemToDelete = nil } }
        ),
        presenting: itemToDelete
      ) { item in
        Button("Delete", role: .destructive) {
          destructiveFeedbackTrigger += 1
          viewModel.removePlanItem(item.id)
        }
      } message: { item in
        Text("Remove \(item.title) from the \(item.pillar.title) plan for \(viewModel.selectedMonthDisplayTitle).")
      }
    }
    .appSensoryFeedback(destructive: destructiveFeedbackTrigger)
  }

  private var selectedMonthBinding: Binding<Date> {
    Binding(
      get: { viewModel.selectedMonthStart },
      set: { viewModel.selectMonth($0) }
    )
  }

  private func presentNewPlanItemDraft(pillar: BudgetPillar) {
    Task {
      if let draft = await viewModel.beginPlannedItemDraft(pillar: pillar) {
        presentedPlanItemDraft = draft
        didSavePresentedPlanItemDraft = false
        itemDraft = draft
      }
    }
  }

  private var selectedYearBinding: Binding<Int> {
    Binding(
      get: { viewModel.selectedYear },
      set: { viewModel.selectYear($0) }
    )
  }
}

private struct ExpensesYearOverviewCard: View {
  @Binding var selectedYear: Int
  let availableYears: [Int]
  let totalSpent: Double
  let averageSpent: Double
  let lastMonthLabel: String
  let chartPoints: [BudgetMonthChartPoint]

  @Environment(\.colorScheme) private var colorScheme

  @State private var chartProgress: Double = 0.0

  var body: some View {
    GlassCard(cornerRadius: 28) {
      VStack(alignment: .leading, spacing: 18) {
        Picker("Year", selection: $selectedYear) {
          ForEach(availableYears, id: \.self) { year in
            Text(String(year)).tag(year)
          }
        }
        .pickerStyle(.menu)

        VStack(alignment: .leading, spacing: 6) {
          Text("Total")
            .typography(.caption, weight: .semibold)
            .foregroundStyle(.secondary)

          Text(totalSpent.currency)
            .typography(.hero, weight: .bold)
            .contentTransition(.numericText())

          Text("Avg \(averageSpent.currency) through \(lastMonthLabel)")
            .typography(.nano)
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
        }

        VStack(alignment: .leading, spacing: 12) {
          Text("Overview")
            .typography(.caption, weight: .semibold)
            .foregroundStyle(.secondary)

          VStack(alignment: .leading, spacing: 12) {
            Text("Expenses")
              .typography(.small, weight: .semibold)
            Text("Yearly actual spending")
              .typography(.nano)
              .foregroundStyle(.secondary)

            Chart(chartPoints) { point in
              BarMark(
                x: .value("Month", point.label),
                y: .value("Spent", point.actual * chartProgress)
              )
              .foregroundStyle(AppTheme.Colors.tint(for: colorScheme).gradient)
              .cornerRadius(6)
            }
            .frame(height: 180)
            .chartYAxis {
              AxisMarks(position: .trailing)
            }
          }
          .padding(14)
          .background(
            AppTheme.Colors.elevatedCardBackground(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
          )
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

private struct ExpensesMonthDetailListCard: View {
  @Binding var selectedMonthStart: Date
  let summaries: [BudgetMonthSummary]

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        Text("Monthly detail")
          .typography(.caption, weight: .semibold)
          .foregroundStyle(.secondary)

        if summaries.isEmpty {
          Text("No months available for this year yet.")
            .typography(.small)
            .foregroundStyle(.secondary)
        } else {
          ForEach(summaries) { summary in
            Button {
              selectedMonthStart = summary.monthStart
            } label: {
              HStack(spacing: 12) {
                Text(summary.monthStart.formatted(.dateTime.month(.wide)))
                  .typography(.small, weight: .semibold)
                  .foregroundStyle(.primary)

                Spacer()

                Text(summary.actual.currency)
                  .typography(.small, weight: .semibold)
                  .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 12)
              .background(
                calendarHighlight(for: summary),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
              )
            }
            .buttonStyle(.plain)

            if summary.id != summaries.last?.id {
              Divider()
                .padding(.leading, 12)
            }
          }
        }
      }
    }
  }

  private func calendarHighlight(for summary: BudgetMonthSummary) -> Color {
    Calendar.current.isDate(summary.monthStart, equalTo: selectedMonthStart, toGranularity: .month)
      ? AppTheme.Colors.tintSoft(for: colorScheme)
      : .clear
  }
}

private struct SelectedMonthPlannerCard: View {
  let monthTitle: String
  let onPlanNextMonth: () -> Void

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Selected month")
              .typography(.small, weight: .semibold)
            Text(monthTitle)
              .typography(.headline, weight: .bold)
            Text("Tap a month above to switch context, then adjust salary, pillars, and planned items.")
              .typography(.nano)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Button {
            onPlanNextMonth()
          } label: {
            Label("Plan next", systemImage: "calendar.badge.plus")
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
      }
    }
  }
}

private struct PlannerSalaryCard: View {
  let monthTitle: String
  let netSalary: Double
  let allocated: Double
  let spent: Double
  let myPlanned: Double
  let partnerPlanned: Double
  let mySpent: Double
  let partnerSpent: Double
  let partnerName: String
  let leftToAllocate: Double
  let leftAfterSpending: Double
  let onEditMonthlyBudget: () -> Void

  var body: some View {
    GlassCard(cornerRadius: 20) {
      VStack(alignment: .center, spacing: 16) {
        HStack {
          Text("Monthly Budget Plan")
            .font(.headline)
          Spacer()
          Text(monthTitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        
        VStack(spacing: 4) {
          Text(netSalary.currency)
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .contentTransition(.numericText())
          Text("salary + side income")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)

        Button("Edit monthly budget") {
          onEditMonthlyBudget()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        
        HStack(spacing: 0) {
          MetricItem(title: "Planned", value: allocated.currency, color: .primary)
          Divider().background(Color.white.opacity(0.1))
          MetricItem(title: "Spent", value: spent.currency, color: .primary)
        }

        Divider().background(Color.white.opacity(0.1))

        HStack(spacing: 0) {
          MetricItem(title: "My plan", value: myPlanned.currency, color: .primary)
          Divider().background(Color.white.opacity(0.1))
          MetricItem(title: "\(partnerName) plan", value: partnerPlanned.currency, color: .primary)
        }

        Divider().background(Color.white.opacity(0.1))

        HStack(spacing: 0) {
          MetricItem(title: "My spend", value: mySpent.currency, color: .primary)
          Divider().background(Color.white.opacity(0.1))
          MetricItem(title: "\(partnerName) spend", value: partnerSpent.currency, color: .primary)
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        HStack(spacing: 0) {
          MetricItem(
            title: "Available after plan",
            value: leftToAllocate.currency,
            color: leftToAllocate >= 0 ? .green : .red
          )
          Divider().background(Color.white.opacity(0.1))
          MetricItem(
            title: "Available after spend",
            value: leftAfterSpending.currency,
            color: leftAfterSpending >= 0 ? .green : .red
          )
        }
      }
    }
  }
}

private struct PillarAllocationTableCard: View {
  let monthTitle: String
  let summaries: [PillarPlanningSummary]

  var body: some View {
    GlassCard(cornerRadius: 20) {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("Where your salary goes")
            .font(.headline)
          Spacer()
          Text(monthTitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
          GridRow {
            Text("Pillar").font(.subheadline).foregroundStyle(.secondary)
            Text("Goal").font(.subheadline).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text("Plan").font(.subheadline).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text("Actual").font(.subheadline).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text("Left").font(.subheadline).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
          }

          Divider().background(Color.white.opacity(0.1))

          ForEach(summaries) { summary in
            GridRow {
              Text(summary.pillar.title)
                .font(.subheadline)
              Text(summary.targetAmount.currency)
                .font(.subheadline).foregroundStyle(.secondary)
              Text(summary.plannedAmount.currency)
                .font(.subheadline).foregroundStyle(.secondary)
              Text(summary.actualAmount.currency)
                .font(.subheadline).foregroundStyle(.secondary)
              Text(summary.availableToPlan.currency)
                .font(.subheadline)
                .foregroundStyle(summary.availableToPlan >= 0 ? .green : .red)
            }
            if summary.id != summaries.last?.id {
              Divider().background(Color.white.opacity(0.1))
            }
          }
        }
      }
    }
  }
}

private struct PillarPlannerCard: View {
  let pillar: BudgetPillar
  let items: [BudgetPlanItem]
  let summary: PillarPlanningSummary
  let actualAmount: (BudgetPlanItem) -> Double
  let onEdit: (BudgetPlanItem) -> Void
  let onAdd: () -> Void
  let onDelete: (BudgetPlanItem) -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 6) {
            Label(pillar.title, systemImage: pillar.symbol)
              .typography(.small, weight: .semibold)
              .foregroundStyle(pillar.color(for: colorScheme))

            Text(pillar.subtitle)
              .typography(.nano)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Button("Add", action: onAdd)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }

        HStack(spacing: 10) {
          SummaryMetric(title: "Goal", value: summary.targetAmount.currency)
          SummaryMetric(title: "Planned", value: summary.plannedAmount.currency)
          SummaryMetric(title: "Actual", value: summary.actualAmount.currency)
        }

        if items.isEmpty {
          Text("No planned items yet.")
            .typography(.small)
            .foregroundStyle(.secondary)
        } else {
          ForEach(items) { item in
            PlannerItemRow(
              item: item,
              actualAmount: actualAmount(item),
              onEdit: { onEdit(item) },
              onDelete: { onDelete(item) }
            )

            if item.id != items.last?.id {
              Divider()
            }
          }
        }

        if summary.unplannedActualAmount > 0 {
          HStack {
            Text("Unplanned")
              .typography(.nano, weight: .semibold)
            Spacer()
            Text(summary.unplannedActualAmount.currency)
              .typography(.nano, weight: .semibold)
              .foregroundStyle(AppTheme.Colors.warning)
          }
        }
      }
    }
  }
}

private struct PlannerItemRow: View {
  let item: BudgetPlanItem
  let actualAmount: Double
  let onEdit: () -> Void
  let onDelete: () -> Void

  private var variance: Double {
    item.plannedAmount - actualAmount
  }

  var body: some View {
    Button {
      onEdit()
    } label: {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(item.title)
            .typography(.small, weight: .semibold)
            .foregroundStyle(.primary)
          Text(splitLabel)
            .typography(.nano)
            .foregroundStyle(.secondary)
          Text("Planned \(item.plannedAmount.currency) • Spent \(actualAmount.currency)")
            .typography(.nano)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Text(variance.currency)
          .typography(.small, weight: .semibold)
          .foregroundStyle(variance >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger)
          .contentTransition(.numericText())

        Menu {
          Button("Edit", systemImage: "pencil", action: onEdit)
          Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
          Image(systemName: "ellipsis.circle")
            .font(.body)
            .foregroundStyle(.secondary)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(CardButtonStyle())
    .contextMenu {
      Button("Edit", systemImage: "pencil", action: onEdit)
      Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text(item.title))
    .accessibilityValue(Text("Planned \(item.plannedAmount.currency), Spent \(actualAmount.currency)"))
  }

  private var splitLabel: String {
    switch item.splitMode {
    case .personal:
      return "Personal"
    case .shared:
      return "Shared \(Int(item.userSharePercent.rounded()))/\(Int((100 - item.userSharePercent).rounded()))"
    }
  }
}

private struct RecentActivityCard: View {
  let activities: [BudgetActivity]

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        Text("Recorded spend")
          .typography(.small, weight: .semibold)

        if activities.isEmpty {
          Text("No spending recorded for this month yet.")
            .typography(.small)
            .foregroundStyle(.secondary)
        } else {
          ForEach(activities.prefix(8)) { activity in
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                  .typography(.small, weight: .semibold)
                Text(activity.occurredOn.formatted(date: .abbreviated, time: .omitted))
                  .typography(.nano)
                  .foregroundStyle(.secondary)
                Text(splitLabel(for: activity))
                  .typography(.nano)
                  .foregroundStyle(.secondary)
              }

              Spacer()

              Text(activity.amount.currency)
                .typography(.small, weight: .semibold)
            }

            if activity.id != activities.prefix(8).last?.id {
              Divider()
            }
          }
        }
      }
    }
  }

  private func splitLabel(for activity: BudgetActivity) -> String {
    switch activity.splitMode {
    case .personal:
      return "Personal"
    case .shared:
      return "Shared \(Int(activity.userSharePercent.rounded()))/\(Int((100 - activity.userSharePercent).rounded()))"
    }
  }
}

private struct SummaryMetric: View {
  let title: String
  let value: String
  var accent: Color = .primary

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .typography(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .typography(.small, weight: .semibold)
        .foregroundStyle(accent)
        .contentTransition(.numericText())
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text(title))
    .accessibilityValue(Text(value))
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Premium UI Helpers

private struct CardButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
      .opacity(configuration.isPressed ? 0.9 : 1.0)
  }
}

private struct PlannerTableHeader: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .typography(.caption, weight: .semibold)
      .foregroundStyle(.secondary)
  }
}

private struct NetSalaryEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var value: String
  @FocusState private var isValueFocused: Bool
  @State private var successFeedbackTrigger = 0

  let monthTitle: String
  let onSave: (Double) -> Void

  init(currentValue: Double, monthTitle: String, onSave: @escaping (Double) -> Void) {
    _value = State(initialValue: currentValue.formatted(.number.precision(.fractionLength(2))))
    self.monthTitle = monthTitle
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Monthly Budget") {
          Text(monthTitle)
            .foregroundStyle(.secondary)

          TextField("Monthly budget", text: $value)
            .keyboardType(.decimalPad)
            .focused($isValueFocused)

          Text("You can include take-home salary and extra monthly income sources.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Adjust Monthly Budget")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            guard let parsed = parseMonetaryValue(value), parsed >= 0 else { return }
            onSave(parsed)
            successFeedbackTrigger += 1
            dismiss()
          }
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { isValueFocused = false }
        }
      }
    }
    .appSensoryFeedback(success: successFeedbackTrigger)
  }

  private func parseMonetaryValue(_ raw: String) -> Double? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let filtered = trimmed.filter { $0.isNumber || $0 == "," || $0 == "." }
    guard !filtered.isEmpty else { return nil }

    let characters = Array(filtered)
    let separatorIndexes = characters.indices.filter { characters[$0] == "," || characters[$0] == "." }

    if separatorIndexes.isEmpty {
      return Double(filtered)
    }

    if separatorIndexes.count == 1 {
      let separatorIndex = separatorIndexes[0]
      let leadingDigits = separatorIndex
      let trailingDigits = characters.count - separatorIndex - 1
      if leadingDigits > 0 && trailingDigits == 3 {
        let normalized = filtered
          .replacingOccurrences(of: ",", with: "")
          .replacingOccurrences(of: ".", with: "")
        return Double(normalized)
      }
    }

    let decimalSeparator = characters[separatorIndexes.last!]
    var normalized = ""
    var consumedDecimal = false

    for character in characters {
      if character.isNumber {
        normalized.append(character)
        continue
      }

      if (character == "," || character == ".")
        && character == decimalSeparator
        && !consumedDecimal
      {
        normalized.append(".")
        consumedDecimal = true
      }
    }

    guard normalized != "." else { return nil }
    return Double(normalized)
  }
}

private struct PillarTargetsEditorSheet: View {
  @Environment(\.dismiss) private var dismiss

  let monthTitle: String
  let onSave: ([BudgetPillar: Double]) -> Void

  @State private var fundamentals: Double
  @State private var futureYou: Double
  @State private var fun: Double
  @State private var successFeedbackTrigger = 0

  init(
    monthTitle: String,
    currentShares: [BudgetPillar: Double],
    onSave: @escaping ([BudgetPillar: Double]) -> Void
  ) {
    self.monthTitle = monthTitle
    self.onSave = onSave
    _fundamentals = State(initialValue: (currentShares[.fundamentals] ?? 0.5) * 100)
    _futureYou = State(initialValue: (currentShares[.futureYou] ?? 0.2) * 100)
    _fun = State(initialValue: (currentShares[.fun] ?? 0.3) * 100)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Target distribution") {
          Text(monthTitle)
            .foregroundStyle(.secondary)

          TargetSlider(title: BudgetPillar.fundamentals.title, value: $fundamentals)
          TargetSlider(title: BudgetPillar.futureYou.title, value: $futureYou)
          TargetSlider(title: BudgetPillar.fun.title, value: $fun)
          HStack {
            Text("Total")
            Spacer()
            Text("\(Int((fundamentals + futureYou + fun).rounded()))%")
              .foregroundStyle((Int((fundamentals + futureYou + fun).rounded()) == 100) ? .secondary : AppTheme.Colors.warning)
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Pillar Targets")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(
              [
                .fundamentals: fundamentals / 100,
                .futureYou: futureYou / 100,
                .fun: fun / 100,
              ]
            )
            successFeedbackTrigger += 1
            dismiss()
          }
          .disabled(Int((fundamentals + futureYou + fun).rounded()) != 100)
        }
      }
    }
    .appSensoryFeedback(success: successFeedbackTrigger)
  }
}

private struct TargetSlider: View {
  let title: String
  @Binding var value: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(title)
        Spacer()
        Text("\(Int(value.rounded()))%")
          .foregroundStyle(.secondary)
      }

      Slider(value: $value, in: 0...100, step: 1)
    }
  }
}

private struct PlanItemEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  @State private var title: String
  @State private var plannedAmount: String
  @State private var pillar: BudgetPillar
  @State private var splitMode: ExpenseSplitMode
  @State private var userSharePercent: Double
  @FocusState private var isAmountFocused: Bool
  @State private var validationMessage: String?
  @State private var successFeedbackTrigger = 0

  let itemID: UUID?
  let placeholderItemID: UUID?
  let onSave: (BudgetPlanItemDraft) -> Void

  init(draft: BudgetPlanItemDraft, onSave: @escaping (BudgetPlanItemDraft) -> Void) {
    _title = State(initialValue: draft.title)
    _plannedAmount = State(
      initialValue: draft.plannedAmount == 0
        ? ""
        : draft.plannedAmount.formatted(.number.precision(.fractionLength(2)))
    )
    _pillar = State(initialValue: draft.pillar)
    _splitMode = State(initialValue: draft.splitMode)
    _userSharePercent = State(initialValue: draft.userSharePercent)
    self.itemID = draft.itemID
    self.placeholderItemID = draft.placeholderItemID
    self.onSave = onSave
  }

  var body: some View {
    VStack(spacing: 0) {
      FormSheetHeader(
        title: itemID == nil ? "Add Planned Item" : "Edit Planned Item",
        onDismiss: { dismiss() }
      )

      ScrollView {
        VStack(spacing: 16) {
          FormCard(title: "Details") {
            FormTextField(
              icon: "text.cursor",
              iconColor: AppTheme.Colors.tint(for: colorScheme),
              placeholder: "Name",
              text: $title,
              autocapitalization: .words
            )

            FormDivider()

            FormTextField(
              icon: "dollarsign.circle",
              iconColor: AppTheme.Colors.secondaryTint(for: colorScheme),
              placeholder: "Planned amount",
              text: $plannedAmount,
              keyboardType: .decimalPad
            )
            .focused($isAmountFocused)

            if let validationMessage {
              Text(validationMessage)
                .font(.caption)
                .foregroundStyle(.red)
            }
          }

          FormCard(title: "Category") {
            FormRow(icon: "square.stack.3d.up", iconColor: .orange, label: "Pillar") {
              Picker("Pillar", selection: $pillar) {
                ForEach(BudgetPillar.allCases) { pillar in
                  Text(pillar.title).tag(pillar)
                }
              }
              .labelsHidden()
            }
          }

          FormCard(title: "Split") {
            FormRow(icon: "person.2", iconColor: .green, label: "Mode") {
              Picker("Mode", selection: $splitMode) {
                Text("Personal").tag(ExpenseSplitMode.personal)
                Text("Shared").tag(ExpenseSplitMode.shared)
              }
              .labelsHidden()
            }

            if splitMode == .shared {
              FormDivider()
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text("My share")
                  Spacer()
                  Text("\(Int(userSharePercent.rounded()))%")
                    .foregroundStyle(.secondary)
                }
                Slider(value: $userSharePercent, in: 0...100, step: 1)
              }
            }
          }

          Spacer(minLength: 80)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
      }
      .scrollDismissesKeyboard(.interactively)

      FormActionBar(
        primaryLabel: "Save",
        isDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ) {
        let normalizedAmount = plannedAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount: Double
        if normalizedAmount.isEmpty {
          amount = 0
        } else if let parsed = Double(normalizedAmount.replacingOccurrences(of: ",", with: ".")) {
          amount = parsed
        } else {
          validationMessage = "Enter a valid amount (for example: 120 or 120.50)."
          return
        }
        validationMessage = nil
        onSave(
          BudgetPlanItemDraft(
            itemID: itemID,
            placeholderItemID: placeholderItemID,
            title: title,
            plannedAmount: amount,
            pillar: pillar,
            splitMode: splitMode,
            userSharePercent: splitMode == .personal ? 100 : userSharePercent
          )
        )
        successFeedbackTrigger += 1
        dismiss()
      }
    }
    .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
    .presentationDragIndicator(.visible)
    .appSensoryFeedback(success: successFeedbackTrigger)
  }
}

private struct RecordSpendSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  let monthTitle: String
  let initialPillar: BudgetPillar
  let availableItems: [BudgetPlanItem]
  let onSave: (BudgetActivityDraft) -> Void

  @State private var title = ""
  @State private var amount = ""
  @State private var pillar: BudgetPillar
  @State private var occurredOn: Date
  @State private var linkedPlanItemID: UUID?
  @State private var splitMode: ExpenseSplitMode = .personal
  @State private var userSharePercent: Double = 100
  @FocusState private var isAmountFocused: Bool
  @State private var successFeedbackTrigger = 0

  init(
    monthTitle: String,
    selectedMonthStart: Date,
    initialPillar: BudgetPillar = .fundamentals,
    availableItems: [BudgetPlanItem],
    onSave: @escaping (BudgetActivityDraft) -> Void
  ) {
    self.monthTitle = monthTitle
    self.initialPillar = initialPillar
    self.availableItems = availableItems
    self.onSave = onSave
    _pillar = State(initialValue: initialPillar)
    _occurredOn = State(initialValue: Self.defaultDate(for: selectedMonthStart))
  }

  var body: some View {
    VStack(spacing: 0) {
      FormSheetHeader(
        title: "Record Spend",
        subtitle: monthTitle,
        onDismiss: { dismiss() }
      )

      ScrollView {
        VStack(spacing: 16) {
          // Month tag
          HStack {
            FormInfoTag(text: monthTitle, icon: "calendar")
            Spacer()
          }

          FormCard(title: "Spend") {
            FormTextField(
              icon: "text.cursor",
              iconColor: AppTheme.Colors.tint(for: colorScheme),
              placeholder: "Title",
              text: $title,
              autocapitalization: .words,
              disableAutocorrection: true
            )

            FormDivider()

            FormTextField(
              icon: "dollarsign.circle",
              iconColor: AppTheme.Colors.secondaryTint(for: colorScheme),
              placeholder: "Amount",
              text: $amount,
              keyboardType: .decimalPad
            )
            .focused($isAmountFocused)

            FormDivider()

            FormRow(icon: "calendar", iconColor: .orange, label: "Date") {
              DatePicker("", selection: $occurredOn, displayedComponents: .date)
                .labelsHidden()
            }
          }

          FormCard(title: "Category") {
            FormRow(icon: "square.stack.3d.up", iconColor: .purple, label: "Pillar") {
              Picker("Pillar", selection: $pillar) {
                ForEach(BudgetPillar.allCases) { pillar in
                  Text(pillar.title).tag(pillar)
                }
              }
              .labelsHidden()
            }

            FormDivider()

            FormRow(icon: "link", iconColor: AppTheme.Colors.tint(for: colorScheme), label: "Link to plan") {
              Picker("Link", selection: $linkedPlanItemID) {
                Text("None").tag(UUID?.none)
                ForEach(filteredItems) { item in
                  Text(item.title).tag(Optional(item.id))
                }
              }
              .labelsHidden()
            }
          }

          FormCard(title: "Split") {
            FormRow(icon: "person.2", iconColor: .green, label: "Mode") {
              Picker("Mode", selection: $splitMode) {
                Text("Personal").tag(ExpenseSplitMode.personal)
                Text("Shared").tag(ExpenseSplitMode.shared)
              }
              .labelsHidden()
            }

            if splitMode == .shared {
              FormDivider()
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text("My share")
                  Spacer()
                  Text("\(Int(userSharePercent.rounded()))%")
                    .foregroundStyle(.secondary)
                }
                Slider(value: $userSharePercent, in: 0...100, step: 1)
              }
            }
          }

          Spacer(minLength: 80)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
      }
      .scrollDismissesKeyboard(.interactively)

      FormActionBar(
        primaryLabel: "Save",
        isDisabled: parseMonetaryValue(amount) == nil
          || (
            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              && linkedPlanItemID == nil
          )
      ) {
        guard let parsedAmount = parseMonetaryValue(amount) else {
          return
        }

        let resolvedTitle =
          title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          ? filteredItems.first(where: { $0.id == linkedPlanItemID })?.title ?? ""
          : title

        onSave(
          BudgetActivityDraft(
            title: resolvedTitle,
            amount: parsedAmount,
            pillar: pillar,
            occurredOn: occurredOn,
            linkedPlanItemID: linkedPlanItemID,
            splitMode: splitMode,
            userSharePercent: splitMode == .personal ? 100 : userSharePercent
          )
        )
        successFeedbackTrigger += 1
        dismiss()
      }
    }
    .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
    .presentationDragIndicator(.visible)
    .appSensoryFeedback(success: successFeedbackTrigger)
    .onChange(of: linkedPlanItemID) { newValue in
      guard let newValue, let item = availableItems.first(where: { $0.id == newValue }) else { return }
      splitMode = item.splitMode
      userSharePercent = item.userSharePercent
    }
  }

  private var filteredItems: [BudgetPlanItem] {
    availableItems.filter { $0.pillar == pillar }
  }

  private static func defaultDate(for monthStart: Date) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    let today = Date()
    let day = calendar.component(.day, from: today)
    let monthRange = calendar.range(of: .day, in: .month, for: monthStart)
    let maxDay = monthRange?.count ?? 28
    let clampedDay = min(day, maxDay)
    let comps = calendar.dateComponents([.year, .month], from: monthStart)
    return calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: clampedDay)) ?? monthStart
  }

  private func parseMonetaryValue(_ raw: String) -> Double? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let filtered = trimmed.filter { $0.isNumber || $0 == "," || $0 == "." }
    guard !filtered.isEmpty else { return nil }

    let characters = Array(filtered)
    let separatorIndexes = characters.indices.filter { characters[$0] == "," || characters[$0] == "." }

    if separatorIndexes.isEmpty {
      return Double(filtered)
    }

    if separatorIndexes.count == 1 {
      let separatorIndex = separatorIndexes[0]
      let leadingDigits = separatorIndex
      let trailingDigits = characters.count - separatorIndex - 1
      if leadingDigits > 0 && trailingDigits == 3 {
        let normalized = filtered
          .replacingOccurrences(of: ",", with: "")
          .replacingOccurrences(of: ".", with: "")
        return Double(normalized)
      }
    }

    let decimalSeparator = characters[separatorIndexes.last!]
    var normalized = ""
    var consumedDecimal = false

    for character in characters {
      if character.isNumber {
        normalized.append(character)
        continue
      }

      if (character == "," || character == ".")
          && character == decimalSeparator
          && !consumedDecimal
      {
        normalized.append(".")
        consumedDecimal = true
      }
    }

    guard normalized != "." else { return nil }
    return Double(normalized)
  }
}

private struct HouseholdPartnerEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var name: String

  let onSave: (String?) -> Void

  init(currentName: String, onSave: @escaping (String?) -> Void) {
    _name = State(initialValue: currentName)
    self.onSave = onSave
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Partner") {
          TextField("Name", text: $name)
        }
      }
      .navigationTitle("Household Partner")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            onSave(trimmed.isEmpty ? nil : trimmed)
            dismiss()
          }
        }
      }
    }
  }
}

// MARK: - Native Feel Components

struct ExpensesCircularOverviewCard: View {
  let leftAmount: Double
  let totalAmount: Double
  @State private var progress: Double = 0
  
  var body: some View {
    VStack {
      ZStack {
        Circle()
          .stroke(Color.white.opacity(0.1), lineWidth: 20)
        
        Circle()
          .trim(from: 0, to: progress)
          .stroke(
            AngularGradient(
              gradient: Gradient(colors: [
                Color(red: 0.7, green: 0.3, blue: 1.0), // Purple at top
                Color(red: 0.9, green: 0.4, blue: 0.8), // Pink at right
                Color(red: 0.5, green: 0.3, blue: 1.0), // Purple at bottom
                Color(red: 0.2, green: 0.6, blue: 1.0), // Blue at left
                Color(red: 0.7, green: 0.3, blue: 1.0)  // Purple at top
              ]),
              center: .center,
              startAngle: .degrees(-90),
              endAngle: .degrees(270)
            ),
            style: StrokeStyle(lineWidth: 20, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
        
        VStack(spacing: 8) {
          Text("Monthly Budget")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(leftAmount.currency)
              .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Left")
              .font(.title2)
          }
          
          Text("of \(totalAmount.currency)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .frame(height: 260)
      .padding(.horizontal, 40)
      .padding(.vertical, 20)
    }
    .onAppear {
      withAnimation(.spring(response: 1.5, dampingFraction: 0.8).delay(0.2)) {
        progress = totalAmount > 0 ? max(0, min(1, leftAmount / totalAmount)) : 0
      }
    }
  }
}

struct SmartSuggestionsCard: View {
  let suggestion: ReportSuggestionResponse?
  let isLoading: Bool
  let isUnavailable: Bool
  let onDismiss: (ReportSuggestionResponse) -> Void

  @State private var selectedSuggestion: ReportSuggestionResponse?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 8) {
        Image(systemName: "lightbulb.fill")
          .foregroundStyle(.yellow)
          .font(.title3)
        Text("Smart Suggestions")
          .font(.headline)
      }

      if isLoading {
        VStack(alignment: .leading, spacing: 12) {
          Text("Loading suggestion")
            .font(.subheadline)
          RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.18))
            .frame(height: 12)
          RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.18))
            .frame(height: 12)
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.14))
            .frame(height: 42)
        }
        .redacted(reason: .placeholder)
        .shimmer()
      } else if let suggestion {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 8) {
            Text(suggestion.severity.rawValue.capitalized)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.white)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(severityColor(suggestion.severity), in: Capsule())
            Text(suggestion.monthStart)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Text(suggestion.title)
            .font(.headline)
            .foregroundStyle(.primary)

          Text(suggestion.message)
            .font(.subheadline)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)

          Text("Potential savings: \(suggestion.recommendedSavings.currency)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(severityColor(suggestion.severity))
        }
        .transition(.asymmetric(insertion: .scale(scale: 0.98).combined(with: .opacity), removal: .opacity))

        HStack(spacing: 12) {
          Button {
            selectedSuggestion = suggestion
          } label: {
            Text("View Details")
              .font(.subheadline.weight(.semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(Color.white.opacity(0.1))
              .cornerRadius(12)
              .foregroundStyle(.white)
          }

          Button {
            onDismiss(suggestion)
          } label: {
            Text("Dismiss")
              .font(.subheadline.weight(.semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(Color.white.opacity(0.1))
              .cornerRadius(12)
              .foregroundStyle(.white)
          }
        }
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text(isUnavailable ? "Unavailable" : "No suggestions right now")
            .font(.subheadline.weight(.semibold))
          Text(isUnavailable ? "-- / no data" : "You're all caught up for this period.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(20)
    .background(Color(uiColor: .secondarySystemGroupedBackground))
    .cornerRadius(20)
    .animation(.easeOut(duration: 0.25), value: isLoading)
    .sheet(item: $selectedSuggestion) { suggestion in
      SuggestionDetailSheet(suggestion: suggestion)
    }
  }

  private func severityColor(_ severity: ReportSuggestionSeverity) -> Color {
    switch severity {
    case .high:
      return .red
    case .medium:
      return .orange
    case .low:
      return .green
    }
  }
}

private struct SuggestionDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  let suggestion: ReportSuggestionResponse

  var body: some View {
    NavigationStack {
      List {
        Section("Summary") {
          LabeledContent("Category", value: suggestion.category.rawValue)
          LabeledContent("Month", value: suggestion.monthStart)
          LabeledContent("Recommended savings", value: suggestion.recommendedSavings.currency)
        }
        if suggestion.detailPayload.isEmpty == false {
          Section("Details") {
            ForEach(suggestion.detailPayload.keys.sorted(), id: \.self) { key in
              LabeledContent(key, value: suggestion.detailPayload[key] ?? "")
            }
          }
        }
      }
      .navigationTitle(suggestion.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}

struct RecentTransactionsList: View {
  let activities: [BudgetActivity]
  
  private func relativeDateString(from date: Date) -> String {
      let calendar = Calendar.current
      if calendar.isDateInToday(date) { return "Today" }
      if calendar.isDateInYesterday(date) { return "Yesterday" }
      let formatter = DateFormatter()
      formatter.dateFormat = "MMM d"
      return formatter.string(from: date)
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Recent Transactions")
        .font(.title2.bold())
        .padding(.horizontal, 4)
      
      VStack(spacing: 0) {
        if activities.isEmpty {
          Text("No recent transactions.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding()
        } else {
          ForEach(activities.prefix(5)) { activity in
            HStack(spacing: 16) {
              Circle()
                .fill(activity.pillar.color(for: .dark))
                .frame(width: 48, height: 48)
                .overlay(
                  Image(systemName: activity.pillar.symbol)
                    .foregroundStyle(.white)
                    .font(.title3)
                )
              
              VStack(alignment: .leading, spacing: 4) {
                Text(activity.pillar.title)
                  .font(.headline)
                Text(activity.title)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
                Text(relativeDateString(from: activity.occurredOn))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              
              Spacer()
              
              Text("-\(activity.amount.currency)")
                .font(.headline)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            
            if activity.id != activities.prefix(5).last?.id {
              Divider()
                .background(Color.white.opacity(0.1))
                .padding(.leading, 80)
            }
          }
        }
      }
      .background(Color(uiColor: .secondarySystemGroupedBackground))
      .cornerRadius(20)
    }
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
