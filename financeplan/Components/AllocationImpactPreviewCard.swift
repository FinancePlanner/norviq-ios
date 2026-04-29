import SwiftUI

struct AllocationImpactPreviewCard: View {
  let impact: PortfolioAllocationImpact

  var body: some View {
    GlassCard {
      HStack(spacing: 12) {
        Image(systemName: impact.afterPercentage >= impact.beforePercentage ? "arrow.up.forward" : "arrow.down.forward")
          .font(.headline.weight(.semibold))
          .foregroundStyle(impact.afterPercentage >= impact.beforePercentage ? .green : .orange)
          .frame(width: 28)

        VStack(alignment: .leading, spacing: 4) {
          Text("\(impact.symbol) allocation impact")
            .typography(.caption, weight: .semibold)
            .foregroundStyle(.secondary)

          Text(Self.formattedChange(impact))
            .typography(.label, weight: .bold)
            .monospacedDigit()
        }

        Spacer()
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(impact.symbol) allocation changes from \(Self.formattedPercent(impact.beforePercentage)) to \(Self.formattedPercent(impact.afterPercentage))")
    }
  }

  private static func formattedChange(_ impact: PortfolioAllocationImpact) -> String {
    "\(formattedPercent(impact.beforePercentage)) => \(formattedPercent(impact.afterPercentage))"
  }

  private static func formattedPercent(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1))) + "%"
  }
}
