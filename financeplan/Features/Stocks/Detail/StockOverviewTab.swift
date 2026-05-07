import StockPlanShared
import SwiftUI

struct StockOverviewTab: View {
    let details: StockDetails?
    let valuation: StockValuationRequest?
    let marketSnapshot: StockMarketSnapshot?
    let analystConsensus: StockAnalystConsensus?
    let analystConsensusMessage: String?
    let basicFinancials: StockBasicFinancials?
    let errorMessage: String?
    let onEditValuation: () -> Void
    let onEditPosition: () -> Void
    let onSellPosition: () -> Void

    var body: some View {
        LazyVStack(spacing: 16) {
            if let details {
                StockPositionOverviewCard(
                    details: details,
                    onEditPosition: onEditPosition,
                    onSellPosition: onSellPosition
                )
            }

            if let marketSnapshot {
                StockMarketSnapshotCard(snapshot: marketSnapshot)
            } else {
                GlassCard {
                    Text("No live quote data is available for this stock right now.")
                        .typography(.small)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let analystConsensus {
                StockConsensusCard(consensus: analystConsensus)
            } else {
                StockConsensusPlaceholderCard(
                    message: analystConsensusMessage,
                    isWarning: analystConsensusMessage != nil
                )
            }

            if let basicFinancials {
                StockBasicFinancialsCard(financials: basicFinancials)
            } else {
                StockBasicFinancialsPlaceholderCard()
            }

            StockValuationSummaryCard(
                symbol: details?.symbol,
                currentPrice: marketSnapshot?.currentPrice,
                valuation: valuation,
                onEditValuation: onEditValuation
            )

            if let errorMessage {
                GlassCard {
                    Text(errorMessage)
                        .typography(.small)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
