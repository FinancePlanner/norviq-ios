import SwiftUI

/// Selectable subscription plan card used across all paywall screens.
/// Provides glass styling, spring selection animation, and haptic feedback.
struct PaywallPlanCard: View {
  let title: String
  let subtitle: String
  let price: String
  let priceUnit: String
  var badge: String?
  let isSelected: Bool
  let onSelect: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 14) {
        selectionIndicator

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Text(title)
              .font(.body.weight(.semibold))
              .fixedSize(horizontal: false, vertical: true)

            if let badge {
              Text(badge)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(AppTheme.Colors.success, in: Capsule())
            }
          }

          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        // The price and its unit are the billing disclosure, so they get layout
        // priority and are never allowed to compress. At AX5 the title/subtitle
        // column grows and SwiftUI truncates whichever side loses the
        // negotiation — on a paywall that must not be the price. Build-31 was
        // rejected for exactly this class of Dynamic Type failure.
        VStack(alignment: .trailing, spacing: 2) {
          HStack(alignment: .lastTextBaseline, spacing: 1) {
            Text(price)
              .font(.body.weight(.semibold))
              .foregroundStyle(.primary)
            Text(priceUnit)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .fixedSize(horizontal: true, vertical: false)
        }
        .layoutPriority(1)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(
        isSelected
          ? AppTheme.Colors.tintSoft(for: colorScheme)
          : Color(.secondarySystemBackground),
        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(PressableStyle())
    .appAnimation(AppMotion.state, value: isSelected)
    .sensoryFeedback(.selection, trigger: isSelected)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title) plan, \(subtitle), \(price)\(priceUnit)")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var selectionIndicator: some View {
    ZStack {
      Circle()
        .fill(isSelected ? AppTheme.Colors.tint(for: colorScheme) : Color(.tertiarySystemFill))
        .frame(width: 22, height: 22)

      if isSelected {
        Image(systemName: "checkmark")
          .font(.caption2.weight(.bold))
          .foregroundStyle(Color(.systemBackground))
          .transition(.scale.combined(with: .opacity))
      }
    }
    .appAnimation(AppMotion.state, value: isSelected)
    .accessibilityHidden(true)
  }
}
