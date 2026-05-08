import SwiftUI
import StockPlanShared

struct CryptoListRow: View {
    let asset: CryptoQuoteResponse

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(asset.symbol.prefix(1)))
                        .foregroundStyle(.white)
                        .bold()
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.headline)
                Text(asset.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(asset.price.formatted(.currency(code: "USD")))
                    .font(.subheadline.bold())
                Text("\(asset.changePercentage >= 0 ? "+" : "")\(asset.changePercentage.formatted(.percent.precision(.fractionLength(2))))")
                    .font(.caption)
                    .foregroundStyle(asset.changePercentage >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 12)
    }
}
