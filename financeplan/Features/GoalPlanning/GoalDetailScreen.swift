import Charts
import StockPlanShared
import SwiftUI

struct GoalDetailScreen: View {
  let item: GoalOverviewItem
  @Bindable var model: GoalPlanningViewModel
  @State private var contribution: Double
  @State private var annualReturnPercent: Double
  @State private var pendingSuggestion: GoalSuggestion?
  @State private var isAddingContribution = false

  init(item: GoalOverviewItem, model: GoalPlanningViewModel) {
    self.item = item
    self.model = model
    _contribution = State(initialValue: item.goal.monthlyContribution)
    _annualReturnPercent = State(initialValue: item.goal.expectedAnnualReturn * 100)
  }

  private var progress: GoalProgress { model.progressByGoal[item.id] ?? item.progress }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        progressSummary
        trajectoryChart
        whatIfSimulator
        suggestions
        assumptions
      }
      .padding(16)
      .maxContentWidth(regularSizeClass: ContentWidth.dense)
    }
    .background(MeshGradientBackground())
    .navigationTitle(item.goal.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Record contribution", systemImage: "plus.circle") { isAddingContribution = true }
      }
    }
    .task { await model.loadDetails(goalId: item.id) }
    .refreshable { await model.loadDetails(goalId: item.id) }
    .confirmationDialog(
      "Prepare this adjustment?",
      isPresented: Binding(get: { pendingSuggestion != nil }, set: { if !$0 { pendingSuggestion = nil } }),
      presenting: pendingSuggestion
    ) { suggestion in
      Button("Create review draft") { Task { await model.accept(suggestion) } }
      Button("Cancel", role: .cancel) {}
    } message: { suggestion in
      Text("\(suggestion.explanation) This creates a draft only; budget and portfolio changes still require confirmation.")
    }
    .sheet(isPresented: $isAddingContribution) {
      GoalContributionSheet(goalId: item.id, model: model)
    }
    .alert("Draft ready", isPresented: Binding(
      get: { model.confirmationMessage != nil }, set: { if !$0 { model.confirmationMessage = nil } }
    )) {
      Button("OK", role: .cancel) { model.confirmationMessage = nil }
    } message: { Text(model.confirmationMessage ?? "") }
  }

  private var progressSummary: some View {
    VStack(spacing: 16) {
      Gauge(value: progress.percentComplete) {
        Text("Goal progress")
      } currentValueLabel: {
        Text(progress.percentComplete, format: .percent.precision(.fractionLength(0)))
          .font(.title2.bold().monospacedDigit())
      }
      .gaugeStyle(.accessoryCircularCapacity)
      .tint(progress.driftState == .behind ? .orange : AppTheme.Colors.success)
      .scaleEffect(1.7)
      .frame(height: 116)
      HStack {
        valueMetric("Current", progress.currentValue)
        Spacer()
        valueMetric("Target", progress.targetAmount)
        Spacer()
        VStack(alignment: .trailing, spacing: 3) {
          Text("Drift").font(.caption).foregroundStyle(.secondary)
          Text(driftText).font(.headline.monospacedDigit())
        }
      }
    }
    .padding(18)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
  }

  private var trajectoryChart: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Trajectory").font(.headline)
      Chart(progress.trajectory) { point in
        LineMark(x: .value("Date", point.date), y: .value("Planned", point.plannedValue))
          .foregroundStyle(.secondary)
          .lineStyle(.init(dash: [5, 4]))
        LineMark(x: .value("Date", point.date), y: .value("Projected", point.projectedValue))
          .foregroundStyle(AppTheme.Colors.success)
        if let actual = point.actualValue {
          PointMark(x: .value("Date", point.date), y: .value("Actual", actual))
            .foregroundStyle(.primary)
        }
      }
      .frame(height: 240)
      HStack {
        Label("Planned", systemImage: "minus").foregroundStyle(.secondary)
        Label("Projected", systemImage: "minus").foregroundStyle(AppTheme.Colors.success)
        Label("Actual", systemImage: "circle.fill")
      }
      .font(.caption)
    }
    .padding(16)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  private var whatIfSimulator: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("What if?").font(.headline)
      LabeledContent("Monthly contribution") {
        TextField("Contribution", value: $contribution, format: .number.precision(.fractionLength(0)))
          .multilineTextAlignment(.trailing)
          .keyboardType(.decimalPad)
          .frame(maxWidth: 120)
      }
      Slider(value: $contribution, in: 0 ... max(5_000, item.goal.monthlyContribution * 3), step: 25)
      LabeledContent("Expected annual return") {
        Text(annualReturnPercent / 100, format: .percent.precision(.fractionLength(1)))
          .monospacedDigit()
      }
      Slider(
        value: $annualReturnPercent,
        in: max(0, item.goal.riskProfile.defaultAnnualReturn * 100 - 1) ... min(20, item.goal.riskProfile.defaultAnnualReturn * 100 + 1),
        step: 0.1
      )
      LabeledContent("Projected at target") {
        Text(localProjection, format: .currency(code: item.goal.baseCurrency).presentation(.narrow))
          .fontWeight(.semibold)
          .monospacedDigit()
      }
      Button("Use this scenario") {
        Task { await model.runWhatIf(
          goalId: item.id, contribution: contribution, annualReturn: annualReturnPercent / 100
        ) }
      }
      .buttonStyle(.borderedProminent)
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(16)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  @ViewBuilder private var suggestions: some View {
    let values = model.suggestionsByGoal[item.id] ?? []
    if !values.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        Text("Adjustment options").font(.headline)
        ForEach(values) { suggestion in
          VStack(alignment: .leading, spacing: 8) {
            Label(suggestion.title, systemImage: suggestion.kind == .reduceSpending ? "chart.pie" : "slider.horizontal.3")
              .font(.subheadline.bold())
            Text(suggestion.explanation).font(.caption).foregroundStyle(.secondary)
            Button("Review option") { pendingSuggestion = suggestion }
              .buttonStyle(.bordered)
          }
          .padding(14)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
      }
    }
  }

  private var assumptions: some View {
    DisclosureGroup("Assumptions & data quality") {
      VStack(alignment: .leading, spacing: 8) {
        Text("Return: \(item.goal.expectedAnnualReturn, format: .percent.precision(.fractionLength(1))) nominal per year")
        Text("Planned contribution: \(progress.plannedMonthlyContribution, format: .currency(code: item.goal.baseCurrency)) / month")
        Text("Observed contribution: \(progress.observedMonthlyContribution, format: .currency(code: item.goal.baseCurrency)) / month")
        ForEach(progress.warnings, id: \.self) { Label($0, systemImage: "exclamationmark.triangle") }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.top, 8)
    }
  }

  private var localProjection: Double {
    let months = max(0, Calendar.current.dateComponents([.month], from: Date(), to: Self.date(item.goal.targetDate)).month ?? 0)
    return GoalProjectionCalculator.futureValue(
      principal: progress.currentValue,
      monthlyContribution: contribution,
      annualRate: annualReturnPercent / 100,
      months: months
    )
  }

  private var driftText: String {
    guard let months = progress.driftMonths else { return "—" }
    if abs(months) <= 1 { return "On track" }
    return months > 0 ? "\(months) mo behind" : "\(-months) mo ahead"
  }

  private func valueMetric(_ title: LocalizedStringKey, _ value: Double) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value, format: .currency(code: item.goal.baseCurrency).presentation(.narrow))
        .font(.headline.monospacedDigit())
    }
  }

  private static func date(_ value: String) -> Date {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value) ?? Date()
  }
}

private struct GoalContributionSheet: View {
  @Environment(\.dismiss) private var dismiss
  let goalId: String
  @Bindable var model: GoalPlanningViewModel
  @State private var amount = 0.0
  @State private var date = Date()

  var body: some View {
    NavigationStack {
      Form {
        TextField("Amount", value: $amount, format: .number)
          .keyboardType(.decimalPad)
        DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
      }
      .navigationTitle("Record contribution")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task { if await model.addContribution(goalId: goalId, amount: amount, date: date) { dismiss() } }
          }
          .disabled(amount <= 0)
        }
      }
    }
  }
}
