import SwiftUI

/// 2-column grid tile for multi-select preference screens (holdings, spending leaks).
/// Larger emoji, title below, full-tile tap target.
struct OnboardingSelectableTile: View {
  let emoji: String
  let title: String
  let isSelected: Bool
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: action) {
      VStack(spacing: 10) {
        Text(emoji)
          .font(.system(size: 36))

        Text(title)
          .typography(.small, weight: .semibold)
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 12)
      .padding(.vertical, 18)
      .appGlassEffect(.rect(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .stroke(
            isSelected ? AppTheme.Colors.tint(for: colorScheme) : .clear,
            lineWidth: 2
          )
      }
      .overlay(alignment: .topTrailing) {
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.title3)
            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
            .background(Circle().fill(AppTheme.Colors.pageBackground(for: colorScheme)).frame(width: 22, height: 22))
            .padding(8)
        }
      }
    }
    .buttonStyle(PressableStyle())
  }
}
