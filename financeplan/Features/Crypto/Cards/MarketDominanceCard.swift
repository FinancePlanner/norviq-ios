import SwiftUI

struct MarketDominanceCard: View {
    let data: [CryptoViewModel.DominanceData]

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Market Dominance")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                // Animated multi-colored bar
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(data) { item in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.color.gradient)
                                .frame(width: max(0, (geometry.size.width * CGFloat(item.percentage / 100)) - 2))
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 12)

                // Legend
                HStack(spacing: 16) {
                    ForEach(data) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.symbol)
                                .font(.caption2.bold())
                            Text(item.percentage.formatted(.number.precision(.fractionLength(1))) + "%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
