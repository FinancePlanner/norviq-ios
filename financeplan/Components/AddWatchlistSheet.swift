import StockPlanShared
import SwiftUI

struct AddWatchlistDraft: Equatable {
  var symbol: String = ""
  var note: String = ""
  var status: WatchlistStatus = .active
}

struct AddWatchlistSheet: View {
  @Environment(\.dismiss) private var dismiss

  @State var draft: AddWatchlistDraft
  let isSaving: Bool
  let onSave: @MainActor (AddWatchlistDraft) async -> String?

  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Stock") {
          TextField("Symbol", text: $draft.symbol)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled(true)
        }

        Section("Why are you watching it?") {
          TextField("Optional note", text: $draft.note, axis: .vertical)
            .lineLimit(3 ... 5)
        }

        Section("Status") {
          Picker("Status", selection: $draft.status) {
            Text("Active").tag(WatchlistStatus.active)
            Text("Researching").tag(WatchlistStatus.researching)
            Text("Waiting").tag(WatchlistStatus.waiting)
            Text("Ready").tag(WatchlistStatus.ready)
            Text("Archived").tag(WatchlistStatus.archived)
          }
        }

        if let errorMessage {
          Section {
            Text(errorMessage)
              .foregroundStyle(AppTheme.Colors.danger)
          }
        }
      }
      .navigationTitle("Add to Watchlist")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(isSaving ? "Saving..." : "Add") {
            Task {
              errorMessage = await onSave(draft)
              if errorMessage == nil {
                dismiss()
              }
            }
          }
          .disabled(isSaving || draft.symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}
