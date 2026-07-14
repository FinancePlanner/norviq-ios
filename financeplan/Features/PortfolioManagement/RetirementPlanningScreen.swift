import Charts
import StockPlanShared
import SwiftUI

struct RetirementPlanningScreen: View {
  @State private var model: RetirementPlanningViewModel

  init(portfolio: Portfolio, service: any PortfolioReportingServicing) {
    _model = State(initialValue: RetirementPlanningViewModel(portfolio: portfolio, service: service))
  }

  var body: some View {
    @Bindable var model = model
    Form {
      Section("Planning assumptions") {
        Picker("Jurisdiction", selection: $model.jurisdiction) {
          ForEach(TaxJurisdiction.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .onChange(of: model.jurisdiction) { Task { await model.jurisdictionChanged() } }
        Stepper("Current age: \(model.currentAge)", value: $model.currentAge, in: 18...80)
        Stepper("Retirement age: \(model.retirementAge)", value: $model.retirementAge, in: 40...85)
        Stepper("Plan through age: \(model.longevityAge)", value: $model.longevityAge, in: 70...110)
        currencyField("Annual salary", value: $model.annualSalary)
        currencyField("Current savings", value: $model.currentBalance)
        currencyField("Annual contribution", value: $model.annualContribution)
        currencyField("Desired annual spending", value: $model.desiredAnnualSpending)
        currencyField("Public pension (manual)", value: $model.publicPension)
        LabeledContent("Expected annual return") {
          TextField("Return", value: $model.expectedAnnualReturn, format: .percent)
            .multilineTextAlignment(.trailing).keyboardType(.decimalPad)
        }
      }

      if let rules = model.rules {
        Section("Rule pack") {
          LabeledContent("Version", value: rules.version)
          LabeledContent("Effective", value: rules.effectiveFrom)
          Text(rules.disclaimer).font(.footnote).foregroundStyle(.secondary)
          ForEach(rules.sources) { source in
            if let url = URL(string: source.url) {
              Link(source.title, destination: url)
            }
          }
        }
      }

      if model.plan?.newerRuleVersion != nil {
        Section {
          Button("Review and use current rules") { Task { await model.refreshRules() } }
          Text("Rule updates are explicit; projections keep their saved version until you refresh.")
            .font(.footnote).foregroundStyle(.secondary)
        }
      }

      if let projection = model.projection {
        Section("Projection") {
          LabeledContent(
            "Readiness",
            value: projection.summary.readinessProbability.formatted(.percent.precision(.fractionLength(0)))
          )
          LabeledContent(
            "Median at retirement",
            value: projection.summary.medianValueAtRetirement.formatted(.currency(code: projection.currency))
          )
          Chart(projection.points) { point in
            LineMark(x: .value("Age", point.age), y: .value("Median", point.p50))
              .foregroundStyle(.tint)
            AreaMark(x: .value("Age", point.age), yStart: .value("Low", point.p25), yEnd: .value("High", point.p75))
              .foregroundStyle(.tint.opacity(0.15))
          }
          .frame(height: 220)
          .accessibilityLabel("Projected retirement portfolio range by age")
          ForEach(projection.warnings, id: \.self) { Text($0).font(.footnote).foregroundStyle(.orange) }
        }
      }

      Section {
        Button("Save and run projection") { Task { await model.saveAndProject() } }
          .disabled(model.isLoading || model.retirementAge <= model.currentAge)
      }
    }
    .navigationTitle("Retirement plan")
    .overlay {
      if model.isLoading {
        ProgressView().controlSize(.large)
      }
    }
    .task { await model.load() }
    .alert("Retirement plan unavailable", isPresented: errorBinding) {
      Button("OK") { model.errorMessage = nil }
    } message: { Text(model.errorMessage ?? "Please try again.") }
  }

  private func currencyField(_ title: String, value: Binding<Double>) -> some View {
    LabeledContent(title) {
      TextField(title, value: value, format: .number)
        .multilineTextAlignment(.trailing).keyboardType(.decimalPad)
    }
  }

  private var errorBinding: Binding<Bool> {
    Binding(get: { model.errorMessage != nil }, set: {
      if !$0 {
        model.errorMessage = nil
      }
    })
  }
}
