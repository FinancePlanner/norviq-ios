import SwiftUI

struct SignInView: View {
  @ObservedObject var viewModel: LoginViewModel
  @State private var isPasswordVisible = false
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        // Header
        VStack(spacing: 16) {
          NorviqaLogo(size: 78)
            .padding(.top, 24)

          VStack(spacing: 8) {
            Text("Welcome back")
              .font(.largeTitle.weight(.bold))
              .foregroundStyle(.primary)

            Text("Securely access your private financial editorial and curated portfolio.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .lineSpacing(4)
          }
          .padding(.top, 8)
        }

        // Form Card
        GlassCard(cornerRadius: 24) {
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
            .buttonStyle(.glassProminent)
            .tint(AppTheme.Colors.tint(for: colorScheme))
            .disabled(viewModel.isSubmitting)
            .padding(.top, 8)

            SocialAuthSection(viewModel: viewModel, intentLabel: "sign in")
              .padding(.top, 6)
          }
          .padding(24)
        }
        .padding(.horizontal, 24)

        // Switch to Sign Up
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

        Spacer(minLength: 40)

        AuthFooter()
      }
    }
    .scrollDismissesKeyboard(.interactively)
  }
}
