import SwiftUI

/// `GlassCard` wrapper with the standard detail-tab header (title + subtitle),
/// matching the layout used by `StockPriceChartTab`.
struct ChartCard<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .typography(.small, weight: .semibold)

                    if let subtitle {
                        Text(subtitle)
                            .typography(.nano)
                            .foregroundStyle(.secondary)
                    }
                }

                content
            }
        }
    }
}
