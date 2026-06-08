import Charts
import SwiftUI

/// Donut chart of the analyst recommendation mix. Colors match the
/// distribution rows shown below it in `StockConsensusCard`. Tapping a sector
/// highlights it and shows its rating count in the center.
struct ConsensusDonutChart: View {
    let consensus: StockAnalystConsensus

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCount: Int?

    private var buckets: [StockAnalystConsensusBucket] {
        consensus.buckets.filter { $0.count > 0 }
    }

    /// Maps the angular selection (a cumulative count along the ring) back to
    /// the bucket whose slice contains it.
    private var selectedBucket: StockAnalystConsensusBucket? {
        guard let selectedCount else { return nil }
        var running = 0
        for bucket in buckets {
            running += bucket.count
            if selectedCount <= running { return bucket }
        }
        return nil
    }

    private func tint(for kind: StockAnalystConsensusBucketKind) -> Color {
        switch kind {
        case .strongBuy: return AppTheme.Colors.success
        case .buy: return AppTheme.Colors.tint(for: colorScheme)
        case .hold: return AppTheme.Colors.warning
        case .sell: return Color.orange
        case .strongSell: return AppTheme.Colors.danger
        }
    }

    var body: some View {
        if consensus.totalRatings > 0 {
            Chart(buckets) { bucket in
                SectorMark(
                    angle: .value("Ratings", bucket.count),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(tint(for: bucket.kind))
                .opacity(opacity(for: bucket))
            }
            .chartAngleSelection(value: $selectedCount)
            .chartLegend(.hidden)
            .frame(height: 200)
            .overlay { centerLabel }
            .animation(.snappy(duration: 0.2), value: selectedBucket)
        }
    }

    private func opacity(for bucket: StockAnalystConsensusBucket) -> Double {
        guard let selectedBucket else { return 1 }
        return selectedBucket.id == bucket.id ? 1 : 0.35
    }

    @ViewBuilder
    private var centerLabel: some View {
        VStack(spacing: 2) {
            if let selectedBucket {
                Text("\(selectedBucket.count)")
                    .typography(.title, weight: .bold)
                    .monospacedDigit()
                Text(selectedBucket.kind.title)
                    .typography(.nano, weight: .semibold)
                    .foregroundStyle(.secondary)
            } else {
                Text(StockMetricFormatter.percentText(consensus.bullishShare))
                    .typography(.title, weight: .bold)
                    .monospacedDigit()
                Text("Bullish")
                    .typography(.nano, weight: .semibold)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
