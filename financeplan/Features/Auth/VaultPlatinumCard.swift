import SwiftUI

struct VaultPlatinumCard: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack(alignment: .leading) {
      RoundedRectangle(cornerRadius: 24)
        .fill(
          LinearGradient(
            colors: [
              AppTheme.Colors.elevatedCardBackground(for: colorScheme),
              AppTheme.Colors.cardBackground(for: colorScheme)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      VStack(alignment: .leading, spacing: 8) {
        Text("NORDIQ")
          .font(.caption.weight(.bold))
          .tracking(1.5)
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))

        Text("Your data, forever yours")
          .font(.title3.weight(.bold))
          .foregroundStyle(.primary)
          .padding(.top, 4)

        Text("End-to-end encryption and zero-knowledge architecture keep your financial information private.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineSpacing(4)
          .padding(.top, 8)
      }
      .padding(24)
    }
    .frame(height: 180)
  }
}
