import SwiftUI

struct OnboardingWelcomeScreen: View {
  let onGetStarted: () -> Void
  let onLogIn: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 32)

      Image("CerberusMarkFull")
        .resizable()
        .scaledToFit()
        .frame(maxHeight: 220)
        .padding(.horizontal, 40)
        .padding(.bottom, 32)
        .accessibilityHidden(true)

      VStack(spacing: 12) {
        Text("Three heads. Every angle of your money.")
          .typography(.hero, weight: .bold)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)

        Text("Norviq keeps the vigil — wealth, spending, and the signals between. Nothing slips past.")
          .typography(.label)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)
      }

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
  }

  private var legalFootnote: some View {
    Text("By continuing, you agree to our **Terms** and **Privacy Policy**.")
      .typography(.nano)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
  }
}
