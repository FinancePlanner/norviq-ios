import SwiftUI
import StockPlanShared

struct YourCryptoBalanceCard: View {
    let holdings: [CryptoPortfolioItemResponse]
    let topAssets: [CryptoQuoteResponse]

    var totalValue: Double {
        holdings.reduce(0) { total, holding in
            let currentPrice = topAssets.first(where: { $0.symbol == holding.symbol })?.price ?? holding.averageBuyPrice
            return total + (holding.quantity * currentPrice)
        }
    }

    var totalProfit: Double {
        holdings.reduce(0) { total, holding in
            let currentPrice = topAssets.first(where: { $0.symbol == holding.symbol })?.price ?? holding.averageBuyPrice
            let currentValue = holding.quantity * currentPrice
            let costBasis = holding.quantity * holding.averageBuyPrice
            return total + (currentValue - costBasis)
        }
    }

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Crypto Balance")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(totalValue.formatted(.currency(code: "USD")))
                            .font(.title2.bold())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(totalProfit >= 0 ? "+" : "")\(totalProfit.formatted(.currency(code: "USD")))")
                            .font(.subheadline.bold())
                            .foregroundStyle(totalProfit >= 0 ? .green : .red)
                        Text("Profit")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(holdings) { holding in
                            HoldingCircle(symbol: holding.symbol)
                        }
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.orange.opacity(0.6), .purple.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
