import SwiftUI

/// Badge type displayed on a paywall feature row.
enum PaywallFeatureBadge {
  case pro
  case free
}

/// A single feature bullet row used in paywall feature lists.
/// Groups all content for VoiceOver accessibility.
struct PaywallFeatureRow: View {
  let icon: String
  let title: String
  var badge: PaywallFeatureBadge? = .pro

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 16) {
      // Icon container — 44×44 minimum tap target
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(AppTheme.Colors.secondaryTint(for: colorScheme).opacity(
            colorScheme == .dark ? 0.18 : 0.12
          ))
          .frame(width: 44, height: 44)

        Image(systemName: icon)
          .font(.body.weight(.semibold))
          .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme))
      }
      .accessibilityHidden(true)

      Text(title)
        .font(.body.weight(.semibold))
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)

      if let badge {
        badgeLabel(for: badge)
      }
    }
    .padding(16)
    .background(AppTheme.Colors.cardBackground(for: colorScheme))
    .clipShape(.rect(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.0), lineWidth: 1)
    )
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private func badgeLabel(for badge: PaywallFeatureBadge) -> some View {
    switch badge {
    case .pro:
      Text("PRO")
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
          AppTheme.Colors.premiumGradient(for: colorScheme),
          in: Capsule()
        )
    case .free:
      Text("FREE")
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
          AppTheme.Colors.tertiaryFill(for: colorScheme),
          in: Capsule()
        )
    }
  }
}
