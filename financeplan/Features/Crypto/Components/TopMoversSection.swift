import SwiftUI
import StockPlanShared

struct TopMoversSection: View {
    let gainers: [CryptoMarketCoin]
    let losers: [CryptoMarketCoin]
    @State private var showingGainers = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(showingGainers ? "Top Gainers" : "Top Losers")
                    .font(.headline)
                Spacer()
                Picker("Movers", selection: $showingGainers) {
                    Text("Gainers").tag(true)
                    Text("Losers").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(showingGainers ? gainers : losers) { coin in
                        if let route = coin.detailRoute {
                            NavigationLink(value: route) { MoverCard(coin: coin) }
                                .buttonStyle(.plain)
                        } else {
                            MoverCard(coin: coin)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct MoverCard: View {
    let coin: CryptoMarketCoin

    private var change: Double { coin.changePct ?? 0 }
    private var isPositive: Bool { change >= 0 }

    var body: some View {
        GlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(coin.symbol)
                        .font(.caption.bold())
                    Spacer()
                    Image(systemName: isPositive ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                        .font(.caption2)
                        .foregroundStyle(isPositive ? .green : .red)
                }

                // changePct is in percent points (2.5 = 2.5%), not a fraction.
                Text(formatCryptoPercent(change, digits: 1))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(isPositive ? .green : .red)

                Text(coin.price.formatted(.currency(code: "USD").precision(.significantDigits(2...6))))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 95)
        }
    }
}
