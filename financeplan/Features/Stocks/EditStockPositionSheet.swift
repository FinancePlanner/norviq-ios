import StockPlanShared
import SwiftUI

@MainActor
struct EditStockPositionSheet: View {
  let stock: StockResponse
  let isSaving: Bool
  let isDeleting: Bool
  let allocationImpactProvider: ((StockResponse) -> PortfolioAllocationImpact?)?
  let onCancel: () -> Void
  let onSave: @MainActor (StockResponse) async -> Bool
  let onDelete: @MainActor () async -> Bool

  @Environment(\.colorScheme) private var colorScheme
  @State private var sharesText: String
  @State private var buyPriceText: String
  @State private var category: AssetCategory
  @State private var notes: String
  @State private var successFeedbackTrigger = 0
  @State private var deleteConfirmationShown = false

  init(
    stock: StockResponse,
    isSaving: Bool,
    isDeleting: Bool = false,
    allocationImpactProvider: ((StockResponse) -> PortfolioAllocationImpact?)? = nil,
    onCancel: @escaping () -> Void,
    onSave: @escaping @MainActor (StockResponse) async -> Bool,
    onDelete: @escaping @MainActor () async -> Bool
  ) {
    self.stock = stock
    self.isSaving = isSaving
    self.isDeleting = isDeleting
    self.allocationImpactProvider = allocationImpactProvider
    self.onCancel = onCancel
    self.onSave = onSave
    self.onDelete = onDelete
    _sharesText = State(initialValue: String(stock.shares))
    _buyPriceText = State(initialValue: String(stock.buyPrice))
    _category = State(initialValue: stock.category)
    _notes = State(initialValue: stock.notes ?? "")
  }

  var body: some View {
    VStack(spacing: 0) {
      FormSheetHeader(
        title: "Edit position",
        subtitle: stock.symbol,
        onDismiss: onCancel
      )

      ScrollView {
        VStack(spacing: 16) {
          HStack {
            FormInfoTag(text: stock.symbol, icon: "chart.line.uptrend.xyaxis")
            Spacer()
          }

          FormCard(title: "Position") {
            FormRow(icon: "tag", iconColor: .purple, label: "Category") {
              Picker("", selection: $category) {
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
              text: $sharesText,
              keyboardType: .decimalPad
            )

            FormDivider()

            FormTextField(
              icon: "dollarsign.circle",
              iconColor: AppTheme.Colors.secondaryTint(for: colorScheme),
              placeholder: "Buy price",
              text: $buyPriceText,
              keyboardType: .decimalPad
            )
          }

          if let impact = currentDraft.flatMap({ allocationImpactProvider?($0) }), impact.didChange {
            AllocationImpactPreviewCard(impact: impact)
          }

          FormCard(title: "Notes") {
            HStack(spacing: 12) {
              Image(systemName: "note.text")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)

              TextField("Optional notes", text: $notes, axis: .vertical)
                .lineLimit(2...5)
                .typography(.label)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
          }

          Button(role: .destructive) {
            deleteConfirmationShown = true
          } label: {
            Label("Delete position", systemImage: "trash")
              .frame(maxWidth: .infinity)
              .typography(.label, weight: .semibold)
          }
          .padding(.vertical, 4)
          .disabled(isSaving || isDeleting)

          Spacer(minLength: 80)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
      }
      .scrollDismissesKeyboard(.interactively)

      FormActionBar(
        primaryLabel: isSaving ? "Saving…" : "Save changes",
        isLoading: isSaving,
        isDisabled: isSaving || isDeleting
      ) {
        guard let currentDraft else { return }
        Task {
          let didSave = await onSave(currentDraft)
          if didSave {
            successFeedbackTrigger += 1
          }
        }
      }
    }
    .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
    .presentationDragIndicator(.visible)
    .appSensoryFeedback(success: successFeedbackTrigger)
    .confirmationDialog(
      "Delete \(stock.symbol) from your portfolio?",
      isPresented: $deleteConfirmationShown,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        Task {
          _ = await onDelete()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This removes the holding from your portfolio. You can add it again later.")
    }
  }

  private var currentDraft: StockResponse? {
    guard let shares = Double(sharesText), let buyPrice = Double(buyPriceText) else { return nil }
    return StockResponse(
      id: stock.id,
      symbol: stock.symbol,
      shares: shares,
      buyPrice: buyPrice,
      buyDate: stock.buyDate,
      notes: notes.isEmpty ? nil : notes,
      category: category
    )
  }
}
