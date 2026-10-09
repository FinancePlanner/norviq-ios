import Factory
import StockPlanShared
import SwiftUI

enum AutobuyEditorTarget: Identifiable {
  case new
  case edit(AutobuyResponse)

  var id: String {
    switch self {
    case .new: "new"
    case let .edit(autobuy): autobuy.id
    }
  }

  var autobuy: AutobuyResponse? {
    if case let .edit(autobuy) = self { return autobuy }
    return nil
  }
}

struct AutobuyEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model: AutobuyEditorModel
  private let onSaved: (AutobuyResponse) -> Void

  init(target: AutobuyEditorTarget, currency: String, onSaved: @escaping (AutobuyResponse) -> Void) {
    _model = State(initialValue: AutobuyEditorModel(
      autobuy: target.autobuy,
      currency: currency,
      service: Container.shared.terminalPositionsService()
    ))
    self.onSaved = onSaved
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Label", text: $model.inputs.label, prompt: Text("e.g. 401k contribution"))
          TextField("Ticker (optional)", text: $model.inputs.ticker)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
          if let problem = model.tickerProblem {
            Text(problem).font(.caption).foregroundStyle(.red)
          }
          Toggle("Active", isOn: $model.inputs.active)
        }
        Section {
          Picker("Cadence", selection: $model.inputs.cadence) {
            ForEach(AutobuyEditorModel.cadences, id: \.self) { cadence in
              Text(cadence.title).tag(cadence)
            }
          }
          TerminalNumberInputField(
            title: model.isPercentCadence ? "Monthly base" : "Amount",
            input: $model.inputs.amount,
            problem: model.amountProblem
          )
          if model.isPercentCadence {
            TerminalNumberInputField(
              title: "Percent",
              input: $model.inputs.percent,
              problem: model.percentProblem
            )
          }
        } footer: {
          if let monthly = model.monthlyEquivalent {
            Text("Monthly equivalent: \(TerminalFormat.money(monthly, currency: model.currency))")
          }
        }
      }
      .navigationTitle(model.isEditing ? LocalizedStringKey("Edit autobuy") : LocalizedStringKey("New autobuy"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: dismiss.callAsFunction)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await save() } }
            .disabled(!model.canSave)
        }
      }
      .alert("Autobuys", isPresented: Binding(
        get: { model.errorMessage != nil },
        set: { if !$0 { model.errorMessage = nil } }
      )) {
        Button("OK", role: .cancel) { model.errorMessage = nil }
      } message: {
        Text(model.errorMessage ?? "")
      }
    }
  }

  private func save() async {
    guard let saved = await model.save() else { return }
    onSaved(saved)
    dismiss()
  }
}

struct TerminalAutobuysSection: View {
  let model: TerminalPositionsViewModel
  let onEdit: (AutobuyResponse) -> Void
  let onAdd: () -> Void

  var body: some View {
    Section {
      ForEach(model.autobuys) { autobuy in
        Button {
          onEdit(autobuy)
        } label: {
          AutobuyRow(autobuy: autobuy, currency: model.currency)
        }
        .buttonStyle(.plain)
        // A cadence this build doesn't know can't be edited without losing it.
        .disabled(autobuy.cadence == .unknown)
        .swipeActions {
          Button("Delete", role: .destructive) {
            Task { await model.deleteAutobuy(autobuy) }
          }
        }
      }
      Button(action: onAdd) {
        Label("Add autobuy", systemImage: "plus")
      }
      if !model.autobuys.isEmpty {
        LabeledContent("Monthly total") {
          Text(TerminalFormat.money(model.monthlyAutobuyTotal, currency: model.currency)).monospacedDigit()
        }
      }
    } header: {
      Text("Autobuys")
    }
  }
}

struct AutobuyRow: View {
  let autobuy: AutobuyResponse
  let currency: String

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(verbatim: autobuy.label)
            .font(.body.weight(.semibold))
          if let ticker = autobuy.ticker {
            Text(verbatim: ticker)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        Text(verbatim: detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if let monthly = autobuy.monthlyEquivalent {
        Text("\(TerminalFormat.money(monthly, currency: currency)) a month")
          .font(.subheadline.monospacedDigit())
      } else if autobuy.cadence == .percentOfContribution {
        Text("Add a monthly base")
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
    .opacity(autobuy.active ? 1 : 0.5)
    .contentShape(Rectangle())
  }

  private var detail: String {
    if autobuy.cadence == .percentOfContribution, let percent = autobuy.percent {
      return "\(autobuy.cadence.title) · \(percent.formatted(.percent.precision(.fractionLength(0...2))))"
    }
    return "\(autobuy.cadence.title) · \(TerminalFormat.money(autobuy.amount, currency: currency))"
  }
}
