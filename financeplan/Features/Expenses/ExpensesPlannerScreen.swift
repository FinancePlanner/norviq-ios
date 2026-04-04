import Charts
import SwiftUI

struct ExpensesPlannerScreen: View {
  @Binding var isSettingsPresented: Bool
  @ObservedObject var viewModel: BudgetPlannerViewModel

  @Environment(\.colorScheme) private var colorScheme
  @State private var isProfilePresented = false
  @State private var isSalaryEditorPresented = false
  @State private var isTargetEditorPresented = false
  @State private var isActivitySheetPresented = false
  @State private var itemDraft: BudgetPlanItemDraft?
  @State private var itemToDelete: BudgetPlanItem?
  @State private var destructiveFeedbackTrigger = 0

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          ExpensesYearOverviewCard(
            selectedYear: selectedYearBinding,
            availableYears: viewModel.availableYears,
            totalSpent: viewModel.selectedYearActualTotal,
            averageSpent: viewModel.selectedYearAverageActual,
            lastMonthLabel: viewModel.selectedYearLastMonthLabel,
            chartPoints: viewModel.selectedYearChartPoints
          )

          ExpensesMonthDetailListCard(
            selectedMonthStart: selectedMonthBinding,
            summaries: viewModel.selectedYearSummaries
          )

          SelectedMonthPlannerCard(
            monthTitle: viewModel.selectedMonthDisplayTitle,
            onPlanNextMonth: viewModel.createNextMonthPlan
          )

          PlannerSalaryCard(
            monthTitle: viewModel.selectedMonthDisplayTitle,
            netSalary: viewModel.selectedMonthSnapshot.netSalary,
            allocated: viewModel.selectedMonthPlannedTotal,
            spent: viewModel.selectedMonthActualTotal,
            leftToAllocate: viewModel.selectedMonthAvailableAfterPillarPlan,
            leftAfterSpending: viewModel.selectedMonthLeftAfterSpending
          )

          PillarAllocationTableCard(
            monthTitle: viewModel.selectedMonthDisplayTitle,
            summaries: viewModel.selectedMonthSummaries
          )

          ForEach(BudgetPillar.allCases) { pillar in
            PillarPlannerCard(
              pillar: pillar,
              items: viewModel.items(for: pillar),
              summary: viewModel.selectedMonthSummaries.first { $0.pillar == pillar }
                ?? PillarPlanningSummary(
                  pillar: pillar,
                  targetAmount: 0,
                  plannedAmount: 0,
                  actualAmount: 0,
                  unplannedActualAmount: 0
                ),
              actualAmount: { item in
                viewModel.actualAmount(for: item)
              },
              onEdit: { item in
                itemDraft = BudgetPlanItemDraft(
                  itemID: item.id,
                  title: item.title,
                  plannedAmount: item.plannedAmount,
                  pillar: item.pillar
                )
              },
              onAdd: {
                itemDraft = BudgetPlanItemDraft(
                  itemID: nil,
                  title: "",
                  plannedAmount: 0,
                  pillar: pillar
                )
              },
              onDelete: { item in
                itemToDelete = item
              }
            )
          }

          RecentActivityCard(activities: viewModel.selectedMonthActivities)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
      }
      .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
      .navigationTitle("Expenses")
      .navigationBarTitleDisplayMode(.large)
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

              Button("Adjust net salary", systemImage: "eurosign.circle") {
                isSalaryEditorPresented = true
              }

              Button("Adjust pillar targets", systemImage: "slider.horizontal.3") {
                isTargetEditorPresented = true
              }

              Button("Add planned item", systemImage: "plus.rectangle.on.folder") {
                itemDraft = BudgetPlanItemDraft(
                  itemID: nil,
                  title: "",
                  plannedAmount: 0,
                  pillar: .fundamentals
                )
              }

              Button("Record spend", systemImage: "plus.circle") {
                isActivitySheetPresented = true
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

            AppTopBarProfileButton(
              isUserMenuPresented: isProfilePresented,
              onTap: { isProfilePresented = true }
            )
            .accessibilityLabel("Open profile")
          }
        }
      }
      .sheet(isPresented: $isProfilePresented) {
        UserProfileView()
      }
      .sheet(isPresented: $isSalaryEditorPresented) {
        NetSalaryEditorSheet(
          currentValue: viewModel.selectedMonthSnapshot.netSalary,
          monthTitle: viewModel.selectedMonthDisplayTitle,
          onSave: viewModel.updateNetSalary
        )
      }
      .sheet(isPresented: $isTargetEditorPresented) {
        PillarTargetsEditorSheet(
          monthTitle: viewModel.selectedMonthDisplayTitle,
          currentShares: viewModel.selectedMonthSnapshot.targetShares,
          onSave: viewModel.updateTargetShares
        )
      }
      .sheet(item: $itemDraft) { draft in
        PlanItemEditorSheet(draft: draft) { updatedDraft in
          viewModel.addOrUpdatePlanItem(updatedDraft)
        }
      }
      .sheet(isPresented: $isActivitySheetPresented) {
        RecordSpendSheet(
          monthTitle: viewModel.selectedMonthDisplayTitle,
          availableItems: viewModel.selectedMonthSnapshot.items
        ) { draft in
          viewModel.recordExpense(draft)
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
  let leftToAllocate: Double
  let leftAfterSpending: Double

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        Text("Net salary plan")
          .typography(.small, weight: .semibold)

        Text(monthTitle)
          .typography(.nano)
          .foregroundStyle(.secondary)

        HStack(alignment: .lastTextBaseline, spacing: 8) {
          Text(netSalary.currency)
            .typography(.hero, weight: .bold)
            .contentTransition(.numericText())
          Text("monthly take-home")
            .typography(.small)
            .foregroundStyle(.secondary)
        }

        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
          GridRow {
            SummaryMetric(title: "Planned", value: allocated.currency)
            SummaryMetric(title: "Spent", value: spent.currency)
          }

          GridRow {
            SummaryMetric(
              title: "Available after plan",
              value: leftToAllocate.currency,
              accent: leftToAllocate >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger
            )
            SummaryMetric(
              title: "Available after spend",
              value: leftAfterSpending.currency,
              accent: leftAfterSpending >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger
            )
          }
        }
      }
    }
  }
}

private struct PillarAllocationTableCard: View {
  let monthTitle: String
  let summaries: [PillarPlanningSummary]

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        Text("Where your salary goes")
          .typography(.small, weight: .semibold)

        Text(monthTitle)
          .typography(.nano)
          .foregroundStyle(.secondary)

        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
          GridRow {
            PlannerTableHeader("Pillar")
            PlannerTableHeader("Goal")
            PlannerTableHeader("Plan")
            PlannerTableHeader("Actual")
            PlannerTableHeader("Left")
          }

          ForEach(summaries) { summary in
            GridRow {
              Text(summary.pillar.title)
                .typography(.nano, weight: .semibold)
              Text(summary.targetAmount.currency)
                .typography(.nano)
              Text(summary.plannedAmount.currency)
                .typography(.nano)
              Text(summary.actualAmount.currency)
                .typography(.nano)
              Text(summary.availableToPlan.currency)
                .typography(.nano, weight: .semibold)
                .foregroundStyle(
                  summary.availableToPlan >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger
                )
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
        Section("Net Salary") {
          Text(monthTitle)
            .foregroundStyle(.secondary)

          TextField("Net salary", text: $value)
            .keyboardType(.decimalPad)
            .focused($isValueFocused)
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Adjust Salary")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            guard let parsed = Double(value.replacingOccurrences(of: ",", with: ".")) else { return }
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
  @FocusState private var isAmountFocused: Bool
  @State private var successFeedbackTrigger = 0

  let itemID: UUID?
  let onSave: (BudgetPlanItemDraft) -> Void

  init(draft: BudgetPlanItemDraft, onSave: @escaping (BudgetPlanItemDraft) -> Void) {
    _title = State(initialValue: draft.title)
    _plannedAmount = State(
      initialValue: draft.plannedAmount == 0
        ? ""
        : draft.plannedAmount.formatted(.number.precision(.fractionLength(2)))
    )
    _pillar = State(initialValue: draft.pillar)
    self.itemID = draft.itemID
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
        guard let amount = Double(plannedAmount.replacingOccurrences(of: ",", with: ".")) else {
          return
        }
        onSave(
          BudgetPlanItemDraft(
            itemID: itemID,
            title: title,
            plannedAmount: amount,
            pillar: pillar
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
  let availableItems: [BudgetPlanItem]
  let onSave: (BudgetActivityDraft) -> Void

  @State private var title = ""
  @State private var amount = ""
  @State private var pillar: BudgetPillar = .fundamentals
  @State private var occurredOn = Date()
  @State private var linkedPlanItemID: UUID?
  @FocusState private var isAmountFocused: Bool
  @State private var successFeedbackTrigger = 0

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

          Spacer(minLength: 80)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
      }
      .scrollDismissesKeyboard(.interactively)

      FormActionBar(
        primaryLabel: "Save",
        isDisabled: Double(amount.replacingOccurrences(of: ",", with: ".")) == nil
          || (
            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              && linkedPlanItemID == nil
          )
      ) {
        guard let parsedAmount = Double(amount.replacingOccurrences(of: ",", with: ".")) else {
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
            linkedPlanItemID: linkedPlanItemID
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

  private var filteredItems: [BudgetPlanItem] {
    availableItems.filter { $0.pillar == pillar }
  }
}

