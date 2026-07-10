import Charts
import SwiftUI
import StockPlanShared
import Factory

struct ExpensesPlannerScreen: View {
  @Binding var isSettingsPresented: Bool
  @Bindable var viewModel: BudgetPlannerViewModel

  @Environment(\.colorScheme) private var colorScheme
  @InjectedObservable(\Container.billingManager) private var billingManager
  @State private var isSalaryEditorPresented = false
  @State private var isTargetEditorPresented = false
  @State private var isActivitySheetPresented = false
  @State private var isPartnerEditorPresented = false
  @State private var isRecurringManagerPresented = false
  @State private var recurringTemplateToLog: RecurringTemplateResponse?
  @State private var itemDraft: BudgetPlanItemDraft?
  @State private var presentedPlanItemDraft: BudgetPlanItemDraft?
  @State private var didSavePresentedPlanItemDraft = false
  @State private var itemToDelete: BudgetPlanItem?
  @State private var activityToEdit: BudgetActivity?
  @State private var activityToDelete: BudgetActivity?
  @State private var recordSpendInitialPillar: BudgetPillar = .fundamentals
  @State private var destructiveFeedbackTrigger = 0
  @State private var isPaywallPresented = false

  private var isShowingLoadingState: Bool {
    viewModel.isLoading && viewModel.monthlySnapshots.isEmpty
  }

  private var loadErrorMessage: String? {
    guard viewModel.monthlySnapshots.isEmpty else { return nil }
    return viewModel.errorMessage
  }

  private var shouldShowEmptyState: Bool {
    !viewModel.isLoading && viewModel.monthlySnapshots.isEmpty
  }

  private var itemDeleteBinding: Binding<Bool> {
    Binding(
      get: { itemToDelete != nil },
      set: { if !$0 { itemToDelete = nil } }
    )
  }

  private var expenseDeleteBinding: Binding<Bool> {
    Binding(
      get: { activityToDelete != nil },
      set: { if !$0 { activityToDelete = nil } }
    )
  }

  var body: some View {
    NavigationStack {
      rootContent
      .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
      .navigationTitle("Expenses and Budgeting")
      .navigationBarTitleDisplayMode(.inline)
      .task {
        await initialLoad()
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
          toolbarActions
        }
      }
      .sheet(isPresented: $isSalaryEditorPresented, content: salaryEditorSheet)
      .sheet(isPresented: $isTargetEditorPresented, content: targetEditorSheet)
      .sheet(item: $itemDraft, onDismiss: handlePlanItemDismiss) { draft in
        planItemEditorSheet(for: draft)
      }
      .sheet(isPresented: $isActivitySheetPresented, onDismiss: resetRecordSpendInitialPillar, content: recordSpendSheet)
      .sheet(item: $activityToEdit) { activity in
        editActivitySheet(for: activity)
      }
      .sheet(isPresented: $isPartnerEditorPresented, content: householdPartnerSheet)
      .sheet(item: $recurringTemplateToLog) { template in
        recurringTemplateSheet(for: template)
      }
      .sheet(isPresented: $isRecurringManagerPresented, content: recurringManagerSheet)
      .sheet(isPresented: $isPaywallPresented) {
        PaywallView(billingManager: billingManager)
      }
      .confirmationDialog(
        "Delete planned item?",
        isPresented: itemDeleteBinding,
        presenting: itemToDelete
      ) { item in
        Button("Delete", role: .destructive) {
          deletePlannedItem(item)
        }
      } message: { item in
        Text("Remove \(item.title) from the \(item.pillar.title) plan for \(viewModel.selectedMonthDisplayTitle).")
      }
      .confirmationDialog(
        "Delete expense?",
        isPresented: expenseDeleteBinding,
        presenting: activityToDelete
      ) { activity in
        Button("Delete", role: .destructive) {
          deleteExpense(activity)
        }
      } message: { activity in
        Text("Remove \(activity.title) from \(viewModel.selectedMonthDisplayTitle).")
      }
    }
    .appSensoryFeedback(destructive: destructiveFeedbackTrigger)
  }

  @ViewBuilder
  private var rootContent: some View {
    if isShowingLoadingState {
          ExpensesSkeletonView()
    } else if let loadErrorMessage {
      ErrorRetryView(message: loadErrorMessage, onRetry: retryLoad)
    } else if shouldShowEmptyState {
      EmptyStateView(
        icon: "chart.bar.doc.horizontal",
        title: "No budget yet",
        message: "Set up your first monthly budget to get started.",
        ctaLabel: "Add Budget",
        onCTA: presentSalaryEditor
      )
    } else {
      mainScrollView
    }
  }

  private var toolbarActions: some View {
    HStack(spacing: 8) {
      Button(action: presentRecordSpend) {
        Image(systemName: "plus.circle")
          .font(.system(size: 16, weight: .semibold))
      }
.buttonStyle(.borderedProminent)
      .tint(AppTheme.Colors.tint(for: colorScheme))
      .accessibilityLabel("Record spend")
      .accessibilityIdentifier("expenses.recordSpendButton")

      Menu {
        Button("Plan next month", systemImage: "calendar.badge.plus", action: viewModel.createNextMonthPlan)
        Button("Adjust monthly budget", systemImage: "eurosign.circle", action: presentSalaryEditor)
        Button("Adjust pillar targets", systemImage: "slider.horizontal.3", action: presentTargetEditor)
        Button("Add pillar", systemImage: "square.stack.3d.up", action: presentTargetEditor)
        Button("Record spend", systemImage: "plus.circle", action: presentRecordSpend)
        Button {
          if billingManager.isPro {
            presentPartnerEditor()
          } else {
            isPaywallPresented = true
          }
        } label: {
          Label("Household partner", systemImage: "person.2")
        }
        Divider()
        Button("Delete this month plan", systemImage: "trash", role: .destructive, action: viewModel.deleteCurrentSnapshot)
      } label: {
        Image(systemName: "ellipsis.circle")
          .font(.system(size: 16, weight: .semibold))
      }
.buttonStyle(.borderedProminent)
      .tint(AppTheme.Colors.tint(for: colorScheme))
      .accessibilityLabel("Expense actions")

      Button(action: openSettings) {
        Image(systemName: "gearshape")
          .font(.system(size: 16, weight: .semibold))
      }
.buttonStyle(.borderedProminent)
      .tint(AppTheme.Colors.tint(for: colorScheme))
      .accessibilityLabel("Open settings")
    }
  }

  private var mainScrollView: some View {
    ScrollView {
      VStack(spacing: 24) {
        ExpensesCircularOverviewCard(
          leftAmount: viewModel.selectedMonthLeftAfterSpending,
          totalAmount: viewModel.selectedMonthSnapshot?.netSalary ?? 0
        )
        .padding(.top, 10)

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

        MissingBudgetAlert(
          netSalary: viewModel.selectedMonthSnapshot?.netSalary ?? 0,
          hasSnapshot: viewModel.selectedMonthSnapshot != nil,
          monthTitle: viewModel.selectedMonthDisplayTitle,
          isSalaryEditorPresented: $isSalaryEditorPresented
        )

        MonthlyPlanItemsCard(
          monthTitle: viewModel.selectedMonthDisplayTitle,
          items: (viewModel.selectedMonthSnapshot?.items ?? []).sorted {
            if $0.pillar == $1.pillar {
              return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.pillar.rawValue < $1.pillar.rawValue
          },
          recurringTemplates: viewModel.recurringTemplates,
          onAdd: { presentNewPlanItemDraft(pillar: viewModel.preferredInitialPillar) },
          onEdit: { item in presentExistingPlanItemDraft(item) },
          onDelete: { item in itemToDelete = item },
          onLogRecurring: { template in recurringTemplateToLog = template },
          onManageRecurring: {
            if billingManager.isPro {
              isRecurringManagerPresented = true
            } else {
              isPaywallPresented = true
            }
          }
        )
        .padding(.horizontal, 16)

        ProGateView(billingManager: billingManager) {
          ExpensesYearOverviewCard(
            selectedYear: selectedYearBinding,
            availableYears: viewModel.availableYears,
            totalSpent: viewModel.selectedYearActualTotal,
            averageSpent: viewModel.selectedYearAverageActual,
            lastMonthLabel: viewModel.selectedYearLastMonthLabel,
            chartPoints: viewModel.selectedYearChartPoints
          )
          .padding(.horizontal, 16)
        }

        PillarAllocationTableCard(
          monthTitle: viewModel.selectedMonthDisplayTitle,
          summaries: viewModel.selectedMonthSummaries
        )
        .padding(.horizontal, 16)

        ProGateView(billingManager: billingManager) {
          SmartSuggestionsCard(
            suggestion: viewModel.topReportSuggestion,
            isLoading: viewModel.isSuggestionsLoading,
            isUnavailable: viewModel.suggestionsUnavailable,
            onDismiss: { suggestion in
              viewModel.dismissSuggestion(suggestion)
            }
          )
          .padding(.horizontal, 16)
        }

        ExpensesByCategoryCard(
          monthTitle: viewModel.selectedMonthDisplayTitle,
          activities: viewModel.selectedMonthActivities,
          summaries: viewModel.selectedMonthSummaries,
          onEdit: { activity in
            activityToEdit = activity
          },
          onDelete: { activity in
            activityToDelete = activity
          }
        )
        .padding(.horizontal, 16)

        NavigationLink {
          BudgetCategoryDetailsScreen(
            viewModel: viewModel,
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
          .clipShape(.rect(cornerRadius: 16))
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(Color.white.opacity(0.05), lineWidth: 1)
          )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
      }
      .padding(.vertical, 10)
      // Center the planner column on iPad instead of stretching edge-to-edge (Guideline 4).
      .maxContentWidth(regularSizeClass: ContentWidth.dense)
    }
    .refreshable {
      await viewModel.load(force: true)
    }
  }

  private func initialLoad() async {
    await viewModel.load()
  }

  private func retryLoad() {
    Task { await viewModel.load(force: true) }
  }

  private func openSettings() {
    isSettingsPresented = true
  }

  private func presentSalaryEditor() {
    isSalaryEditorPresented = true
  }

  private func presentTargetEditor() {
    isTargetEditorPresented = true
  }

  private func presentPartnerEditor() {
    isPartnerEditorPresented = true
  }

  private func presentRecordSpend() {
    recordSpendInitialPillar = viewModel.preferredInitialPillar
    isActivitySheetPresented = true
  }

  private func resetRecordSpendInitialPillar() {
    recordSpendInitialPillar = viewModel.preferredInitialPillar
  }

  private func handlePlanItemDismiss() {
    if !didSavePresentedPlanItemDraft, let draft = presentedPlanItemDraft {
      viewModel.cancelPlanItemDraft(draft)
    }
    didSavePresentedPlanItemDraft = false
    presentedPlanItemDraft = nil
  }

  private func deletePlannedItem(_ item: BudgetPlanItem) {
    destructiveFeedbackTrigger += 1
    viewModel.removePlanItem(item.id)
  }

  private func deleteExpense(_ activity: BudgetActivity) {
    destructiveFeedbackTrigger += 1
    viewModel.removeExpense(activity.id)
  }

  private func salaryEditorSheet() -> some View {
    NetSalaryEditorSheet(
      currentValue: viewModel.selectedMonthSnapshot?.netSalary ?? 0,
      monthTitle: viewModel.selectedMonthDisplayTitle,
      onSave: viewModel.updateNetSalary
    )
  }

  private func targetEditorSheet() -> some View {
    PillarTargetsEditorSheet(
      monthTitle: viewModel.selectedMonthDisplayTitle,
      currentShares: viewModel.selectedMonthSnapshot?.targetShares ?? [:],
      onSave: viewModel.updateTargetShares
    )
  }

  private func planItemEditorSheet(for draft: BudgetPlanItemDraft) -> some View {
    PlanItemEditorSheet(
      draft: draft,
      availablePillars: viewModel.selectedMonthPillars,
      availableCategories: viewModel.categories
    ) { updatedDraft in
      didSavePresentedPlanItemDraft = true
      viewModel.addOrUpdatePlanItem(updatedDraft)
    }
  }

  private func recordSpendSheet() -> some View {
    RecordSpendSheet(
      monthTitle: viewModel.selectedMonthDisplayTitle,
      selectedMonthStart: viewModel.selectedMonthStart,
      editingActivity: nil,
      initialPillar: recordSpendInitialPillar,
      availablePillars: viewModel.selectedMonthPillars,
      availableItems: viewModel.selectedMonthSnapshot?.items ?? [],
      availableCategories: viewModel.categories
    ) { draft in
      await viewModel.recordExpenseAndWait(draft)
    }
  }

  private func editActivitySheet(for activity: BudgetActivity) -> some View {
    RecordSpendSheet(
      monthTitle: viewModel.selectedMonthDisplayTitle,
      selectedMonthStart: viewModel.selectedMonthStart,
      editingActivity: activity,
      initialPillar: activity.pillar,
      availablePillars: viewModel.selectedMonthPillars,
      availableItems: viewModel.selectedMonthSnapshot?.items ?? [],
      availableCategories: viewModel.categories
    ) { draft in
      await viewModel.updateExpenseAndWait(expenseID: activity.id, draft)
    }
  }

  private func householdPartnerSheet() -> some View {
    HouseholdPartnerEditorSheet(
      currentName: viewModel.partnerDisplayName == "Partner" ? "" : viewModel.partnerDisplayName
    ) { name in
      viewModel.updatePartnerDisplayName(name)
    }
  }

  private func recurringTemplateSheet(for template: RecurringTemplateResponse) -> some View {
    let draft = viewModel.draftFromRecurringTemplate(template)
    return RecordSpendSheet(
      monthTitle: viewModel.selectedMonthDisplayTitle,
      selectedMonthStart: viewModel.selectedMonthStart,
      editingActivity: nil,
      initialPillar: template.pillar,
      availablePillars: viewModel.selectedMonthPillars,
      availableItems: viewModel.selectedMonthSnapshot?.items ?? [],
      availableCategories: viewModel.categories,
      prefillDraft: draft
    ) { saveDraft in
      await viewModel.recordExpenseAndWait(saveDraft)
    }
  }

  private func recurringManagerSheet() -> some View {
    RecurringTemplatesManagerSheet(
      templates: viewModel.recurringTemplates,
      availableCategories: viewModel.categories,
      availablePillars: viewModel.selectedMonthPillars,
      onSave: { req, id in viewModel.saveRecurringTemplate(req, templateId: id) },
      onDelete: { id in viewModel.deleteRecurringTemplate(id) }
    )
  }

  private var selectedMonthBinding: Binding<Date> {
    Binding(
      get: { viewModel.selectedMonthStart },
      set: { newValue in
        if billingManager.isPro {
          viewModel.selectMonth(newValue)
        } else {
          isPaywallPresented = true
        }
      }
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

  private func presentExistingPlanItemDraft(_ item: BudgetPlanItem) {
    let draft = BudgetPlanItemDraft(
      itemID: item.id,
      placeholderItemID: nil,
      title: item.title,
      plannedAmount: item.plannedAmount,
      pillar: item.pillar,
      categoryId: item.categoryId,
      splitMode: item.splitMode,
      userSharePercent: item.userSharePercent
    )
    presentedPlanItemDraft = draft
    didSavePresentedPlanItemDraft = false
    itemDraft = draft
  }

  private struct MissingBudgetAlert: View {
  let netSalary: Double
  let hasSnapshot: Bool
  let monthTitle: String
  @Binding var isSalaryEditorPresented: Bool

  var body: some View {
    if netSalary <= 0 {
      GlassCard(cornerRadius: 18) {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(AppTheme.Colors.warning)

          VStack(alignment: .leading, spacing: 6) {
            Text("Set your monthly budget")
              .typography(.small, weight: .semibold)
            Text(hasSnapshot
              ? "Your monthly budget is currently 0. Add salary and side income so spending insights can calculate correctly."
              : "No budget plan for \(monthTitle). Create one or select a different month from the title menu.")
              .typography(.nano)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Button(hasSnapshot ? "Set" : "Create") {
            isSalaryEditorPresented = true
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
        }
      }
      .padding(.horizontal, 16)
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
            .contentTransition(.numericText(value: totalSpent))
            .appAnimation(AppMotion.state, value: totalSpent)

          Text("Avg \(averageSpent.currency) through \(lastMonthLabel)")
            .typography(.nano)
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
            .appAnimation(AppMotion.state, value: averageSpent)
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
              .clipShape(.rect(cornerRadius: 6))
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
.buttonStyle(.bordered)

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
      VStack(alignment: .center, spacing: 20) {
        HStack {
          Text("Monthly Budget Plan")
            .typography(.label, weight: .semibold)
          Spacer()
          Text(monthTitle)
            .typography(.small)
            .foregroundStyle(.secondary)
        }

        VStack(spacing: 6) {
          Text(netSalary.currency)
            .font(.largeTitle.bold())
            .fontDesign(.rounded)
            .contentTransition(.numericText(value: netSalary))
            .appAnimation(AppMotion.state, value: netSalary)
          Text("salary + side income")
            .typography(.small)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)

        Button("Edit monthly budget", action: onEditMonthlyBudget)
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
          .accessibilityIdentifier("expenses.editSalaryButton")

        Divider()

        HStack(spacing: 0) {
          MetricItem(title: "Planned", value: allocated.currency, color: .primary)
          MetricItem(title: "Spent", value: spent.currency, color: .primary)
        }

        Divider()

        HStack(spacing: 0) {
          MetricItem(title: "My plan", value: myPlanned.currency, color: .primary)
          MetricItem(title: "\(partnerName) plan", value: partnerPlanned.currency, color: .primary)
        }

        HStack(spacing: 0) {
          MetricItem(title: "My spend", value: mySpent.currency, color: .primary)
          MetricItem(title: "\(partnerName) spend", value: partnerSpent.currency, color: .primary)
        }

        Divider()

        HStack(spacing: 0) {
          MetricItem(
            title: "Available after plan",
            value: leftToAllocate.currency,
            color: leftToAllocate >= 0 ? .green : .red
          )
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

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GlassCard(cornerRadius: 20) {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("Where your salary goes")
            .typography(.label, weight: .semibold)
          Spacer()
          Text(monthTitle)
            .typography(.small)
            .foregroundStyle(.secondary)
        }

        if summaries.contains(where: { $0.actualAmount > 0 }) {
            Chart(summaries.filter { $0.actualAmount > 0 }) { summary in
                SectorMark(
                    angle: .value("Amount", summary.actualAmount),
                    innerRadius: .ratio(0.65),
                    outerRadius: .ratio(1.0),
                    angularInset: 2.0
                )
                .foregroundStyle(summary.pillar.color(for: colorScheme))
            }
            .frame(height: 200)
            .padding(.vertical, 8)
        }

        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
          GridRow {
            Text("Pillar").typography(.small).foregroundStyle(.secondary)
            Text("Goal").typography(.small).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text("Plan").typography(.small).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text("Actual").typography(.small).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
            Text("Left").typography(.small).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
          }

          Divider()

          ForEach(summaries) { summary in
            GridRow {
              Text(summary.pillar.title)
                .typography(.small)
              Text(summary.targetAmount.currency)
                .typography(.small).foregroundStyle(.secondary)
              Text(summary.plannedAmount.currency)
                .typography(.small).foregroundStyle(.secondary)
              Text(summary.actualAmount.currency)
                .typography(.small).foregroundStyle(.secondary)
              Text(summary.availableToPlan.currency)
                .typography(.small)
                .foregroundStyle(summary.availableToPlan >= 0 ? .green : .red)
            }
            if summary.id != summaries.last?.id {
              Divider()
            }
          }
        }
      }
    }
  }
}

private struct MonthlyPlanItemsCard: View {
  let monthTitle: String
  let items: [BudgetPlanItem]
  let recurringTemplates: [RecurringTemplateResponse]
  let onAdd: () -> Void
  let onEdit: (BudgetPlanItem) -> Void
  let onDelete: (BudgetPlanItem) -> Void
  let onLogRecurring: (RecurringTemplateResponse) -> Void
  let onManageRecurring: () -> Void

  @Environment(\.colorScheme) private var colorScheme
  @State private var editingItemID: UUID?
  @State private var editAmount: String = ""
  @FocusState private var focusedItemID: UUID?
  
  private var groupedItems: [(BudgetPillar, [BudgetPlanItem])] {
    let grouped = Dictionary(grouping: items, by: { $0.pillar })
    return BudgetPillar.sortedForDisplay(grouped.keys).compactMap { pillar in
      guard let items = grouped[pillar], !items.isEmpty else { return nil }
      return (pillar, items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
    }
  }

  var body: some View {
    GlassCard(cornerRadius: 20) {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("Monthly plan items")
            .typography(.label, weight: .semibold)
          Spacer()
          Text(monthTitle)
            .typography(.small)
            .foregroundStyle(.secondary)
        }

        if items.isEmpty {
          ContentUnavailableView {
            Label("No planned items", systemImage: "list.bullet.clipboard")
          } description: {
            Text("Add items to plan your monthly budget")
          } actions: {
            Button("Add First Item") {
              onAdd()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("expenses.addFirstPlanItemButton")
          }
          .padding(.vertical, 8)
          .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else {
          ForEach(groupedItems, id: \.0) { pillar, pillarItems in
            VStack(alignment: .leading, spacing: 0) {
              HStack(spacing: 8) {
                Image(systemName: pillar.symbol)
                  .typography(.small)
                  .foregroundStyle(pillar.color(for: colorScheme))
                  .frame(width: 20)
                
                Text(pillar.title.uppercased())
                  .typography(.nano, weight: .bold)
                  .foregroundStyle(.primary)
                  .tracking(0.5)
                
                Spacer()
                
                let total = pillarItems.reduce(0) { $0 + $1.plannedAmount }
                Text(total.currency)
                  .typography(.nano, weight: .bold)
                  .foregroundStyle(.primary)
              }
              .padding(.bottom, 12)
              
              ForEach(pillarItems) { item in
                VStack(alignment: .leading, spacing: 0) {
                  HStack(alignment: .top, spacing: 12) {
                    Text("│")
                      .font(.system(size: 16, weight: .regular, design: .monospaced))
                      .foregroundStyle(pillar.color(for: colorScheme).opacity(0.4))
                      .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                      HStack {
                        Text(item.title)
                          .font(.subheadline.weight(.medium))
                        
                        Spacer()
                        
                        if editingItemID == item.id {
                          TextField("Amount", text: $editAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .focused($focusedItemID, equals: item.id)
                            .onSubmit { saveInlineEdit(item) }
                            .transition(.scale.combined(with: .opacity))
                          
                          Button("Save") { saveInlineEdit(item) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .transition(.scale.combined(with: .opacity))
                        } else {
                          Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                              startInlineEdit(item)
                            }
                          } label: {
                            Text(item.plannedAmount.currency)
                              .font(.subheadline.weight(.semibold))
                              .contentTransition(.numericText())
                          }
.buttonStyle(.bordered)
                          
                          Menu {
                            Button("Edit", systemImage: "pencil") { onEdit(item) }
                            Button("Delete", systemImage: "trash", role: .destructive) { onDelete(item) }
                          } label: {
                            Image(systemName: "ellipsis.circle")
                              .font(.body)
                              .foregroundStyle(.secondary)
                          }
                        }
                      }
                      
                      HStack(spacing: 4) {
                        if item.isSubscription {
                          Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                          Text("Subscription")
                            .font(.caption2)
                            .foregroundStyle(.teal)
                        } else if item.splitMode == .shared {
                          Image(systemName: "person.2.fill")
                            .font(.caption2)
                          Text("Shared • \(Int(item.userSharePercent))% yours")
                            .font(.caption2)
                        } else {
                          Text("Personal")
                            .font(.caption2)
                        }
                      }
                      .foregroundStyle(.secondary)
                    }
                  }
                  .padding(.vertical, 6)
                  .transition(.move(edge: .trailing).combined(with: .opacity))
                  
                  if item.id != pillarItems.last?.id {
                      Text("│")
                        .font(.system(size: 16, weight: .regular, design: .monospaced))
                        .foregroundStyle(pillar.color(for: colorScheme).opacity(0.4))
                        .frame(width: 20)
                        .padding(.vertical, 4)
                  }
                }
              }
            }
            .padding(.vertical, 8)
            
            if pillar != groupedItems.last?.0 {
              Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 8)
            }
          }
        }

        // Recurring Templates Section
        if !recurringTemplates.isEmpty {
          Divider().background(Color.white.opacity(0.2)).padding(.vertical, 4)

          HStack(spacing: 6) {
            Image(systemName: "arrow.clockwise")
              .font(.caption.weight(.bold))
              .foregroundStyle(.secondary)
            Text("RECURRING".uppercased())
              .font(.caption.weight(.bold))
              .foregroundStyle(.secondary)
              .tracking(0.5)
            Spacer()
            Button("Manage", action: onManageRecurring)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          ForEach(recurringTemplates) { template in
            HStack(spacing: 12) {
              Rectangle()
                .fill(template.pillar.color(for: colorScheme).opacity(0.6))
                .frame(width: 3)
                .clipShape(.rect(cornerRadius: 1.5))

              VStack(alignment: .leading, spacing: 2) {
                Text(template.title)
                  .font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                  Text(template.frequency == .monthly ? "Monthly" : "Weekly")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(template.pillar.color(for: colorScheme).opacity(0.15))
                    .foregroundStyle(template.pillar.color(for: colorScheme))
                    .clipShape(Capsule())
                }
              }

              Spacer()

              Text(template.amount.currency)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

              Button {
                onLogRecurring(template)
              } label: {
                Text("Log")
                  .font(.caption.weight(.semibold))
                  .padding(.horizontal, 10)
                  .padding(.vertical, 5)
                  .background(AppTheme.Colors.tint(for: colorScheme).opacity(0.15))
                  .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                  .clipShape(Capsule())
              }
            }
            .padding(.vertical, 6)

            if template.id != recurringTemplates.last?.id {
              Divider().background(Color.white.opacity(0.1)).padding(.leading, 15)
            }
          }
        }

        HStack {
          Button("Add planned item", action: onAdd)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("expenses.addPlanItemButton")
          Spacer()
          Button {
            onManageRecurring()
          } label: {
            Label("Recurring", systemImage: "arrow.clockwise")
              .font(.caption)
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
      }
    }
  }
  
  private func startInlineEdit(_ item: BudgetPlanItem) {
    editingItemID = item.id
    editAmount = item.plannedAmount.formatted(.number.precision(.fractionLength(2)))
    focusedItemID = item.id
  }
  
  private func saveInlineEdit(_ item: BudgetPlanItem) {
    guard MoneyInputParser.parse(editAmount) != nil else {
      editingItemID = nil
      return
    }
    editingItemID = nil
    focusedItemID = nil
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
    .buttonStyle(PressableStyle())
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
  @State private var invalidFeedbackTrigger = 0
  @State private var validationMessage: String?

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
            .accessibilityIdentifier("expenses.salaryAmountField")
            .onChange(of: value) {
              validationMessage = nil
            }

          if let validationMessage {
            Text(validationMessage)
              .font(.footnote)
              .foregroundStyle(.red)
              .accessibilityIdentifier("expenses.salaryValidationMessage")
          }

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
            guard let parsed = parseMonetaryValue(value), parsed >= 0 else {
              validationMessage = String(localized: "Enter a valid amount, like 2500 or 2500.50.")
              invalidFeedbackTrigger += 1
              return
            }
            onSave(parsed)
            successFeedbackTrigger += 1
            dismiss()
          }
          .accessibilityIdentifier("expenses.salarySaveButton")
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { isValueFocused = false }
        }
      }
    }
    .appSensoryFeedback(success: successFeedbackTrigger, destructive: invalidFeedbackTrigger)
    .animation(.easeOut(duration: 0.2), value: validationMessage)
  }

  private func parseMonetaryValue(_ raw: String) -> Double? {
    MoneyInputParser.parse(raw)
  }
}

private struct PillarTargetsEditorSheet: View {
  @Environment(\.dismiss) private var dismiss

  let monthTitle: String
  let onSave: ([BudgetPillar: Double]) -> Void

  @State private var shares: [BudgetPillar: Double]
  @State private var newPillarName: String = ""
  @State private var validationMessage: String?
  @State private var successFeedbackTrigger = 0

  init(
    monthTitle: String,
    currentShares: [BudgetPillar: Double],
    onSave: @escaping ([BudgetPillar: Double]) -> Void
  ) {
    self.monthTitle = monthTitle
    self.onSave = onSave
    var normalizedShares = currentShares
    for pillar in BudgetPillar.standardPillars where normalizedShares[pillar] == nil {
      normalizedShares[pillar] = pillar.defaultTargetShare
    }
    _shares = State(
      initialValue: Dictionary(uniqueKeysWithValues: normalizedShares.map { key, value in
        (key, max(value, 0) * 100)
      })
    )
  }

  private var orderedPillars: [BudgetPillar] {
    BudgetPillar.sortedForDisplay(shares.keys)
  }

  private var totalSharePercent: Int {
    Int(shares.values.reduce(0, +).rounded())
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Target distribution") {
          Text(monthTitle)
            .foregroundStyle(.secondary)

          ForEach(orderedPillars, id: \.self) { pillar in
            TargetSlider(title: pillar.title, value: binding(for: pillar))

            if !pillar.isStandard {
              Button("Remove \(pillar.title)", role: .destructive) {
                shares.removeValue(forKey: pillar)
              }
            }
          }

          HStack {
            Text("Total")
            Spacer()
            Text("\(totalSharePercent)%")
              .foregroundStyle(totalSharePercent == 100 ? .secondary : AppTheme.Colors.warning)
          }

          if let validationMessage {
            Text(validationMessage)
              .font(.footnote)
              .foregroundStyle(AppTheme.Colors.warning)
          }
        }

        Section("Add custom pillar") {
          HStack {
            TextField("New pillar name", text: $newPillarName)
              .textInputAutocapitalization(.words)
              .disableAutocorrection(true)

            Button("Add") {
              addPillar()
            }
            .disabled(newPillarName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            let normalized = Dictionary(uniqueKeysWithValues: shares.map { key, value in
              (key, max(value, 0) / 100)
            })
            onSave(normalized)
            successFeedbackTrigger += 1
            dismiss()
          }
          .disabled(totalSharePercent != 100 || shares.isEmpty)
        }
      }
    }
    .appSensoryFeedback(success: successFeedbackTrigger)
  }

  private func binding(for pillar: BudgetPillar) -> Binding<Double> {
    Binding(
      get: { shares[pillar] ?? 0 },
      set: { shares[pillar] = max($0, 0) }
    )
  }

  private func addPillar() {
    let rawName = newPillarName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let pillar = BudgetPillar(rawValue: rawName) else {
      validationMessage = "Enter a valid pillar name."
      return
    }
    guard shares[pillar] == nil else {
      validationMessage = "\(pillar.title) already exists."
      return
    }
    shares[pillar] = 0
    validationMessage = nil
    newPillarName = ""
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
  @State private var categoryId: String?
  @State private var splitMode: ExpenseSplitMode
  @State private var userSharePercent: Double
  @FocusState private var isAmountFocused: Bool
  @FocusState private var isTitleFocused: Bool
  @State private var validationMessage: String?
  @State private var successFeedbackTrigger = 0
  let availablePillars: [BudgetPillar]
  let availableCategories: [ExpenseCategoryResponse]

  let itemID: UUID?
  let placeholderItemID: UUID?
  let onSave: (BudgetPlanItemDraft) -> Void

  private var filteredCategories: [ExpenseCategoryResponse] {
    availableCategories.filter { $0.pillar == nil || $0.pillar == pillar }
  }

  init(
    draft: BudgetPlanItemDraft,
    availablePillars: [BudgetPillar],
    availableCategories: [ExpenseCategoryResponse] = [],
    onSave: @escaping (BudgetPlanItemDraft) -> Void
  ) {
    _title = State(initialValue: draft.title)
    _plannedAmount = State(
      initialValue: draft.plannedAmount == 0
        ? ""
        : draft.plannedAmount.formatted(.number.precision(.fractionLength(2)))
    )
    _pillar = State(initialValue: draft.pillar)
    _categoryId = State(initialValue: draft.categoryId)
    _splitMode = State(initialValue: draft.splitMode)
    _userSharePercent = State(initialValue: draft.userSharePercent)
    self.itemID = draft.itemID
    self.placeholderItemID = draft.placeholderItemID
    self.availablePillars = availablePillars.isEmpty
      ? BudgetPillar.standardPillars
      : BudgetPillar.sortedForDisplay(availablePillars)
    self.availableCategories = availableCategories
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
              autocapitalization: .words,
              accessibilityIdentifier: "expenses.planItemTitleField"
            )
            .focused($isTitleFocused)

            FormDivider()

            FormTextField(
              icon: "dollarsign.circle",
              iconColor: AppTheme.Colors.secondaryTint(for: colorScheme),
              placeholder: "Planned amount",
              text: $plannedAmount,
              keyboardType: .decimalPad,
              accessibilityIdentifier: "expenses.planItemAmountField"
            )
            .focused($isAmountFocused)

            if let validationMessage {
              Text(validationMessage)
                .typography(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
          }

          FormCard(title: "Category") {
            FormRow(icon: "square.stack.3d.up", iconColor: .orange, label: "Pillar") {
              Picker("Pillar", selection: $pillar) {
                ForEach(availablePillars, id: \.self) { p in
                  Label(p.title, systemImage: p.symbol)
                    .tag(p)
                }
              }
              .labelsHidden()
              .accessibilityIdentifier("expenses.planItemPillarPicker")
            }

            if !filteredCategories.isEmpty {
              FormDivider()
              FormRow(icon: "tag", iconColor: .teal, label: "Category") {
                Picker("Category", selection: $categoryId) {
                  Text("None").tag(String?.none)
                  ForEach(filteredCategories) { cat in
                    Text(cat.name).tag(Optional(cat.id))
                  }
                }
                .labelsHidden()
              }
            }

            Text(pillar.subtitle)
              .typography(.caption)
              .foregroundStyle(.secondary)
              .padding(.horizontal, 16)
              .padding(.bottom, 12)
              .padding(.top, 4)
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

                HStack(spacing: 12) {
                  ForEach([50.0, 60.0, 70.0], id: \.self) { preset in
                    Button("\(Int(preset))%") {
                      userSharePercent = preset
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))
                  }
                }
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
        isDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        accessibilityIdentifier: "expenses.planItemSaveButton"
      ) {
        let normalizedAmount = plannedAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount: Double
        if normalizedAmount.isEmpty {
          amount = 0
        } else if let parsed = MoneyInputParser.parse(normalizedAmount) {
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
            categoryId: categoryId,
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
    .onChange(of: pillar) { _, _ in categoryId = nil }
  }
}

private struct RecordSpendSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  let monthTitle: String
  let editingActivity: BudgetActivity?
  let initialPillar: BudgetPillar
  let availablePillars: [BudgetPillar]
  let availableItems: [BudgetPlanItem]
  let availableCategories: [ExpenseCategoryResponse]
  let onSave: @MainActor (BudgetActivityDraft) async -> Bool

  @State private var title = ""
  @State private var amount = ""
  @State private var pillar: BudgetPillar
  @State private var occurredOn: Date
  @State private var linkedPlanItemID: UUID?
  @State private var categoryId: String?
  @State private var splitMode: ExpenseSplitMode = .personal
  @State private var userSharePercent: Double = 100
  @State private var isForeignCurrency = false
  @State private var foreignAmountText = ""
  @State private var foreignCurrencyCode = ""
  @State private var exchangeRateText = ""
  @FocusState private var isAmountFocused: Bool
  @State private var isSaving = false
  @State private var saveErrorMessage: String?
  @State private var successFeedbackTrigger = 0

  private var filteredCategories: [ExpenseCategoryResponse] {
    availableCategories.filter { $0.pillar == nil || $0.pillar == pillar }
  }

  init(
    monthTitle: String,
    selectedMonthStart: Date,
    editingActivity: BudgetActivity? = nil,
    initialPillar: BudgetPillar = .fundamentals,
    availablePillars: [BudgetPillar],
    availableItems: [BudgetPlanItem],
    availableCategories: [ExpenseCategoryResponse] = [],
    prefillDraft: BudgetActivityDraft? = nil,
    onSave: @escaping @MainActor (BudgetActivityDraft) async -> Bool
  ) {
    self.monthTitle = monthTitle
    self.editingActivity = editingActivity
    self.initialPillar = initialPillar
    self.availablePillars = availablePillars.isEmpty
      ? BudgetPillar.standardPillars
      : BudgetPillar.sortedForDisplay(availablePillars)
    self.availableItems = availableItems
    self.availableCategories = availableCategories
    self.onSave = onSave
    let prefill = prefillDraft
    _title = State(initialValue: editingActivity?.title ?? prefill?.title ?? "")
    _amount = State(initialValue: editingActivity.map { Self.formattedAmount($0.amount) } ?? prefill.map { Self.formattedAmount($0.amount) } ?? "")
    _pillar = State(initialValue: editingActivity?.pillar ?? prefill?.pillar ?? initialPillar)
    _occurredOn = State(
      initialValue: editingActivity?.occurredOn ?? prefill?.occurredOn ?? Self.defaultDate(for: selectedMonthStart)
    )
    _linkedPlanItemID = State(initialValue: editingActivity?.linkedPlanItemID)
    _categoryId = State(initialValue: editingActivity == nil ? prefill?.categoryId : nil)
    _splitMode = State(initialValue: editingActivity?.splitMode ?? prefill?.splitMode ?? .personal)
    _userSharePercent = State(initialValue: editingActivity?.userSharePercent ?? prefill?.userSharePercent ?? 100)
  }

  var body: some View {
    VStack(spacing: 0) {
      FormSheetHeader(
        title: editingActivity == nil ? "Record Spend" : "Edit Spend",
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
              disableAutocorrection: true,
              accessibilityIdentifier: "expenses.expenseTitleField"
            )

            FormDivider()

            if isForeignCurrency {
              FormTextField(
                icon: "globe",
                iconColor: .orange,
                placeholder: "Foreign amount (e.g. 50)",
                text: $foreignAmountText,
                keyboardType: .decimalPad
              )

              FormDivider()

              FormTextField(
                icon: "dollarsign.circle",
                iconColor: .orange,
                placeholder: "Currency code (e.g. USD)",
                text: $foreignCurrencyCode,
                autocapitalization: .characters,
                disableAutocorrection: true
              )

              FormDivider()

              FormTextField(
                icon: "arrow.left.arrow.right",
                iconColor: .orange,
                placeholder: "Exchange rate (e.g. 1.27)",
                text: $exchangeRateText,
                keyboardType: .decimalPad
              )

              if let fa = MoneyInputParser.parse(foreignAmountText),
                 let rate = MoneyInputParser.parse(exchangeRateText),
                 rate > 0 {
                FormDivider()
                HStack {
                  Image(systemName: "equal.circle")
                    .foregroundStyle(.secondary)
                  Text("Home amount: \((fa * rate).currency)")
                    .typography(.small, weight: .semibold)
                    .foregroundStyle(.primary)
                }
                .padding(.vertical, 4)
              }
            } else {
              FormTextField(
                icon: "dollarsign.circle",
                iconColor: AppTheme.Colors.secondaryTint(for: colorScheme),
                placeholder: "Amount",
                text: $amount,
                keyboardType: .decimalPad,
                accessibilityIdentifier: "expenses.expenseAmountField"
              )
              .focused($isAmountFocused)
            }

            FormDivider()

            FormToggle(
              icon: "globe",
              label: "Foreign currency",
              isOn: $isForeignCurrency
            )

            if let saveErrorMessage {
              FormDivider()
              Text(saveErrorMessage)
                .typography(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            FormDivider()

            FormRow(icon: "calendar", iconColor: .orange, label: "Date") {
              DatePicker("", selection: $occurredOn, displayedComponents: .date)
                .labelsHidden()
            }
          }

          FormCard(title: "Category") {
            FormRow(icon: "square.stack.3d.up", iconColor: .purple, label: "Pillar") {
              Picker("Pillar", selection: $pillar) {
                ForEach(availablePillars, id: \.self) { p in
                  Label(p.title, systemImage: p.symbol).tag(p)
                }
              }
              .labelsHidden()
            }

            if !filteredCategories.isEmpty {
              FormDivider()
              FormRow(icon: "tag", iconColor: .teal, label: "Category") {
                Picker("Category", selection: $categoryId) {
                  Text("None").tag(String?.none)
                  ForEach(filteredCategories) { cat in
                    Text(cat.name).tag(Optional(cat.id))
                  }
                }
                .labelsHidden()
                .accessibilityIdentifier("expenses.expenseCategoryPicker")
              }
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
        primaryLabel: editingActivity == nil ? "Save" : "Save changes",
        isLoading: isSaving,
        isDisabled: {
          if isForeignCurrency {
            let fa = MoneyInputParser.parse(foreignAmountText)
            let rate = MoneyInputParser.parse(exchangeRateText)
            return fa == nil || (rate ?? 0) <= 0
              || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && linkedPlanItemID == nil
          }
          return parseMonetaryValue(amount) == nil
            || (title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && linkedPlanItemID == nil)
        }(),
        accessibilityIdentifier: "expenses.expenseSaveButton"
      ) {
        guard !isSaving else { return }

        let parsedAmount: Double
        var foreignAmountVal: Double?
        var foreignCurrencyVal: String?
        var exchangeRateVal: Double?

        if isForeignCurrency {
          guard let fa = MoneyInputParser.parse(foreignAmountText),
                let rate = MoneyInputParser.parse(exchangeRateText), rate > 0 else { return }
          parsedAmount = fa * rate
          foreignAmountVal = fa
          foreignCurrencyVal = foreignCurrencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().isEmpty ? nil : foreignCurrencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
          exchangeRateVal = rate
        } else {
          guard let pa = parseMonetaryValue(amount) else { return }
          parsedAmount = pa
        }

        let resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          ? filteredItems.first(where: { $0.id == linkedPlanItemID })?.title ?? ""
          : title
        let draft = BudgetActivityDraft(
          title: resolvedTitle,
          amount: parsedAmount,
          pillar: pillar,
          occurredOn: occurredOn,
          linkedPlanItemID: linkedPlanItemID,
          categoryId: categoryId,
          splitMode: splitMode,
          userSharePercent: splitMode == .personal ? 100 : userSharePercent,
          foreignAmount: foreignAmountVal,
          foreignCurrency: foreignCurrencyVal,
          exchangeRate: exchangeRateVal
        )

        Task { @MainActor in
          saveErrorMessage = nil
          isSaving = true
          let didSave = await onSave(draft)
          isSaving = false
          if didSave {
            successFeedbackTrigger += 1
            dismiss()
          } else {
            saveErrorMessage = "Could not save expense. Please try again."
          }
        }
      }
    }
    .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
    .presentationDragIndicator(.visible)
    .appSensoryFeedback(success: successFeedbackTrigger)
    .onChange(of: linkedPlanItemID) { _, newValue in
      guard let newValue, let item = availableItems.first(where: { $0.id == newValue }) else { return }
      splitMode = item.splitMode
      userSharePercent = item.userSharePercent
    }
    .onChange(of: pillar) { _, _ in categoryId = nil }
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

  private static func formattedAmount(_ amount: Double) -> String {
    let rounded = amount.rounded()
    if abs(amount - rounded) < 0.000_1 {
      return String(Int(rounded))
    }
    return amount.formatted(.number.precision(.fractionLength(0...2)))
  }

  private func parseMonetaryValue(_ raw: String) -> Double? {
    MoneyInputParser.parse(raw)
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

struct MetricItem: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(spacing: 4) {
      Text(title)
        .typography(.nano)
        .foregroundStyle(.secondary)
      Text(value)
        .typography(.small, weight: .semibold)
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity)
  }
}
