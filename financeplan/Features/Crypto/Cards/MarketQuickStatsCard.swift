import SwiftUI
import StockPlanShared

struct MarketQuickStatsCard: View {
    let asset: CryptoQuoteResponse

    var body: some View {
        GlassCard(cornerRadius: 16) {
            HStack(spacing: 0) {
                QuickStatColumn(
                    title: "24h Volume",
                    value: shortFormat(asset.volume ?? 0)
                )

                Divider()
                    .frame(height: 36)
                    .padding(.horizontal, 8)

                QuickStatColumn(
                    title: "Market Cap",
                    value: shortFormat(asset.marketCap ?? 0)
                )

                Divider()
                    .frame(height: 36)
                    .padding(.horizontal, 8)

                QuickStatColumn(
                    title: "24h Range",
                    value: "\(shortPrice(asset.dayLow)) – \(shortPrice(asset.dayHigh))"
                )
            }
        }
    }

    private func shortFormat(_ value: Double) -> String {
        if value >= 1_000_000_000_000 { return String(format: "$%.1fT", value / 1_000_000_000_000) }
        if value >= 1_000_000_000 { return String(format: "$%.1fB", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        return "$\(Int(value))"
    }

    private func shortPrice(_ value: Double?) -> String {
        guard let v = value else { return "–" }
        if v >= 1000 { return "$\(Int(v).formatted())" }
        return v.formatted(.currency(code: "USD"))
    }
}

struct QuickStatColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
