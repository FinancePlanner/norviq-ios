import SwiftUI

struct PrivacyWelcomeScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  var onSignIn: () -> Void
  var onSignUp: () -> Void

  var body: some View {
    ZStack {
      VStack(spacing: 24) {
        NorviqaLogo(size: 78)
          .padding(.top, 60)

        VStack(spacing: 8) {
          Text("Your data is yours")
            .font(.largeTitle.weight(.bold))
            .multilineTextAlignment(.center)

          Text("We built Norviqa around one principle: your financial data belongs to you.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }

        Spacer()

        GlassCard(cornerRadius: 24) {
          VStack(alignment: .leading, spacing: 16) {
            bulletPoint("We never sell or share your financial data")
            bulletPoint("Your data is encrypted at rest")
            bulletPoint("Export or delete everything, anytime")
            bulletPoint("We don't mine your positions or expenses")
            bulletPoint("We only store what the app needs to work")
          }
          .padding(.vertical, 8)
        }
        .padding(.horizontal, 24)

        Spacer()

        VStack(spacing: 12) {
          Button(action: onSignIn) {
            Text("Sign In")
              .font(.headline.weight(.semibold))
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.glassProminent)

          Button(action: onSignUp) {
            Text("Create Account")
              .font(.headline.weight(.semibold))
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.glass)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)

        AuthFooter()
      }
    }
    .background {
      MeshGradientBackground()
    }
  }

  private func bulletPoint(_ text: String) -> some View {
    Label {
      Text(text)
        .font(.subheadline.weight(.medium))
    } icon: {
      Image(systemName: "checkmark.seal.fill")
        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
    }
  }
}
