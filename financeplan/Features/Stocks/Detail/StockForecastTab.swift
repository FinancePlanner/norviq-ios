import StockPlanShared
import SwiftUI

struct StockForecastTab: View {
    let profile: StockComparisonProfile?
    @Binding var selectedScenario: StockProjectionScenarioKind
    let onEditDCF: () -> Void
    let onApplyDCFToValuation: (_ bearPrice: Double, _ basePrice: Double, _ bullPrice: Double) -> Void

    private var scenario: StockProjectionScenario? {
        profile?.projectionScenarios[selectedScenario]
    }

    var body: some View {
        if let profile, let scenario {
            LazyVStack(spacing: 16) {
                ProjectionScenarioHeaderCard(
                    profile: profile,
                    scenario: scenario,
                    selectedScenario: $selectedScenario
                )

                ForecastGrowthChartCard(scenario: scenario)

                ProjectionHighlightsCard(
                    profile: profile,
                    scenario: scenario,
                    scenarioKind: selectedScenario
                )

                if let dcfBase = profile.dcfBasePrice,
                   let dcfBear = profile.dcfBearPrice,
                   let dcfBull = profile.dcfBullPrice {
                    DCFValuationCard(
                        basePrice: dcfBase,
                        bearPrice: dcfBear,
                        bullPrice: dcfBull,
                        currentPrice: profile.currentPrice,
                        onEdit: onEditDCF,
                        onApplyToValuation: {
                            onApplyDCFToValuation(dcfBear, dcfBase, dcfBull)
                        }
                    )
                }

                ProjectionTableCard(scenario: scenario)

                ProjectionRangeChartCard(scenario: scenario)
            }
        } else {
            GlassCard {
                Text("Projection data is unavailable for this symbol right now.")
                    .typography(.small)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
