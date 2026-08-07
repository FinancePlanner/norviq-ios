import SwiftUI

struct SplashScreen: View {
  @State private var isAnimating = false
  @State private var pulseAnimation = false
  @State private var dotsAnimation = 0
  @State private var dotsTimer: Timer?
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      LinearGradient(
        colors: AppTheme.splashGradient(for: colorScheme),
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      if BrandTheme.current == .vigil {
        MeshGradientBackground(animatesOnAppear: true)
          .opacity(colorScheme == .dark ? 0.55 : 0.35)
          .ignoresSafeArea()
      }

      VStack(spacing: 0) {
        Spacer()

        SplashBrandStage(
          isAnimating: isAnimating,
          pulseAnimation: pulseAnimation
        )
        .padding(.bottom, 40)

        // Tagline
        Text("The vigil begins.")
          .typography(.hero)
          .foregroundStyle(AppTheme.Colors.foreground(for: colorScheme))
          .opacity(isAnimating ? 0.9 : 0.0)
          .offset(y: isAnimating ? 0 : 20)
          .padding(.top, 8)

        Spacer()

        // Loading indicator
        VStack(spacing: 16) {
          // Animated dots
          HStack(spacing: 8) {
            ForEach(0..<3) { index in
              Circle()
                .fill(AppTheme.Colors.tint(for: colorScheme))
                .frame(width: 8, height: 8)
                .scaleEffect(dotsAnimation == index ? 1.3 : 1.0)
                .opacity(dotsAnimation == index ? 1.0 : 0.5)
                .animation(
                  reduceMotion
                    ? nil
                    : .easeInOut(duration: 0.6)
                      .repeatForever(autoreverses: false)
                      .delay(Double(index) * 0.2),
                  value: dotsAnimation
                )
            }
          }
          .opacity(isAnimating ? 1.0 : 0.0)

          Text("Loading your workspace")
            .font(.caption)
            .foregroundStyle(.secondary)
            .opacity(isAnimating ? 0.6 : 0.0)
        }
        .padding(.bottom, 60)
      }
    }
    .onAppear {
      withAnimation(reduceMotion ? AppMotion.reduced : .easeOut(duration: 0.8)) {
        isAnimating = true
      }

      guard !reduceMotion else { return }

      withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
        pulseAnimation = true
      }

      dotsTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
        Task { @MainActor in
          dotsAnimation = (dotsAnimation + 1) % 3
        }
      }
    }
    .onDisappear {
      dotsTimer?.invalidate()
      dotsTimer = nil
    }
  }
}

private struct SplashBrandStage: View {
  var isAnimating: Bool
  var pulseAnimation: Bool

  @Environment(\.colorScheme) private var colorScheme

  private let stageSize: CGFloat = 280
  private let ringSize: CGFloat = 200
  private let logoWidth: CGFloat = 236

  var body: some View {
    ZStack {
      // Plain accent ring — no blurred glow.
      Circle()
        .stroke(AppTheme.Colors.tint(for: colorScheme).opacity(0.25), lineWidth: 1.5)
        .frame(width: ringSize, height: ringSize)
        .scaleEffect(pulseAnimation ? 1.03 : 0.97)
        .opacity(pulseAnimation ? 0.9 : 0.6)

      Image("CerberusMarkFull")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: logoWidth)
        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
        .accessibilityLabel("Norviq")
        .scaleEffect(isAnimating ? 1.0 : 0.8)
        .opacity(isAnimating ? 1.0 : 0.0)
    }
    .frame(width: stageSize, height: stageSize)
    .clipped()
    .compositingGroup()
  }
}

#Preview {
  SplashScreen()
    .preferredColorScheme(.dark)
}
