import SwiftUI
import StockPlanShared

struct CryptoNewsSection: View {
    @ObservedObject var viewModel: CryptoViewModel

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.marketNews) { news in
                CryptoNewsCard(news: news)
                    .padding(.horizontal)
            }
        }
    }
}
