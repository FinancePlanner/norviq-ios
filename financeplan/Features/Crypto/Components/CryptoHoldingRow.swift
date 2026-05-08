import SwiftUI
import StockPlanShared

struct CryptoHoldingRow: View {
    let holding: CryptoPortfolioItemResponse
    let currentPrice: Double?

    var value: Double {
        (currentPrice ?? holding.averageBuyPrice) * holding.quantity
    }

    var profit: Double {
        let current = currentPrice ?? holding.averageBuyPrice
        return (current - holding.averageBuyPrice) * holding.quantity
    }

    var profitPercent: Double {
        let current = currentPrice ?? holding.averageBuyPrice
        guard holding.averageBuyPrice != 0 else { return 0 }
        return (current - holding.averageBuyPrice) / holding.averageBuyPrice
    }

    var body: some View {
        GlassCard(cornerRadius: 12) {
            HStack(spacing: 16) {
                HoldingCircle(symbol: holding.symbol)

                VStack(alignment: .leading, spacing: 4) {
                    Text(holding.name)
                        .font(.subheadline.bold())
                    Text("\(holding.quantity.formatted(.number.precision(.fractionLength(0...8)))) \(holding.symbol.replacingOccurrences(of: "USD", with: ""))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(value.formatted(.currency(code: "USD")))
                        .font(.subheadline.bold())
                    HStack(spacing: 4) {
                        Image(systemName: profit >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(profit >= 0 ? "+" : "")\(profitPercent.formatted(.percent.precision(.fractionLength(2))))")
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(profit >= 0 ? .green : .red)
                }
            }
        }
    }
}
