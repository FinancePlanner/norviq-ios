import SwiftUI

struct ChartBuilderDashboardCard: View {
  let onOpen: () -> Void

  var body: some View {
    GlassCard {
      Button(action: onOpen) {
        HStack(spacing: 12) {
          Image(systemName: "chart.xyaxis.line")
            .font(.title2)
            .foregroundStyle(Color.accentColor)
            .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 4) {
            Text("Chart Builder")
              .font(.headline)
            Text("Plot financial metrics, compare peers, and export CSV data.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.leading)
          }

          Spacer()

          Image(systemName: "chevron.right")
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityHint("Search for a stock and build a custom metrics chart")
    }
  }
}
