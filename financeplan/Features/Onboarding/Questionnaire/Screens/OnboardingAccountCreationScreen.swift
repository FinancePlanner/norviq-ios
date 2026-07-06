import Factory
import SwiftUI

/// Screen 12 — hard-gated account creation. No skip path.
///
/// Owns its own `LoginViewModel` so OAuth (Apple/Google/X) can be invoked directly via
/// `signInWithOAuth`. Email sign-up routes through the existing `LoginScreen` presented
/// as a full-screen cover so we don't duplicate sign-up UI.
struct OnboardingAccountCreationScreen: View {
  let demoPicks: [String]
  /// Fires when authentication succeeds (OAuth or email signup completes).
  let onAuthenticated: () -> Void
  /// User tapped "Log in" — caller decides whether to dismiss flow or route differently.
  let onLogInRequested: () -> Void

  @StateObject private var viewModel: LoginViewModel
  @State private var emailFlowPresented = false
  @Environment(\.colorScheme) private var colorScheme

  @MainActor
  init(
    demoPicks: [String],
    onAuthenticated: @escaping () -> Void,
    onLogInRequested: @escaping () -> Void
  ) {
    self.demoPicks = demoPicks
    self.onAuthenticated = onAuthenticated
    self.onLogInRequested = onLogInRequested
    _viewModel = StateObject(
      wrappedValue: LoginViewModel(
        authService: Container.shared.authService(),
        sessionStore: Container.shared.authSessionStore(),
        onAuthenticated: onAuthenticated
      )
    )
    viewModel.showSignup()
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        pickStrip
        headlineBlock
        benefitsCard
        signUpButtons
        Spacer(minLength: 12)
        legalAndLogIn
      }
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 32)
    }
    .overlay(alignment: .top) {
      if let error = viewModel.error {
        FormErrorBanner(message: error)
          .padding(.horizontal, 16)
          .padding(.top, 8)
          .transition(.move(edge: .top).combined(with: .opacity))
      } else if let info = viewModel.infoMessage {
        ToastBanner(message: info, style: .success)
          .padding(.horizontal, 16)
          .padding(.top, 8)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .fullScreenCover(isPresented: $emailFlowPresented) {
      EmailSignUpCover(
        onAuthenticated: {
          emailFlowPresented = false
          onAuthenticated()
        },
        onClose: {
          emailFlowPresented = false
        }
      )
    }
  }

  // MARK: - Picks strip

  private var pickStrip: some View {
    let chosen = demoPicks.compactMap { symbol in
      OnboardingDemoTickers.all.first { $0.symbol == symbol }
    }
    return VStack(spacing: 8) {
      HStack(spacing: 8) {
        ForEach(chosen) { ticker in
          PickChip(ticker: ticker)
        }
      }
      Text("Saving these to your account →")
        .typography(.nano, weight: .semibold)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 8)
  }

  // MARK: - Headline

  private var headlineBlock: some View {
    VStack(spacing: 10) {
      Text("Save your starter plan.")
        .typography(.title, weight: .bold)
        .multilineTextAlignment(.center)

      Text("Create a free account to keep what you just made.")
        .typography(.label)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
    }
  }

  // MARK: - Benefits

  private var benefitsCard: some View {
    GlassCard(cornerRadius: 20) {
      VStack(alignment: .leading, spacing: 12) {
        Text("Your free account gets you")
          .typography(.caption, weight: .semibold)
          .foregroundStyle(.secondary)

        benefitRow(icon: "icloud.fill", text: "Sync across all your devices")
        benefitRow(icon: "chart.line.uptrend.xyaxis", text: "Live prices and daily updates")
        benefitRow(icon: "lock.shield.fill", text: "Bank-level encryption — no broker linking required")
      }
      .padding(.vertical, 4)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func benefitRow(icon: String, text: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.body.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
        .frame(width: 24)
      Text(text)
        .typography(.small, weight: .medium)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  // MARK: - Sign-up buttons

  private var signUpButtons: some View {
    VStack(spacing: 12) {
      ForEach(SocialAuthProvider.allCases) { provider in
        SocialAuthButton(provider: provider) {
          if let oauthProvider = provider.oauthProvider {
            Task { await viewModel.signInWithOAuth(oauthProvider) }
          }
        }
      }

      Button {
        emailFlowPresented = true
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "envelope.fill")
            .font(.system(size: 16, weight: .semibold))
          Text("Continue with email")
            .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.elevatedCardBackground(for: colorScheme))
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
          RoundedRectangle(cornerRadius: 12)
            .stroke(AppTheme.Colors.separator(for: colorScheme), lineWidth: 1)
        }
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Legal + log in

  private var legalAndLogIn: some View {
    VStack(spacing: 14) {
      Button(action: onLogInRequested) {
        Text("Already have an account? **Log in**")
          .typography(.small)
          .foregroundStyle(.secondary)
      }

      Text("By continuing, you agree to our **Terms** and **Privacy Policy**.")
        .typography(.nano)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
    }
  }
}

// MARK: - Pick chip

private struct PickChip: View {
  let ticker: OnboardingDemoTicker
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 6) {
      Text(ticker.symbol)
        .typography(.nano, weight: .bold)
      SparklinePath(values: ticker.sparkline)
        .stroke(
          AppTheme.Colors.tint(for: colorScheme),
          style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
        )
        .frame(width: 30, height: 14)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(Capsule().fill(AppTheme.Colors.tintSoft(for: colorScheme)))
  }
}

// MARK: - Email sign-up cover

/// Wraps the existing `LoginScreen` (in sign-up mode) as a full-screen presentation
/// so we don't duplicate the email sign-up UI in the onboarding flow.
private struct EmailSignUpCover: View {
  let onAuthenticated: () -> Void
  let onClose: () -> Void

  var body: some View {
    ZStack(alignment: .topLeading) {
      LoginScreen(
        onAuthenticated: onAuthenticated,
        startWithSignup: true
      )

      Button(action: onClose) {
        Image(systemName: "xmark")
          .font(.body.weight(.bold))
          .foregroundStyle(.primary)
          .padding(10)
          .background(Circle().fill(.ultraThinMaterial))
      }
      .padding(.leading, 16)
      .padding(.top, 12)
      .accessibilityLabel("Close email sign-up")
    }
  }
}
