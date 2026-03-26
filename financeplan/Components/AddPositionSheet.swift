import SwiftUI

struct AddPositionDraft: Equatable {
  var symbol: String
  var companyName: String?
  var shares: String = ""
  var buyPrice: String = ""
  var buyDate: Date = .now
  var notes: String = ""
  var symbolLocked: Bool = false
}

struct AddPositionSheet: View {
  @Environment(\.dismiss) private var dismiss

  let title: String
  @State var draft: AddPositionDraft
  let isSaving: Bool
  let onSave: @MainActor (AddPositionDraft) async -> String?

  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Stock") {
          if let companyName = draft.companyName, !companyName.isEmpty {
            Text(companyName)
              .foregroundStyle(.secondary)
          }

          TextField("Symbol", text: $draft.symbol)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled(true)
            .disabled(draft.symbolLocked)
        }

        Section("Position") {
          TextField("Shares", text: $draft.shares)
            .keyboardType(.decimalPad)

          TextField("Buy price", text: $draft.buyPrice)
            .keyboardType(.decimalPad)

          DatePicker("Buy date", selection: $draft.buyDate, displayedComponents: .date)
        }

        Section("Notes") {
          TextField("Optional notes", text: $draft.notes, axis: .vertical)
            .lineLimit(3 ... 6)
        }

        if let errorMessage {
          Section {
            Text(errorMessage)
              .foregroundStyle(AppTheme.Colors.danger)
          }
        }
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(isSaving ? "Saving..." : "Save") {
            Task {
              errorMessage = await onSave(draft)
              if errorMessage == nil {
                dismiss()
              }
            }
          }
          .disabled(isSaving || !isValid)
        }
      }
    }
  }

  private var isValid: Bool {
    !draft.symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && Double(draft.shares) != nil
      && Double(draft.buyPrice) != nil
  }
}
