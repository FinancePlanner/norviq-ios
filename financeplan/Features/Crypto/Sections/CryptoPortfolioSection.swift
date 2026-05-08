import SwiftUI
import StockPlanShared

struct CryptoPortfolioSection: View {
    @ObservedObject var viewModel: CryptoViewModel
    @Binding var editingHolding: CryptoPortfolioItemResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if viewModel.userHoldings.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bitcoinsign.circle")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("No Crypto Holdings")
                        .font(.headline)
                    Text("Add your first cryptocurrency to start tracking your portfolio performance.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                YourCryptoBalanceCard(holdings: viewModel.userHoldings, topAssets: viewModel.topAssets)
                    .padding(.horizontal)

                Text("Your Assets")
                    .font(.headline)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    ForEach(viewModel.userHoldings) { holding in
                        let currentPrice = viewModel.topAssets.first(where: { $0.symbol == holding.symbol })?.price
                        CryptoHoldingRow(holding: holding, currentPrice: currentPrice)
                            .padding(.horizontal)
                            .contextMenu {
                                Button {
                                    editingHolding = holding
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.removeHolding(itemId: holding.id)
                                    }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
}
