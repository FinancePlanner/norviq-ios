import SwiftUI
import StockPlanShared

struct CryptoMarketSection: View {
    @ObservedObject var viewModel: CryptoViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.topAssets) { asset in
                CryptoListRow(asset: asset)
                    .padding(.horizontal)
                Divider()
                    .padding(.leading, 70)
                    .opacity(0.3)
            }
        }
    }
}
