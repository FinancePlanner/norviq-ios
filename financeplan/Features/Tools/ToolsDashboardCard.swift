import SwiftUI

/// Home's way into the Tools hub. Needs `toolsDestinations()` on its stack.
struct ToolsDashboardCard: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    NavigationLink(value: ToolsRoute.hub) {
      HStack(alignment: .top, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Label("Tools", systemImage: "wrench.and.screwdriver")
            .font(.headline)
          Text("Calculators and planners for your money, in one place.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        AppTheme.Colors.cardBackground(for: colorScheme),
        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
      )
    }
    .buttonStyle(.plain)
  }
}
