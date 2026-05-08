import StockPlanShared
import SwiftUI

struct PortfolioTargetAlertSheet: View {
  @Environment(\.dismiss) private var dismiss

  let symbol: String
  let referencePrice: Double
  let existingAlert: TargetResponse?
  let isSaving: Bool
  let onSave: (Double, PortfolioTargetAlertDirection) async -> String?
  let onDelete: () async -> String?

  @State private var isEnabled: Bool
  @State private var priceText: String
  @State private var direction: PortfolioTargetAlertDirection
  @State private var errorMessage: String?

  init(
    symbol: String,
    referencePrice: Double,
    existingAlert: TargetResponse?,
    isSaving: Bool,
    onSave: @escaping (Double, PortfolioTargetAlertDirection) async -> String?,
    onDelete: @escaping () async -> String?
  ) {
    self.symbol = symbol
    self.referencePrice = referencePrice
    self.existingAlert = existingAlert
    self.isSaving = isSaving
    self.onSave = onSave
    self.onDelete = onDelete
    _isEnabled = State(initialValue: existingAlert != nil)
    _priceText = State(initialValue: Self.initialPriceText(existingAlert: existingAlert, referencePrice: referencePrice))
    _direction = State(initialValue: existingAlert.map { PortfolioTargetAlertDirection.fromScenario($0.scenario) } ?? .above)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle(isOn: $isEnabled) {
            Label("Notify at price", systemImage: "bell.badge")
          }

          Picker("Direction", selection: $direction) {
            ForEach(PortfolioTargetAlertDirection.allCases) { direction in
              Text(direction.title).tag(direction)
            }
          }
          .pickerStyle(.segmented)
          .disabled(!isEnabled)

          TextField("Target price", text: $priceText)
            .keyboardType(.decimalPad)
            .disabled(!isEnabled)
        } header: {
          Text(symbol)
        } footer: {
          Text("Reference price: \(referencePrice.currency)")
        }

        if let errorMessage {
          Section {
            Text(errorMessage)
              .foregroundStyle(AppTheme.Colors.danger)
          }
        }
      }
      .navigationTitle("Price Alert")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(isEnabled ? "Save" : "Turn Off") {
            save()
          }
          .disabled(isSaving)
        }
      }
    }
    .presentationDetents([.medium])
  }

  private func save() {
    Task {
      if isEnabled {
        guard let price = MoneyInputParser.parse(priceText), price > 0 else {
          errorMessage = "Enter a valid target price."
          return
        }
        errorMessage = await onSave(price, direction)
      } else {
        errorMessage = await onDelete()
      }

      if errorMessage == nil {
        dismiss()
      }
    }
  }

  private static func initialPriceText(existingAlert: TargetResponse?, referencePrice: Double) -> String {
    let price = existingAlert?.targetPrice ?? referencePrice
    guard price > 0 else { return "" }
    return price.formatted(.number.precision(.fractionLength(0...2)))
  }
}
