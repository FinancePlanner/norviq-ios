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
      // Background gradient
      LinearGradient(
        colors: AppTheme.splashGradient(for: colorScheme),
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

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
  private let outerGlowSize: CGFloat = 218
  private let innerGlowSize: CGFloat = 180
  private let logoWidth: CGFloat = 236

  var body: some View {
    ZStack {
      // Outer gold ring glow
      Circle()
        .fill(
          RadialGradient(
            colors: [
              AppTheme.Colors.splashRing,
              AppTheme.Colors.splashRing.opacity(0.0)
            ],
            center: .center,
            startRadius: 54,
            endRadius: 116
          )
        )
        .frame(width: outerGlowSize, height: outerGlowSize)
        .scaleEffect(pulseAnimation ? 1.1 : 0.9)
        .opacity(pulseAnimation ? 0.6 : 0.3)

      // Inner ember core glow
      Circle()
        .fill(
          RadialGradient(
            colors: [
              AppTheme.Colors.splashCore.opacity(0.4),
              AppTheme.Colors.splashCore.opacity(0.0)
            ],
            center: .center,
            startRadius: 36,
            endRadius: 96
          )
        )
        .frame(width: innerGlowSize, height: innerGlowSize)
        .scaleEffect(pulseAnimation ? 0.95 : 1.05)
        .opacity(pulseAnimation ? 0.4 : 0.2)

      Image("CerberusMarkFull")
        .resizable()
        .scaledToFit()
        .frame(width: logoWidth)
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
