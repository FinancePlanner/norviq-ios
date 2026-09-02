import StockPlanShared
import SwiftUI

/// Takes plain values rather than the view model so it only re-renders when
/// the comparison inputs change, not on every StockDetailsViewModel mutation.
struct StockCompareTab: View {
    let primaryProfile: StockComparisonProfile?
    let peerOptions: [StockComparisonProfile]
    let comparisonProfiles: [StockComparisonProfile]
    let selectedPeerProfiles: [StockComparisonProfile]
    let selectedPeerSymbols: [String]
    let comparisonChartResponse: PriceChartComparisonResponse?
    let selectedComparisonChartRange: PriceChartRange
    let isComparisonChartLoading: Bool
    let comparisonChartErrorMessage: String?
    let onUpdatePeerSymbol: (String, Int) -> Void
    let onSelectComparisonChartRange: (PriceChartRange) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private func selectedPeerSymbol(at slot: Int) -> String {
        guard selectedPeerSymbols.indices.contains(slot) else { return "" }
        return selectedPeerSymbols[slot]
    }

    var body: some View {
        if let primaryProfile {
            LazyVStack(spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Peer comparison")
                            .typography(.small, weight: .semibold)

                        Text("Compare valuation, growth, and profitability side by side against two peers.")
                            .typography(.nano)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            ComparisonPeerPicker(
                                title: "Peer 1",
                                selectedSymbol: selectedPeerSymbol(at: 0),
                                options: peerOptions
                            ) { symbol in
                                onUpdatePeerSymbol(symbol, 0)
                            }

                            ComparisonPeerPicker(
                                title: "Peer 2",
                                selectedSymbol: selectedPeerSymbol(at: 1),
                                options: peerOptions
                            ) { symbol in
                                onUpdatePeerSymbol(symbol, 1)
                            }
                        }

                        HStack(spacing: 10) {
                            HeroMetricPill(
                                title: primaryProfile.symbol,
                                value: primaryProfile.currentPrice.currency,
                                tint: AppTheme.Colors.tint(for: colorScheme)
                            )

                            ForEach(selectedPeerProfiles) { peer in
                                HeroMetricPill(
                                    title: peer.symbol,
                                    value: peer.currentPrice.currency,
                                    tint: AppTheme.Colors.secondaryTint(for: colorScheme)
                                )
                            }
                        }
                    }
                }

                PriceComparisonChartCard(
                    response: comparisonChartResponse,
                    primarySymbol: primaryProfile.symbol,
                    selectedRange: selectedComparisonChartRange,
                    isLoading: isComparisonChartLoading,
                    errorMessage: comparisonChartErrorMessage,
                    onSelectRange: onSelectComparisonChartRange
                )

                ForEach(StockComparisonMetricGroup.allCases) { group in
                    ComparisonMetricTableCard(
                        group: group,
                        profiles: comparisonProfiles
                    )
                }
            }
        } else {
            GlassCard {
                Text("Comparison data will appear after the stock loads.")
                    .typography(.small)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
