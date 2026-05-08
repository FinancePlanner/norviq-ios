import SwiftUI
import StockPlanShared
import Factory
import OSLog

private let cryptoHomeLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "CryptoHome"
)

struct AddCryptoHoldingSheet: View {
    @ObservedObject var viewModel: CryptoViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var symbol = ""
    @State private var name = ""
    @State private var quantity = ""
    @State private var buyPrice = ""
    @State private var isSaving = false
    @State private var searchText = ""
    @State private var allAssets: [CryptoAssetResponse] = []
    @State private var isLoadingAssets = false

    private let cryptoService: any CryptoServicing = Container.shared.cryptoService()

    var filteredAssets: [CryptoAssetResponse] {
        if searchText.isEmpty {
            return allAssets.prefix(20).map { $0 }
        }
        return allAssets.filter {
            $0.symbol.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }.prefix(50).map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Search Asset") {
                    ZStack(alignment: .trailing) {
                        TextField("Search by symbol or name", text: $searchText)

                        if isLoadingAssets {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }

                    if !filteredAssets.isEmpty && symbol.isEmpty {
                        List {
                            ForEach(filteredAssets) { asset in
                                Button {
                                    self.symbol = asset.symbol
                                    self.name = asset.name
                                    self.searchText = asset.symbol
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(asset.symbol).bold()
                                            Text(asset.name).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(minHeight: 200, maxHeight: 300)
                    }
                }

                if !symbol.isEmpty {
                    Section("Selected Asset") {
                        HStack {
                            Text(symbol).bold()
                            Text("-")
                            Text(name)
                            Spacer()
                            Button("Clear") {
                                symbol = ""
                                name = ""
                                searchText = ""
                            }
                            .font(.caption)
                        }
                    }

                    Section("Position") {
                        TextField("Quantity", text: $quantity)
                            .keyboardType(.decimalPad)
                        TextField("Average Buy Price (USD)", text: $buyPrice)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Add Crypto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        save()
                    }
                    .disabled(symbol.isEmpty || quantity.isEmpty || buyPrice.isEmpty || isSaving)
                }
            }
            .task {
                isLoadingAssets = true
                do {
                    allAssets = try await cryptoService.fetchCryptoList()
                } catch {
                    cryptoHomeLogger.error("Failed to fetch crypto list: \(error.localizedDescription, privacy: .public)")
                }
                isLoadingAssets = false
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
            let success = await viewModel.addHolding(symbol: symbol, name: name, quantity: qty, price: price)
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
}
