import SwiftUI

struct SplashScreen: View {
  @State private var isAnimating = false
  @State private var pulseAnimation = false
  @State private var dotsAnimation = 0
  @Environment(\.colorScheme) private var colorScheme

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

        // Owl mascot with glow effect
        ZStack {
          // Outer glow ring
          Circle()
            .fill(
              RadialGradient(
                colors: [
                  AppTheme.Colors.tint(for: colorScheme).opacity(0.3),
                  AppTheme.Colors.tint(for: colorScheme).opacity(0.0)
                ],
                center: .center,
                startRadius: 60,
                endRadius: 120
              )
            )
            .frame(width: 240, height: 240)
            .scaleEffect(pulseAnimation ? 1.1 : 0.9)
            .opacity(pulseAnimation ? 0.6 : 0.3)

          // Inner glow
          Circle()
            .fill(
              RadialGradient(
                colors: [
                  AppTheme.Colors.secondaryTint(for: colorScheme).opacity(0.4),
                  AppTheme.Colors.secondaryTint(for: colorScheme).opacity(0.0)
                ],
                center: .center,
                startRadius: 40,
                endRadius: 100
              )
            )
            .frame(width: 200, height: 200)
            .scaleEffect(pulseAnimation ? 0.95 : 1.05)
            .opacity(pulseAnimation ? 0.4 : 0.2)

          // Owl image
          Image("FoxMascotTransparent")
            .resizable()
            .scaledToFit()
            .frame(width: 160, height: 160)
            .scaleEffect(isAnimating ? 1.0 : 0.8)
            .opacity(isAnimating ? 1.0 : 0.0)
        }
        .padding(.bottom, 40)

        // App name
        Text("Norviqa")
          .font(.system(size: 48, weight: .bold, design: .rounded))
          .foregroundStyle(
            LinearGradient(
              colors: [
                AppTheme.Colors.tint(for: colorScheme),
                AppTheme.Colors.secondaryTint(for: colorScheme)
              ],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .opacity(isAnimating ? 1.0 : 0.0)
          .offset(y: isAnimating ? 0 : 20)

        // Tagline
        Text("Your wealth, wisely managed")
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(.secondary)
          .opacity(isAnimating ? 0.8 : 0.0)
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
                  .easeInOut(duration: 0.6)
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
      // Stagger animations for smooth entrance
      withAnimation(.easeOut(duration: 0.8)) {
        isAnimating = true
      }

      withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
        pulseAnimation = true
      }

      // Animate dots
      Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
        dotsAnimation = (dotsAnimation + 1) % 3
      }
    }
  }
}

#Preview {
  SplashScreen()
    .preferredColorScheme(.dark)
}
