import Charts
import SwiftUI

struct ExpensesPlannerScreen: View {
  @ObservedObject var viewModel: BudgetPlannerViewModel

  @Environment(\.colorScheme) private var colorScheme
  @State private var isSalaryEditorPresented = false
  @State private var isTargetEditorPresented = false
  @State private var isActivitySheetPresented = false
  @State private var itemDraft: BudgetPlanItemDraft?
  @State private var itemToDelete: BudgetPlanItem?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          PlannerMonthCard(
            selectedMonthStart: selectedMonthBinding,
            availableMonths: viewModel.availableMonths,
            onPlanNextMonth: viewModel.createNextMonthPlan
          )

          PlannerSalaryCard(
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

          GlassCard {
            VStack(alignment: .leading, spacing: 16) {
              Text("Six-month spending trend")
                .typography(.small, weight: .semibold)

              Chart(viewModel.monthlySummaries.suffix(6)) { summary in
                LineMark(
                  x: .value("Month", summary.shortLabel),
                  y: .value("Actual", summary.actual)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                .lineStyle(.init(lineWidth: 3))

                PointMark(
                  x: .value("Month", summary.shortLabel),
                  y: .value("Actual", summary.actual)
                )
                .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
              }
              .frame(height: 180)
              .chartYAxis {
                AxisMarks(position: .leading)
              }

              Text("This line tracks how much of your salary is actually leaving each month after your three-pillar plan is set.")
                .typography(.nano)
                .foregroundStyle(.secondary)
            }
          }

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
      .background(MeshGradientBackground())
      .navigationTitle("Expenses")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
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
            Image(systemName: "plus.circle.fill")
              .font(.title3.weight(.semibold))
              .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          }
          .accessibilityLabel("Expense actions")
        }
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
          viewModel.removePlanItem(item.id)
        }
      } message: { item in
        Text("Remove \(item.title) from the \(item.pillar.title) plan for \(viewModel.selectedMonthDisplayTitle).")
      }
    }
  }

  private var selectedMonthBinding: Binding<Date> {
    Binding(
      get: { viewModel.selectedMonthStart },
      set: { viewModel.selectMonth($0) }
    )
  }
}

private struct PlannerMonthCard: View {
  @Binding var selectedMonthStart: Date
  let availableMonths: [Date]
  let onPlanNextMonth: () -> Void

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Monthly planner")
              .typography(.small, weight: .semibold)
            Text("Duplicate a month, then adjust the pillars as life changes.")
              .typography(.nano)
              .foregroundStyle(.secondary)
          }

          Spacer()
        }

        Picker("Month", selection: $selectedMonthStart) {
          ForEach(availableMonths, id: \.self) { month in
            Text(month.formatted(.dateTime.month(.wide).year()))
              .tag(month)
          }
        }
        .pickerStyle(.menu)

        Button {
          onPlanNextMonth()
        } label: {
          Label("Plan next month", systemImage: "calendar.badge.plus")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
      }
    }
  }
}

private struct PlannerSalaryCard: View {
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

        HStack(alignment: .lastTextBaseline, spacing: 8) {
          Text(netSalary.currency)
            .typography(.hero, weight: .bold)
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
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(item.title)
          .typography(.small, weight: .semibold)
        Text("Planned \(item.plannedAmount.currency) • Spent \(actualAmount.currency)")
          .typography(.nano)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Text(variance.currency)
        .typography(.small, weight: .semibold)
        .foregroundStyle(variance >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger)

      Menu {
        Button("Edit", systemImage: "pencil", action: onEdit)
        Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
      } label: {
        Image(systemName: "ellipsis.circle")
          .font(.body)
          .foregroundStyle(.secondary)
      }
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
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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
        }
      }
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
            dismiss()
          }
        }
      }
    }
  }
}

private struct PillarTargetsEditorSheet: View {
  @Environment(\.dismiss) private var dismiss

  let monthTitle: String
  let onSave: ([BudgetPillar: Double]) -> Void

  @State private var fundamentals: Double
  @State private var futureYou: Double
  @State private var fun: Double

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
        }
      }
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
            dismiss()
          }
        }
      }
    }
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

  @State private var title: String
  @State private var plannedAmount: String
  @State private var pillar: BudgetPillar

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
    NavigationStack {
      Form {
        TextField("Name", text: $title)
        TextField("Planned amount", text: $plannedAmount)
          .keyboardType(.decimalPad)

        Picker("Pillar", selection: $pillar) {
          ForEach(BudgetPillar.allCases) { pillar in
            Text(pillar.title).tag(pillar)
          }
        }
      }
      .navigationTitle(itemID == nil ? "Add Planned Item" : "Edit Planned Item")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
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
            dismiss()
          }
          .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}

private struct RecordSpendSheet: View {
  @Environment(\.dismiss) private var dismiss

  let monthTitle: String
  let availableItems: [BudgetPlanItem]
  let onSave: (BudgetActivityDraft) -> Void

  @State private var title = ""
  @State private var amount = ""
  @State private var pillar: BudgetPillar = .fundamentals
  @State private var occurredOn = Date()
  @State private var linkedPlanItemID: UUID?

  var body: some View {
    NavigationStack {
      Form {
        Section("Spend") {
          Text(monthTitle)
            .foregroundStyle(.secondary)

          TextField("Title", text: $title)
          TextField("Amount", text: $amount)
            .keyboardType(.decimalPad)

          Picker("Pillar", selection: $pillar) {
            ForEach(BudgetPillar.allCases) { pillar in
              Text(pillar.title).tag(pillar)
            }
          }

          Picker("Link to plan", selection: $linkedPlanItemID) {
            Text("None").tag(UUID?.none)
            ForEach(filteredItems) { item in
              Text(item.title).tag(Optional(item.id))
            }
          }

          DatePicker("Date", selection: $occurredOn, displayedComponents: .date)
        }
      }
      .navigationTitle("Record Spend")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
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
            dismiss()
          }
          .disabled(
            Double(amount.replacingOccurrences(of: ",", with: ".")) == nil
              || (
                title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && linkedPlanItemID == nil
              )
          )
        }
      }
    }
  }

  private var filteredItems: [BudgetPlanItem] {
    availableItems.filter { $0.pillar == pillar }
  }
}
