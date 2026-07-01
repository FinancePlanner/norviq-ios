import SwiftUI

/// Branded hero section for paywall screens with logo, headline, subtitle,
/// and an animated radial gradient backdrop.
struct PaywallHeroSection: View {
  let headline: String
  let subtitle: String
  var showsLogo: Bool = true

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false

  var body: some View {
    ZStack {
      // Animated radial glow behind the content
      RadialGradient(
        colors: AppTheme.Colors.premiumGradientColors(for: colorScheme).map {
          $0.opacity(colorScheme == .dark ? 0.25 : 0.15)
        } + [.clear],
        center: .center,
        startRadius: 0,
        endRadius: 220
      )
      .frame(height: 280)
      .blur(radius: 30)
      .scaleEffect(appeared ? 1.05 : 0.9)

      VStack(spacing: 16) {
        if showsLogo {
          NorviqFullLogo(width: 210)
            .scaleEffect(appeared ? 1.0 : 0.6)
            .opacity(appeared ? 1 : 0)
        }

        Text(headline)
          .font(.largeTitle.bold())
          .multilineTextAlignment(.center)
          .foregroundStyle(.primary)
          .opacity(appeared ? 1 : 0)
          .offset(y: appeared ? 0 : 12)

        Text(subtitle)
          .font(.body)
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 16)
          .opacity(appeared ? 1 : 0)
          .offset(y: appeared ? 0 : 16)
      }
    }
    .frame(maxWidth: .infinity)
    .onAppear {
      let animation: Animation = reduceMotion
        ? .easeOut(duration: 0.2)
        : .spring(response: 0.7, dampingFraction: 0.75).delay(0.1)
      withAnimation(animation) {
        appeared = true
      }
    }
  }
}
