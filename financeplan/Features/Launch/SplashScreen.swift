import SwiftUI

/// Precision splash: the lockup and the tagline on the launch colour, so the
/// hand-off from LaunchScreen.storyboard is seamless. No glow, no gradient
/// (docs/precision-identity.md); motion is a single fade, and the loading mark
/// is static under Reduce Motion.
struct SplashScreen: View {
  @State private var isShown = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let logoWidth: CGFloat = 236

  var body: some View {
    ZStack {
      Color("LaunchBackground")
        .ignoresSafeArea()

      VStack(spacing: 0) {
        Spacer()

        NorviqFullLogo(width: logoWidth)

        // Live text under the lockup, never baked into the artwork.
        Text("Discipline creates freedom.")
          .font(.footnote.weight(.medium))
          .tracking(1.2)
          .textCase(.uppercase)
          .foregroundStyle(.secondary)
          .padding(.top, 16)

        Spacer()

        VStack(spacing: 12) {
          LoadingEmblem(size: 22)
          Text("Loading your workspace")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.bottom, 60)
      }
      .opacity(isShown ? 1 : 0)
    }
    .onAppear {
      withAnimation(reduceMotion ? AppMotion.reduced : .easeOut(duration: 0.32)) {
        isShown = true
      }
    }
  }
}

#Preview {
  SplashScreen()
    .preferredColorScheme(.dark)
}
