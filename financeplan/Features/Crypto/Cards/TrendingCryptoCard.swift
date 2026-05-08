import SwiftUI
import StockPlanShared

struct TrendingCryptoCard: View {
    let asset: CryptoQuoteResponse

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(asset.symbol.prefix(3))
                        .font(.caption.bold())
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                    Spacer()
                    Text("\(asset.changePercentage >= 0 ? "+" : "")\(asset.changePercentage.formatted(.percent.precision(.fractionLength(1))))")
                        .font(.caption2.bold())
                        .foregroundStyle(asset.changePercentage >= 0 ? .green : .red)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.name)
                        .font(.subheadline.bold())
                    Text(asset.price.formatted(.currency(code: "USD")))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100)
        }
    }
}
