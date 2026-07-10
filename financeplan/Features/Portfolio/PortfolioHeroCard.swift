import StockPlanShared
import SwiftUI

struct PortfolioHeroCard: View {
  let colorScheme: ColorScheme
  let heroLabel: String
  let totalValue: Double
  let heroSubtitle: String
  let chartData: [ChartDataPoint]
  let selectedTimeRange: PortfolioScreen.TimeRange
  let totalShares: Double
  let averagePositionValue: Double
  let cashBalance: Double
  let onSelectTimeRange: (PortfolioScreen.TimeRange) -> Void

  var body: some View {
    GlassCard(cornerRadius: 22) {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text(heroLabel)
            .typography(.small, weight: .semibold)
            .foregroundStyle(.secondary)

          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(totalValue.currency)
              .typography(.displayNumber)
              .contentTransition(.numericText(value: totalValue))
              .appAnimation(AppMotion.state, value: totalValue)
            Text(heroSubtitle)
              .typography(.small)
              .foregroundStyle(.secondary)
          }

          HStack(spacing: 4) {
            Image(systemName: "minus")
            Text("No portfolio trend yet")
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)

        InteractiveLineChart(data: chartData, color: .green)
          .frame(minHeight: 160, maxHeight: .infinity)
          .padding(.horizontal, -12)

        GlassEffectContainer(spacing: 8) {
          HStack(spacing: 8) {
            ForEach(Array(PortfolioScreen.TimeRange.allCases), id: \.self) { range in
              PortfolioRangeButton(
                title: range.rawValue,
                isSelected: selectedTimeRange == range,
                tint: AppTheme.Colors.tint(for: colorScheme),
                action: { onSelectTimeRange(range) }
              )
            }
          }
        }

        HStack {
          PortfolioMetricPill(
            title: "Shares",
            value: totalShares.formatted(.number.precision(.fractionLength(0...2))),
            tint: AppTheme.Colors.secondaryTint(for: colorScheme)
          )
          PortfolioMetricPill(
            title: "Avg / position",
            value: averagePositionValue.currency,
            tint: AppTheme.Colors.tint(for: colorScheme)
          )
          PortfolioMetricPill(
            title: "Cash",
            value: cashBalance.currency,
            tint: .mint
          )
        }
      }
    }
    .foregroundStyle(.primary)
  }
}
