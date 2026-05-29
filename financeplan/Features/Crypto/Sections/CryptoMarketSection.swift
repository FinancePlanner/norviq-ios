import SwiftUI
import StockPlanShared

struct CryptoMarketSection: View {
    @ObservedObject var viewModel: CryptoViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.topAssets) { asset in
                NavigationLink(value: CryptoDetailRoute(symbol: asset.symbol, name: asset.name)) {
                    CryptoListRow(asset: asset)
                        .padding(.horizontal)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider()
                    .padding(.leading, 70)
                    .opacity(0.3)
            }
        }
    }
}
