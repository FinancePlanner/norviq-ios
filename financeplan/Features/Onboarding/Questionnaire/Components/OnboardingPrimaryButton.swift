import SwiftUI

/// Standard primary CTA used at the bottom of every questionnaire screen.
/// Matches the existing `Capsule()` + tint-fill + glow pattern used in `OnboardingStepScaffold`.
struct OnboardingPrimaryButton: View {
  let title: String
  var isEnabled: Bool = true
  var isLoading: Bool = false
  var showsArrow: Bool = false
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if isLoading {
          ProgressView().tint(.white)
        }

        Text(title)
          .font(.headline.weight(.bold))

        if showsArrow && !isLoading {
          Image(systemName: "arrow.right")
            .font(.subheadline.weight(.bold))
        }
      }
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(
        Capsule()
          .fill(AppTheme.Colors.tint(for: colorScheme))
      )
      .shadow(
        color: AppTheme.Colors.tint(for: colorScheme).opacity(0.25),
        radius: 8, x: 0, y: 4
      )
    }
    .buttonStyle(PressEffectStyle())
    .disabled(!isEnabled || isLoading)
    .opacity(isEnabled ? 1 : 0.45)
  }
}

/// Bottom action bar matching the look of `OnboardingStepScaffold`'s footer:
/// thin divider + glass-effect strip + primary button.
struct OnboardingActionBar<Trailing: View>: View {
  let primaryTitle: String
  var isEnabled: Bool = true
  var isLoading: Bool = false
  var showsArrow: Bool = false
  let onPrimary: () -> Void
  @ViewBuilder let leading: () -> Trailing

  var body: some View {
    VStack(spacing: 0) {
      Divider().opacity(0.3)

      HStack(spacing: 12) {
        leading()
        OnboardingPrimaryButton(
          title: primaryTitle,
          isEnabled: isEnabled,
          isLoading: isLoading,
          showsArrow: showsArrow,
          action: onPrimary
        )
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)
      .appGlassEffect(.rect(cornerRadius: 0))
      .ignoresSafeArea(edges: .bottom)
    }
  }
}

extension OnboardingActionBar where Trailing == EmptyView {
  init(
    primaryTitle: String,
    isEnabled: Bool = true,
    isLoading: Bool = false,
    showsArrow: Bool = false,
    onPrimary: @escaping () -> Void
  ) {
    self.primaryTitle = primaryTitle
    self.isEnabled = isEnabled
    self.isLoading = isLoading
    self.showsArrow = showsArrow
    self.onPrimary = onPrimary
    self.leading = { EmptyView() }
  }
}
