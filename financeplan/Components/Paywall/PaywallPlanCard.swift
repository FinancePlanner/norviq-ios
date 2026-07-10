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
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 2) {
          HStack(alignment: .lastTextBaseline, spacing: 1) {
            Text(price)
              .font(.body.weight(.semibold))
              .foregroundStyle(.primary)
            Text(priceUnit)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 18)
      .appGlassEffect(
        .rect(cornerRadius: 20),
        tint: isSelected
          ? AppTheme.Colors.tintSoft(for: colorScheme).opacity(colorScheme == .dark ? 0.55 : 0.45)
          : nil
      )
      .overlay {
        if isSelected {
          RoundedRectangle(cornerRadius: 20)
            .stroke(AppTheme.Colors.tint(for: colorScheme), lineWidth: 2)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(PressableStyle())
    .scaleEffect(isSelected ? 1.02 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    .sensoryFeedback(.selection, trigger: isSelected)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title) plan, \(subtitle), \(price)\(priceUnit)")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var selectionIndicator: some View {
    ZStack {
      Circle()
        .strokeBorder(
          isSelected
            ? AppTheme.Colors.tint(for: colorScheme)
            : AppTheme.Colors.separator(for: colorScheme),
          lineWidth: isSelected ? 0 : 1.5
        )
        .background(
          Circle().fill(isSelected ? AppTheme.Colors.tint(for: colorScheme) : Color.clear)
        )
        .frame(width: 24, height: 24)

      if isSelected {
        Image(systemName: "checkmark")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.white)
          .transition(.scale.combined(with: .opacity))
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    .accessibilityHidden(true)
  }
}
