import StockPlanShared
import SwiftUI

struct GoalCreationWizard: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var model: GoalPlanningViewModel
  let onComplete: () -> Void

  @State private var step = 0
  @State private var selectedTemplate: GoalTemplate?
  @State private var name = ""
  @State private var goalType = FinancialGoalType.custom
  @State private var targetAmount = 100_000.0
  @State private var targetDate = Calendar.current.date(byAdding: .year, value: 10, to: Date()) ?? Date()
  @State private var currency = "USD"
  @State private var startingCapital = 0.0
  @State private var contribution = 500.0
  @State private var riskProfile = FinancialGoalRiskProfile.moderate
  @State private var allocations: [String: Double] = [:]

  var body: some View {
    Form {
      Section {
        ProgressView(value: Double(step + 1), total: 3)
        Text("Step \(step + 1) of 3").font(.caption).foregroundStyle(.secondary)
      }
      switch step {
      case 0: templateStep
      case 1: targetStep
      default: fundingStep
      }
    }
    .navigationTitle("Create a goal")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
      ToolbarItem(placement: .confirmationAction) {
        Button(step == 2 ? "Create" : "Next") { advance() }
          .disabled(!canContinue || model.isSaving)
      }
      if step > 0 {
        ToolbarItem(placement: .bottomBar) { Button("Back", systemImage: "chevron.left") { step -= 1 } }
      }
    }
    .interactiveDismissDisabled(model.isSaving)
  }

  private var templateStep: some View {
    Section("Choose a starting point") {
      ForEach(model.templates) { template in
        Button {
          apply(template)
        } label: {
          HStack {
            VStack(alignment: .leading) {
              Text(template.name).foregroundStyle(.primary)
              Text("\(template.suggestedYears)-year starting horizon")
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if selectedTemplate?.id == template.id { Image(systemName: "checkmark.circle.fill") }
          }
        }
      }
      Button("Start a custom goal") {
        selectedTemplate = .init(id: "custom", name: "Custom", goalType: .custom, suggestedYears: 10, riskProfile: .moderate)
        name = "My financial goal"
        goalType = .custom
      }
    }
  }

  private var targetStep: some View {
    Group {
      Section("Outcome") {
        TextField("Goal name", text: $name)
          .textInputAutocapitalization(.words)
        Picker("Goal type", selection: $goalType) {
          ForEach(FinancialGoalType.allCases, id: \.self) { Text(label($0)).tag($0) }
        }
        TextField("Target amount", value: $targetAmount, format: .number.precision(.fractionLength(0)))
          .keyboardType(.decimalPad)
        TextField("Currency", text: $currency)
          .textInputAutocapitalization(.characters)
          .autocorrectionDisabled()
        DatePicker("Target date", selection: $targetDate, in: Date()..., displayedComponents: .date)
      }
      Section {
        Text("Amounts are nominal in this version. The return assumption is shown explicitly and can be changed later.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
  }

  private var fundingStep: some View {
    Group {
      Section("Funding") {
        TextField("Starting capital", value: $startingCapital, format: .number.precision(.fractionLength(0)))
          .keyboardType(.decimalPad)
        TextField("Monthly contribution", value: $contribution, format: .number.precision(.fractionLength(0)))
          .keyboardType(.decimalPad)
        Picker("Risk profile", selection: $riskProfile) {
          ForEach(FinancialGoalRiskProfile.allCases, id: \.self) { profile in
            Text(profile.rawValue.capitalized).tag(profile)
          }
        }
        LabeledContent("Return assumption") {
          Text(riskProfile.defaultAnnualReturn, format: .percent.precision(.fractionLength(0)))
        }
      }
      Section("Linked portfolios") {
        ForEach(model.portfolios) { portfolio in
          VStack(alignment: .leading, spacing: 8) {
            Toggle(portfolio.name, isOn: allocationBinding(for: portfolio.id))
            if allocations[portfolio.id] != nil {
              HStack {
                Slider(value: percentageBinding(for: portfolio.id), in: 5 ... 100, step: 5)
                Text((allocations[portfolio.id] ?? 0) / 100, format: .percent.precision(.fractionLength(0)))
                  .frame(width: 52, alignment: .trailing).monospacedDigit()
              }
            }
          }
        }
        Text("Allocation is the share of each portfolio reserved for this goal. Total active allocations on a portfolio cannot exceed 100%.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
  }

  private var canContinue: Bool {
    switch step {
    case 0: selectedTemplate != nil
    case 1: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && targetAmount > 0 && currency.count == 3
    default: startingCapital >= 0 && contribution >= 0 && !allocations.isEmpty
    }
  }

  private func advance() {
    guard step == 2 else { step += 1; return }
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    let input = FinancialGoalInput(
      name: name,
      goalType: goalType,
      targetAmount: targetAmount,
      targetDate: formatter.string(from: targetDate),
      baseCurrency: currency.uppercased(),
      startingCapital: startingCapital,
      monthlyContribution: contribution,
      riskProfile: riskProfile,
      portfolioAllocations: allocations.map {
        .init(id: UUID().uuidString, portfolioListId: $0.key, allocationPercentage: $0.value)
      }
    )
    Task {
      if await model.create(input) {
        onComplete()
        dismiss()
      }
    }
  }

  private func apply(_ template: GoalTemplate) {
    selectedTemplate = template
    name = template.name
    goalType = template.goalType
    riskProfile = template.riskProfile
    targetDate = Calendar.current.date(byAdding: .year, value: template.suggestedYears, to: Date()) ?? Date()
  }

  private func allocationBinding(for id: String) -> Binding<Bool> {
    Binding(
      get: { allocations[id] != nil },
      set: { enabled in allocations[id] = enabled ? 100 : nil }
    )
  }

  private func percentageBinding(for id: String) -> Binding<Double> {
    Binding(get: { allocations[id] ?? 100 }, set: { allocations[id] = $0 })
  }

  private func label(_ type: FinancialGoalType) -> String {
    switch type {
    case .retirement: "Retirement"
    case .homePurchase: "Home purchase"
    case .financialIndependence: "Financial independence"
    case .education: "Education"
    case .emergencyFund: "Emergency fund"
    case .investmentTarget: "Investment target"
    case .custom: "Custom"
    }
  }
}
