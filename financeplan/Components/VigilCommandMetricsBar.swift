import SwiftUI

/// Command-center metrics strip mirroring web `CommandStatusBar`.
struct VigilCommandMetricsBar: View {
  @Environment(\.colorScheme) private var colorScheme

  let netWorth: Double
  let periodDeltaPercent: Double?
  let spendingThisMonth: Double?
  let agenticLabel: String

  init(
    netWorth: Double,
    periodDeltaPercent: Double?,
    spendingThisMonth: Double? = nil,
    agenticLabel: String = "AGENTIC · ACTIVE"
  ) {
    self.netWorth = netWorth
    self.periodDeltaPercent = periodDeltaPercent
    self.spendingThisMonth = spendingThisMonth
    self.agenticLabel = agenticLabel
  }

  var body: some View {
    // Only ever rendered inside the command deck, so this
    // GlassCard call has no Classic-side effect — it purely retires
    // vigilGlassCard in favour of the same background every other card uses.
    GlassCard(cornerRadius: 14, padding: 0) {
      HStack(alignment: .center, spacing: 14) {
        metricColumn(label: "NET WORTH", value: netWorth.currency)

        if let periodDeltaPercent {
          metricColumn(
            label: "PERIOD MOVE",
            value: String(format: "%+.1f%%", periodDeltaPercent * 100),
            valueColor: periodDeltaPercent >= 0
              ? AppTheme.Colors.successText(for: colorScheme)
              : AppTheme.Colors.dangerText(for: colorScheme)
          )
        }

        if let spendingThisMonth {
          metricColumn(label: "SPEND · MONTH", value: spendingThisMonth.currency)
        }

        Spacer(minLength: 8)

        agenticPill
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
    }
  }

  private func metricColumn(
    label: String,
    value: String,
    valueColor: Color? = nil
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .vigilOverline()
        .foregroundStyle(.secondary)
      Text(value)
        .font(.subheadline.weight(.bold).monospacedDigit())
        .foregroundStyle(valueColor ?? AppTheme.Colors.foreground(for: colorScheme))
    }
  }

  private var agenticPill: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(AppTheme.Colors.secondaryTint(for: colorScheme))
        .frame(width: 6, height: 6)
        .shadow(color: AppTheme.Colors.secondaryTint(for: colorScheme).opacity(0.8), radius: 4)
      Text(agenticLabel)
        .font(.caption2.weight(.bold).monospaced())
        .tracking(0.8)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme))
    .background(
      Capsule()
        .fill(AppTheme.Colors.secondaryTint(for: colorScheme).opacity(0.14))
        .overlay(
          Capsule()
            .stroke(AppTheme.Colors.secondaryTint(for: colorScheme).opacity(0.45), lineWidth: 1)
        )
    )
  }
}

#Preview {
  VigilCommandMetricsBar(
    netWorth: 2_450_120.50,
    periodDeltaPercent: 0.015,
    spendingThisMonth: 3_500
  )
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}
