import SwiftUI
import StockPlanShared

struct CryptoOverviewSection: View {
    @ObservedObject var viewModel: CryptoViewModel
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Market sentiment (derived from live coin movement)
            MarketSentimentCard(value: viewModel.sentimentValue, label: viewModel.sentimentLabel)
                .padding(.horizontal)

            // Your Balance
            if !viewModel.userHoldings.isEmpty {
                YourCryptoBalanceCard(holdings: viewModel.userHoldings, topAssets: viewModel.topAssets)
                    .padding(.horizontal)
            }

            // Market Dominance
            if !viewModel.dominance.isEmpty {
                MarketDominanceCard(data: viewModel.dominance)
                    .padding(.horizontal)
            }

            // Featured Card
            if let btc = viewModel.topAssets.first(where: { $0.symbol.contains("BTC") }) {
                FeaturedCryptoCard(asset: btc)
                    .padding(.horizontal)

                MarketQuickStatsCard(asset: btc)
                    .padding(.horizontal)
            }

            // Top Movers
            TopMoversSection(gainers: viewModel.topGainers, losers: viewModel.topLosers)

            // Market Leaders
            if viewModel.topAssets.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    OverviewSectionLabel(title: "Market Leaders", color: .blue)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.topAssets.prefix(10)) { asset in
                                TrendingCryptoCard(asset: asset)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }

            // Latest News Preview
            if !viewModel.marketNews.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    OverviewSectionLabel(title: "Latest News", color: .purple)

                    ForEach(viewModel.marketNews.prefix(3)) { news in
                        CryptoNewsRow(news: news)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }
}
