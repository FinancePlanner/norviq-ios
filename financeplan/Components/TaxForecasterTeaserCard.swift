import SwiftUI

/// Dashboard teaser into the tax dashboard. Tax is not a spending concern, so
/// this sits on the dashboard rather than in the expenses planner.
struct TaxForecasterTeaserCard: View {
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    NavigationLink {
      TaxDashboardScreen()
    } label: {
      GlassCard(cornerRadius: AppTheme.Radius.card) {
        HStack(spacing: 12) {
          Image(systemName: "percent")
            .font(.title3)
            .foregroundStyle(.tint)
            .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 2) {
            Text("Tax liability forecaster")
              .typography(.small, weight: .semibold)
            Text("Jurisdiction-aware estimates from your tax profile.")
              .typography(.nano)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
        }
      }
    }
    .buttonStyle(.plain)
    .tint(AppTheme.Colors.tint(for: scheme))
  }
}
