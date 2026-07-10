import SwiftUI

struct VaultForgotPasswordView: View {
  @ObservedObject var viewModel: LoginViewModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  @State private var email = ""
  @State private var isSubmitting = false
  @State private var message: String?
  @State private var errorMessage: String?

  var body: some View {
    ZStack {
      MeshGradientBackground()

      VStack(spacing: 0) {
        // Top Bar
        HStack {
          Button("Back", systemImage: "arrow.left") {
            dismiss()
          }
          .labelStyle(.iconOnly)
          .font(.system(size: 20, weight: .medium))
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          .frame(width: 44, height: 44)
          .contentShape(.rect)
          .accessibilityLabel("Back to sign in")

          Spacer()

          Text("Norviq")
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)

          Spacer()

          // Invisible spacer for centering
          Color.clear
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 20)

        ScrollView {
          VStack(spacing: 32) {
            NorviqFullLogo(width: 220)
              .padding(.top, 40)

            VStack(spacing: 12) {
              Text("Reset Password")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

              Text("Enter the email address associated with your account and we'll send a code to reset your password.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            }

            VStack(spacing: 24) {
              TextField("Email Address", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .foregroundStyle(.primary)
                .background(AppTheme.Colors.cardBackground(for: colorScheme))
                .clipShape(.rect(cornerRadius: 12))

              if let message {
                HStack(spacing: 8) {
                  Image(systemName: "checkmark.circle.fill")
                  Text(message)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.Colors.success)
                .frame(maxWidth: .infinity, alignment: .leading)
              }

              if let errorMessage {
                FormErrorBanner(message: errorMessage)
              }

              Button(action: { Task { await submit() } }) {
                HStack {
                  if isSubmitting {
                    ProgressView()
                      .tint(.white)
                      .padding(.trailing, 8)
                  }
                  Text(isSubmitting ? "Sending..." : "Send Reset Link")
                    .font(.headline.weight(.semibold))
                  if !isSubmitting {
                    Image(systemName: "arrow.right")
                      .font(.subheadline.weight(.bold))
                  }
                }
              }
              .buttonStyle(.borderedProminent)
              .tint(email.isEmpty ? AppTheme.Colors.disabled : AppTheme.Colors.tint(for: colorScheme))
              .disabled(email.isEmpty || isSubmitting)

              Button("Back to Sign In") {
                dismiss()
              }
              .font(.subheadline.weight(.medium))
              .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
              .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer(minLength: 60)

            // Secure Vault Protection Badge
            HStack(spacing: 8) {
              Image(systemName: "shield.fill")
              Text("SECURE NORVIQ PROTECTION")
            }
            .font(.caption.weight(.semibold))
            .tracking(1.0)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.cardBackground(for: colorScheme))
            .clipShape(Capsule())
            .overlay(
              Capsule()
                .stroke(.separator.opacity(0.2), lineWidth: 1)
            )
            .padding(.bottom, 40)
          }
        }
      }
    }
  }

  @MainActor
  private func submit() async {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    isSubmitting = true
    defer { isSubmitting = false }

    do {
        _ = try await viewModel.requestForgotPassword(for: trimmed)
      message = "Instructions sent successfully."
      errorMessage = nil
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not send reset instructions."
      message = nil
    }
  }
}
