import SwiftUI

struct SignInView: View {
  @ObservedObject var viewModel: LoginViewModel
  @State private var isPasswordVisible = false
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        header
        formCard
        signUpPrompt
        Spacer(minLength: 40)
        AuthFooter()
      }
    }
    .scrollDismissesKeyboard(.interactively)
  }

  @ViewBuilder
  private var header: some View {
    VStack(spacing: 16) {
      VigilPageHeader(
        watch: .auth("Secure access"),
        title: "Welcome back",
        subtitle: "Review your portfolio, budgets, and financial insights securely."
      )
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 24)
    }
    .padding(.horizontal, 24)
  }

  @ViewBuilder
  private var formCard: some View {
    Group {
      GlassCard(cornerRadius: AppTheme.Radius.hero, padding: 0) {
        formFields
          .padding(24)
      }
    }
    .padding(.horizontal, 24)
  }

  private var formFields: some View {
    VStack(spacing: 24) {
      VaultTextField(
        label: "Email Address",
        placeholder: "name@domain.com",
        text: $viewModel.username,
        icon: "envelope.fill",
        keyboardType: .emailAddress,
        textContentType: .emailAddress,
        submitLabel: .next
      )

      VStack(alignment: .trailing, spacing: 8) {
        VaultTextField(
          label: "Password",
          placeholder: "••••••••",
          text: $viewModel.password,
          icon: "lock.fill",
          isSecure: !isPasswordVisible,
          rightAccessory:
            Button(
              isPasswordVisible ? "Hide password" : "Show password",
              systemImage: isPasswordVisible ? "eye.slash.fill" : "eye.fill",
              action: { isPasswordVisible.toggle() }
            )
            .labelStyle(.iconOnly)
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .contentShape(.rect)
            .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password"),
          textContentType: .password,
          submitLabel: .done,
          onSubmit: { Task { await viewModel.submit() } }
        )

        Button("Forgot Password?") {
          viewModel.isForgotPasswordPresented = true
        }
        .font(.caption.weight(.bold))
        .tracking(1.0)
        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
      }

      Button(action: { Task { await viewModel.submit() } }) {
        HStack {
          if viewModel.isSubmitting {
            ProgressView()
              .tint(.white)
              .padding(.trailing, 8)
          }
          Text("Sign in")
            .font(.headline.weight(.semibold))
          Image(systemName: "arrow.right")
            .font(.subheadline.weight(.bold))
        }
      }
      .buttonStyle(.borderedProminent)
      .tint(AppTheme.Colors.tint(for: colorScheme))
      .disabled(viewModel.isSubmitting)
      .padding(.top, 8)

      SocialAuthSection(viewModel: viewModel, intentLabel: "sign in")
        .padding(.top, 6)
    }
  }

  private var signUpPrompt: some View {
    Button(action: { viewModel.showSignup() }) {
      HStack(spacing: 8) {
        Text("No account? Sign up instead")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)

        Image(systemName: "chevron.right")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
      }
    }
    .padding(.top, 8)
  }
}
