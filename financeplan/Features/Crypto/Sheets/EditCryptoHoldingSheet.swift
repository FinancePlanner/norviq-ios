import SwiftUI
import StockPlanShared

struct EditCryptoHoldingSheet: View {
    @ObservedObject var viewModel: CryptoViewModel
    let holding: CryptoPortfolioItemResponse
    @Environment(\.dismiss) private var dismiss

    @State private var quantity = ""
    @State private var buyPrice = ""
    @State private var isSaving = false

    init(viewModel: CryptoViewModel, holding: CryptoPortfolioItemResponse) {
        self.viewModel = viewModel
        self.holding = holding
        _quantity = State(initialValue: String(holding.quantity))
        _buyPrice = State(initialValue: String(holding.averageBuyPrice))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Asset Info") {
                    HStack {
                        Text("Symbol")
                        Spacer()
                        Text(holding.symbol).bold()
                    }
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(holding.name).foregroundStyle(.secondary)
                    }
                }

                Section("Position") {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)
                    TextField("Average Buy Price (USD)", text: $buyPrice)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(quantity.isEmpty || buyPrice.isEmpty || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
    }

    private func save() {
        guard let qty = Double(quantity), let price = Double(buyPrice) else { return }
        isSaving = true
        Task {
            let success = await viewModel.updateHolding(
                itemId: holding.id,
                symbol: holding.symbol,
                name: holding.name,
                quantity: qty,
                price: price
            )
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
}
