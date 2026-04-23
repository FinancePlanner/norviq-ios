import StockPlanShared
import SwiftUI

struct VaultMFAVerificationView: View {
  @ObservedObject var viewModel: LoginViewModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack {
      MeshGradientBackground()

      VStack(alignment: .leading, spacing: 18) {
        HStack {
          Text("Two-Factor Verification")
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)
          Spacer()
          Button("Close") {
            viewModel.dismissMFAFlow()
            dismiss()
          }
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
        }

        Text("Enter the 6-digit code sent to \(viewModel.pendingMFAChallenge?.maskedDestination ?? "your email").")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        TextField("123456", text: $viewModel.mfaCode)
          .keyboardType(.numberPad)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .font(.title3.weight(.semibold).monospaced())
          .padding(.horizontal, 14)
          .padding(.vertical, 14)
          .foregroundStyle(.primary)
          .background(AppTheme.Colors.cardBackground(for: colorScheme))
          .clipShape(.rect(cornerRadius: 12))

        if let error = viewModel.mfaError, !error.isEmpty {
          FormErrorBanner(message: error)
        }

        if let message = viewModel.mfaInfoMessage, !message.isEmpty {
          HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text(message)
          }
          .font(.caption.weight(.medium))
          .foregroundStyle(AppTheme.Colors.success)
        }

        Button(action: { Task { await viewModel.submitMFA() } }) {
          HStack {
            if viewModel.isVerifyingMFA {
              ProgressView()
                .tint(.white)
            }
            Text(viewModel.isVerifyingMFA ? "Verifying..." : "Verify and Sign In")
              .font(.headline.weight(.semibold))
          }
        }
        .buttonStyle(.glassProminent)
        .tint(AppTheme.Colors.tint(for: colorScheme))
        .disabled(viewModel.isVerifyingMFA)

        Button(action: { Task { await viewModel.resendMFA() } }) {
          HStack(spacing: 6) {
            if viewModel.isResendingMFA {
              ProgressView()
                .tint(AppTheme.Colors.tint(for: colorScheme))
            }
            Text(resendLabel)
              .font(.subheadline.weight(.semibold))
          }
          .frame(maxWidth: .infinity)
        }
        .disabled(viewModel.isResendingMFA || viewModel.mfaResendAvailableIn > 0)
        .foregroundStyle(
          viewModel.mfaResendAvailableIn > 0 ? .secondary : AppTheme.Colors.tint(for: colorScheme)
        )

        Spacer()
      }
      .padding(24)
    }
  }

  private var resendLabel: String {
    if viewModel.mfaResendAvailableIn > 0 {
      return "Resend in \(viewModel.mfaResendAvailableIn)s"
    }
    return "Resend code"
  }
}
