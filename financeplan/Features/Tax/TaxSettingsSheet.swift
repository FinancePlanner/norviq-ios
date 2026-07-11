import StockPlanShared
import SwiftUI

struct TaxSettingsSheet: View {
  @Environment(\.dismiss) private var dismiss
  let service: TaxServiceProtocol
  @State private var enabled = false
  @State private var minimumBenefit = ""
  @State private var cooldownDays = 7
  @State private var isLoading = true
  @State private var isSaving = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle("Notify me about actionable opportunities", isOn: $enabled)
          TextField("Minimum estimated benefit", text: $minimumBenefit)
            .keyboardType(.decimalPad)
            .disabled(!enabled)
          Stepper("Cooldown: \(cooldownDays) days", value: $cooldownDays, in: 1...30)
            .disabled(!enabled)
        } header: {
          Text("Harvesting alerts")
        } footer: {
          Text("Norviq also requires a benefit above 0.5% of your taxable portfolio or 250 in your reporting currency, whichever is greater.")
        }
        if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
      }
      .navigationTitle("Tax settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await save() } }.disabled(isLoading || isSaving)
        }
      }
      .overlay { if isLoading { ProgressView() } }
      .task { await load() }
    }
  }

  private func load() async {
    defer { isLoading = false }
    do {
      let preferences = try await service.notificationPreferences()
      enabled = preferences.enabled
      cooldownDays = preferences.cooldownDays
      minimumBenefit = preferences.minimumBenefit.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
    } catch { errorMessage = "Notification settings could not be loaded." }
  }

  private func save() async {
    isSaving = true
    defer { isSaving = false }
    do {
      _ = try await service.saveNotificationPreferences(.init(
        enabled: enabled,
        minimumBenefit: Decimal(string: minimumBenefit),
        cooldownDays: cooldownDays
      ))
      dismiss()
    } catch { errorMessage = "Notification settings could not be saved." }
  }
}
