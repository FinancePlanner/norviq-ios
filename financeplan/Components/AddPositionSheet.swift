import SwiftUI
import StockPlanShared

struct AddPositionDraft: Equatable {
  var symbol: String
  var companyName: String?
  var shares: String = ""
  var buyPrice: String = ""
  var buyDate: Date = .now
  var notes: String = ""
  var category: AssetCategory = .stock
  var symbolLocked: Bool = false
}

struct AddPositionSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  let title: String
  @State var draft: AddPositionDraft
  let isSaving: Bool
  let allocationImpactProvider: ((AddPositionDraft) -> PortfolioAllocationImpact?)?
  let onSave: @MainActor (AddPositionDraft) async -> String?

  @State private var errorMessage: String?
  @State private var successFeedbackTrigger = 0

  init(
    title: String,
    draft: AddPositionDraft,
    isSaving: Bool,
    allocationImpactProvider: ((AddPositionDraft) -> PortfolioAllocationImpact?)? = nil,
    onSave: @escaping @MainActor (AddPositionDraft) async -> String?
  ) {
    self.title = title
    _draft = State(initialValue: draft)
    self.isSaving = isSaving
    self.allocationImpactProvider = allocationImpactProvider
    self.onSave = onSave
  }

  var body: some View {
    VStack(spacing: 0) {
      FormSheetHeader(title: title, onDismiss: { dismiss() })

      ScrollView {
        VStack(spacing: 16) {
          // MARK: - Stock section
          FormCard(title: "Stock") {
            if let companyName = draft.companyName, !companyName.isEmpty {
              FormRow(icon: "building.2", iconColor: .secondary, label: companyName) {
                EmptyView()
              }
              FormDivider()
            }

            FormTextField(
              icon: "magnifyingglass",
              iconColor: AppTheme.Colors.tint(for: colorScheme),
              placeholder: "Symbol (e.g. AAPL)",
              text: $draft.symbol,
              autocapitalization: .characters,
              disableAutocorrection: true
            )
            .disabled(draft.symbolLocked)
              .opacity(draft.symbolLocked ? 0.6 : 1)
          }

          if let impact = allocationImpactProvider?(draft), impact.didChange {
            AllocationImpactPreviewCard(impact: impact)
          }

          // MARK: - Position section
          FormCard(title: "Position") {
            FormRow(icon: "tag", iconColor: .purple, label: "Category") {
              Picker("", selection: $draft.category) {
                ForEach(AssetCategory.allCases, id: \.self) { category in
                  Text(category.rawValue.capitalized).tag(category)
                }
              }
              .labelsHidden()
            }

            FormDivider()

            FormTextField(
              icon: "number",
              placeholder: "Shares",
              text: $draft.shares,
              keyboardType: .decimalPad
            )

            FormDivider()

            FormTextField(
              icon: "dollarsign.circle",
              iconColor: AppTheme.Colors.secondaryTint(for: colorScheme),
              placeholder: "Buy price",
              text: $draft.buyPrice,
              keyboardType: .decimalPad
            )

            FormDivider()

            FormRow(icon: "calendar", iconColor: .orange, label: "Buy date") {
              DatePicker("", selection: $draft.buyDate, displayedComponents: .date)
                .labelsHidden()
            }
          }

          // MARK: - Notes section
          FormCard(title: "Notes") {
            HStack(spacing: 12) {
              Image(systemName: "note.text")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)

              TextField("Optional notes", text: $draft.notes, axis: .vertical)
                .lineLimit(3...6)
                .typography(.label)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
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
        primaryLabel: isSaving ? "Saving…" : "Save",
        isLoading: isSaving,
        isDisabled: !isValid || isSaving
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

  private var isValid: Bool {
    !draft.symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && Double(draft.shares) != nil
      && Double(draft.buyPrice) != nil
  }
}
