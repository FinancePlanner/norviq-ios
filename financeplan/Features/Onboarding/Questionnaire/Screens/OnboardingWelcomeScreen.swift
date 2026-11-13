import SwiftUI

struct OnboardingWelcomeScreen: View {
  let onGetStarted: () -> Void
  let onLogIn: () -> Void

  #if DEBUG || BETA
    /// A finger on the screen, for the 3D Vig to turn toward (BRD-001).
    @State private var pointer: CGPoint?
  #endif

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 32)

      VStack(spacing: 24) {
        Text(VigilWatch.wealth.eyebrow)
          .vigilOverline()
          .foregroundStyle(.secondary)

        vig

        NorviqFullLogo(width: 236)
          .accessibilityHidden(true)

        VStack(spacing: 12) {
          Text("Clarity in Every Position.")
            .typography(.hero, weight: .bold)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

          Text("Professional stock planning and portfolio intelligence for disciplined investors.")
            .typography(.label)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }
      }
      .onboardingStepCard(cornerRadius: 28)
      .padding(.horizontal, 20)

      Spacer(minLength: 24)

      VStack(spacing: 14) {
        OnboardingPrimaryButton(title: "Get started", action: onGetStarted)
          .padding(.horizontal, 24)

        Button(action: onLogIn) {
          Text("Already have an account? Log in")
            .typography(.small, weight: .semibold)
            .foregroundStyle(.secondary)
        }

        legalFootnote
          .padding(.horizontal, 32)
          .padding(.top, 4)
      }
      .padding(.bottom, 32)
    }
    .vigilScreenBackground()
    #if DEBUG || BETA
      .vigFollows($pointer)
    #endif
  }

  /// Beta builds try the 3D Vig (BRD-001); it shows this same still until its first frame and
  /// whenever it cannot draw. Release has only the still.
  private var vig: some View {
    #if DEBUG || BETA
      Vig3DView(pointer: pointer, height: 200)
    #else
      Image("VigFull")
        .resizable()
        .scaledToFit()
        .frame(height: 200)
        .accessibilityHidden(true)
    #endif
  }

  private var legalFootnote: some View {
    Text("By continuing, you agree to our **Terms** and **Privacy Policy**.")
      .typography(.nano)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
  }
}
