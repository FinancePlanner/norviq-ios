import SwiftUI

/// Full-width selectable row used by single-select (goal) and multi-select (pain points) screens.
/// Visual: emoji glyph + title + selection indicator (check or radio).
struct OnboardingSelectableRow: View {
  let emoji: String
  let title: String
  let isSelected: Bool
  let isMultiSelect: Bool
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Text(emoji)
          .font(.title2)
          .frame(width: 32, height: 32)

        Text(title)
          .typography(.label, weight: .medium)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)

        selectionIndicator
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .appGlassEffect(.rect(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            isSelected ? AppTheme.Colors.tint(for: colorScheme) : .clear,
            lineWidth: 2
          )
      }
    }
    .buttonStyle(PressEffectStyle())
  }

  @ViewBuilder
  private var selectionIndicator: some View {
    if isMultiSelect {
      Image(systemName: isSelected ? "checkmark.square.fill" : "square")
        .font(.title3)
        .foregroundStyle(isSelected ? AppTheme.Colors.tint(for: colorScheme) : .secondary.opacity(0.5))
    } else {
      Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
        .font(.title3)
        .foregroundStyle(isSelected ? AppTheme.Colors.tint(for: colorScheme) : .secondary.opacity(0.5))
    }
  }
}
