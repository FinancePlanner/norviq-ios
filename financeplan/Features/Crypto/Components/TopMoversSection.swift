import SwiftUI
import StockPlanShared

struct TopMoversSection: View {
    let gainers: [CryptoQuoteResponse]
    let losers: [CryptoQuoteResponse]
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
                    ForEach(showingGainers ? gainers : losers) { asset in
                        MoverCard(asset: asset)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct MoverCard: View {
    let asset: CryptoQuoteResponse

    private var isPositive: Bool { asset.changePercentage >= 0 }

    var body: some View {
        GlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(asset.symbol.replacingOccurrences(of: "USD", with: ""))
                        .font(.caption.bold())
                    Spacer()
                    Image(systemName: isPositive ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                        .font(.caption2)
                        .foregroundStyle(isPositive ? .green : .red)
                }

                Text(asset.changePercentage.formatted(.percent.precision(.fractionLength(1))))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(isPositive ? .green : .red)

                Text(asset.price.formatted(.currency(code: "USD")))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 95)
        }
    }
}
