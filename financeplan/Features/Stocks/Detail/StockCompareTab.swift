import StockPlanShared
import SwiftUI

struct StockCompareTab: View {
    @ObservedObject var viewModel: StockDetailsViewModel

    @Environment(\.colorScheme) private var colorScheme

    private var primaryProfile: StockComparisonProfile? {
        viewModel.primaryComparisonProfile
    }

    private var peerOptions: [StockComparisonProfile] {
        viewModel.availablePeerProfiles
    }

    private var comparisonProfiles: [StockComparisonProfile] {
        viewModel.comparisonProfiles
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
                                selectedSymbol: viewModel.selectedPeerSymbol(at: 0),
                                options: peerOptions
                            ) { symbol in
                                viewModel.updatePeerSymbol(symbol, slot: 0)
                            }

                            ComparisonPeerPicker(
                                title: "Peer 2",
                                selectedSymbol: viewModel.selectedPeerSymbol(at: 1),
                                options: peerOptions
                            ) { symbol in
                                viewModel.updatePeerSymbol(symbol, slot: 1)
                            }
                        }

                        HStack(spacing: 10) {
                            HeroMetricPill(
                                title: primaryProfile.symbol,
                                value: primaryProfile.currentPrice.currency,
                                tint: AppTheme.Colors.tint(for: colorScheme)
                            )

                            ForEach(viewModel.selectedPeerProfiles) { peer in
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
                    response: viewModel.comparisonChartResponse,
                    primarySymbol: primaryProfile.symbol,
                    selectedRange: viewModel.selectedComparisonChartRange,
                    isLoading: viewModel.isComparisonChartLoading,
                    errorMessage: viewModel.comparisonChartErrorMessage,
                    onSelectRange: viewModel.switchComparisonChartRange
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
