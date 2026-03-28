import StockPlanShared
import SwiftUI

struct AddWatchlistDraft: Equatable {
  var symbol: String = ""
  var note: String = ""
  var status: WatchlistStatus = .active
}

struct AddWatchlistSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  @State var draft: AddWatchlistDraft
  let isSaving: Bool
  let onSave: @MainActor (AddWatchlistDraft) async -> String?

  @State private var errorMessage: String?
  @State private var successFeedbackTrigger = 0

  var body: some View {
    VStack(spacing: 0) {
      FormSheetHeader(title: "Add to Watchlist", onDismiss: { dismiss() })

      ScrollView {
        VStack(spacing: 16) {
          // MARK: - Symbol
          FormCard(title: "Stock") {
            FormTextField(
              icon: "magnifyingglass",
              iconColor: AppTheme.Colors.tint(for: colorScheme),
              placeholder: "Symbol (e.g. TSLA)",
              text: $draft.symbol,
              autocapitalization: .characters,
              disableAutocorrection: true
            )
          }

          // MARK: - Note
          FormCard(title: "Why are you watching it?") {
            HStack(spacing: 12) {
              Image(systemName: "text.quote")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)

              TextField("Optional note", text: $draft.note, axis: .vertical)
                .lineLimit(3...5)
                .typography(.label)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
          }

          // MARK: - Status
          FormCard(title: "Status") {
            FormRow(icon: "flag", iconColor: .orange, label: "Status") {
              Picker("Status", selection: $draft.status) {
                Text("Active").tag(WatchlistStatus.active)
                Text("Researching").tag(WatchlistStatus.researching)
                Text("Waiting").tag(WatchlistStatus.waiting)
                Text("Ready").tag(WatchlistStatus.ready)
                Text("Archived").tag(WatchlistStatus.archived)
              }
              .labelsHidden()
            }
          }

          // MARK: - Error
          if let errorMessage {
            FormErrorBanner(message: errorMessage)
          }

          Spacer(minLength: 80)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
      }
      .scrollDismissesKeyboard(.interactively)

      // MARK: - Action bar
      FormActionBar(
        primaryLabel: isSaving ? "Adding…" : "Add to Watchlist",
        isLoading: isSaving,
        isDisabled: draft.symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving
      ) {
        Task {
          errorMessage = await onSave(draft)
          if errorMessage == nil {
            successFeedbackTrigger += 1
            dismiss()
          }
        }
      }
    }
    .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
    .presentationDragIndicator(.visible)
    .appSensoryFeedback(success: successFeedbackTrigger)
  }
}
