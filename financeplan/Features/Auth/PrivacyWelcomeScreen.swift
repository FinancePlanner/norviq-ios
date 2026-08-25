import SwiftUI

struct PrivacyWelcomeScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  var onSignIn: () -> Void
  var onSignUp: () -> Void

  var body: some View {
    ZStack {
      VStack(spacing: 24) {
        VigilPageHeader(
          watch: .auth("The gate holds"),
          title: "Your data is yours",
          subtitle: "We built Norviq around one principle: your financial data belongs to you."
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 60)

        Spacer()

        privacyCard

        Spacer()

        VStack(spacing: 12) {
          Button(action: onSignIn) {
            Text("Sign In")
              .font(.headline.weight(.semibold))
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)

          Button(action: onSignUp) {
            Text("Create Account")
              .font(.headline.weight(.semibold))
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
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

  @ViewBuilder
  private var privacyCard: some View {
    Group {
      GlassCard(cornerRadius: 24, padding: 0) {
        privacyBullets
          .padding(.vertical, 8)
          .padding(.horizontal, 8)
      }
    }
    .padding(.horizontal, 24)
  }

  private var privacyBullets: some View {
    VStack(alignment: .leading, spacing: 16) {
      bulletPoint("We never sell or share your financial data")
      bulletPoint("Your data is encrypted at rest")
      bulletPoint("Export or delete everything, anytime")
      bulletPoint("We don't mine your positions or expenses")
      bulletPoint("We only store what the app needs to work")
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
