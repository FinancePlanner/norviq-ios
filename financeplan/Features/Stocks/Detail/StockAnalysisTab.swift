import StockPlanShared
import SwiftUI

struct StockAnalysisTab: View {
    let details: StockResponse?
    let profile: StockComparisonProfile?
    let analysisMetrics: StockAnalysisMetrics?
    let analysisMetricsMessage: String?
    let valuation: StockValuationRequest?
    let onEditAnalysis: () -> Void
    let onEditDCF: () -> Void
    let onApplyDCFToValuation: (_ bearPrice: Double, _ basePrice: Double, _ bullPrice: Double) -> Void

    private var resolvedProfile: StockComparisonProfile? {
        if let profile {
            return profile
        }

        guard let analysisMetrics else { return nil }
        return StockComparisonProfile(
            symbol: analysisMetrics.symbol.uppercased(),
            companyName: analysisMetrics.symbol.uppercased(),
            currentPrice: analysisMetrics.currentPrice ?? 0,
            marketCap: analysisMetrics.marketCap ?? 0,
            sharesOutstanding: analysisMetrics.sharesOutstanding ?? 0,
            metrics: analysisMetrics.comparisonMetrics,
            projectionScenarios: [:],
            dcfBasePrice: analysisMetrics.dcfBasePrice,
            dcfBearPrice: analysisMetrics.dcfBearPrice,
            dcfBullPrice: analysisMetrics.dcfBullPrice
        )
    }

    var body: some View {
        LazyVStack(spacing: 16) {
            if let resolvedProfile, analysisMetrics != nil {
                if let intrinsicValue = resolvedProfile.dcfBasePrice ?? resolvedProfile.metrics[.dcfFairValue] {
                    SharePriceIntrinsicValueCard(
                        currentPrice: resolvedProfile.currentPrice,
                        intrinsicValue: intrinsicValue,
                        bearValue: resolvedProfile.dcfBearPrice,
                        bullValue: resolvedProfile.dcfBullPrice,
                        onEdit: onEditDCF,
                        onApplyToValuation: dcfApplyAction(
                            bearPrice: resolvedProfile.dcfBearPrice,
                            basePrice: intrinsicValue,
                            bullPrice: resolvedProfile.dcfBullPrice
                        )
                    )
                }

                StockCurrentMetricsCard(profile: resolvedProfile)
                StockFundamentalsCard(profile: resolvedProfile)
            } else {
                StockAnalysisPlaceholderCard(
                    message: analysisMetricsMessage,
                    isWarning: analysisMetricsMessage != nil
                )
            }

            StockThesisCard(
                symbol: details?.symbol,
                details: details,
                analysis: details?.notes,
                valuationRationale: valuation?.rationale,
                canEdit: details != nil,
                onEdit: onEditAnalysis
            )
        }
    }

    private func dcfApplyAction(
        bearPrice: Double?,
        basePrice: Double?,
        bullPrice: Double?
    ) -> (() -> Void)? {
        guard let bearPrice, let basePrice, let bullPrice else { return nil }
        return {
            onApplyDCFToValuation(bearPrice, basePrice, bullPrice)
        }
    }
}
