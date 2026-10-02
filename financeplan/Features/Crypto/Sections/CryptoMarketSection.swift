import SwiftUI
import StockPlanShared

/// Market segment: timeframe picker, heat-map, top/worst performers, the
/// all-time-high board and the ranked coin list, all from one markets call.
struct CryptoMarketSection: View {
    @ObservedObject var viewModel: CryptoMarketsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CryptoTimeframePicker(viewModel: viewModel)
                .padding(.horizontal)

            if let response = viewModel.response {
                content(response)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView(
                    "Crypto markets are warming up",
                    systemImage: "chart.bar.xaxis",
                    description: Text(error)
                )
            }
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func content(_ response: CryptoMarketsResponse) -> some View {
        summary(response)
            .padding(.horizontal)

        if response.isStale || viewModel.errorMessage != nil {
            Label("Showing the last available data.", systemImage: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }

        CryptoHeatmapCard(response: response)
            .padding(.horizontal)

        CryptoPerformersCard(response: response)
            .padding(.horizontal)

        CryptoAthBoardCard(board: response.athBoard)
            .padding(.horizontal)

        VStack(alignment: .leading, spacing: 8) {
            OverviewSectionLabel(title: "All coins", color: .blue)
            LazyVStack(spacing: 0) {
                ForEach(response.coins) { coin in
                    CryptoMarketCoinRow(
                        coin: coin,
                        value: coin.changePct.map { formatCryptoPercent($0) },
                        caption: coin.rank.map { "#\($0) · \(coin.name)" }
                    )
                    .padding(.horizontal)
                    Divider().opacity(0.3).padding(.leading)
                }
            }
        }

        if let attribution = response.attribution {
            Text(attribution)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    private func summary(_ response: CryptoMarketsResponse) -> some View {
        HStack(spacing: 16) {
            if let cap = response.summary.totalMarketCap {
                stat("Market cap", cap.formatted(.currency(code: "USD").notation(.compactName).precision(.fractionLength(2))))
            }
            if let dominance = response.summary.btcDominancePct {
                stat("BTC dominance", String(format: "%.1f%%", dominance))
            }
            stat("Up / down", "\(response.summary.advancers) / \(response.summary.decliners)")
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }
}
