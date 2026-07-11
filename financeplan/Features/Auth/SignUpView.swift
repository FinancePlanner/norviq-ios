import SwiftUI

struct SignUpView: View {
  @ObservedObject var viewModel: LoginViewModel
  @State private var isPasswordVisible = false
  @State private var isConfirmPasswordVisible = false
  @State private var isDatePickerPresented = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        // Header
        HStack {
          Text("Norviq")
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
          Spacer()
          Button("Close", systemImage: "xmark") {
            viewModel.hideSignup()
          }
          .labelStyle(.iconOnly)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(.secondary)
          .frame(width: 44, height: 44)
          .contentShape(.rect)
          .accessibilityLabel("Close sign up")
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)

        // Hero
        VStack(alignment: .center, spacing: 16) {
          NorviqFullLogo(width: 220)
            .padding(.top, 24)

          Text("Create your\naccount")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)

          Text("Bring your portfolio and budgets together in one secure place.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.bottom, 40)

        // Form Fields
        GlassCard(cornerRadius: AppTheme.Radius.hero) {
          VStack(spacing: 20) {
            VaultTextField(
              label: "Username",
              placeholder: "johndoe",
              text: $viewModel.username,
              textContentType: .username,
              submitLabel: .next
            )

            VaultTextField(
              label: "Email Address",
              placeholder: "john@example.com",
              text: $viewModel.email,
              keyboardType: .emailAddress,
              textContentType: .emailAddress,
              submitLabel: .next
            )

            VaultTextField(
              label: "Password",
              placeholder: "••••••••",
              text: $viewModel.password,
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
                .contentShape(.rect),
              textContentType: .newPassword,
              submitLabel: .next
            )

            PasswordStrengthMeter(
              score: viewModel.passwordRuleScore,
              strength: viewModel.passwordStrength
            )

            VaultTextField(
              label: "Confirm Password",
              placeholder: "••••••••",
              text: $viewModel.confirmPassword,
              isSecure: !isConfirmPasswordVisible,
              rightAccessory:
                Button(
                  isConfirmPasswordVisible ? "Hide confirm password" : "Show confirm password",
                  systemImage: isConfirmPasswordVisible ? "eye.slash.fill" : "eye.fill",
                  action: { isConfirmPasswordVisible.toggle() }
                )
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(.rect),
              textContentType: .newPassword,
              submitLabel: .next
            )

            // Date of Birth
            VStack(alignment: .leading, spacing: 8) {
              Text("DATE OF BIRTH")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

              Button(action: { isDatePickerPresented = true }) {
                HStack {
                  Text(viewModel.dateOfBirth, format: .dateTime.day().month().year())
                    .foregroundStyle(.primary)
                  Spacer()
                  Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(AppTheme.Colors.cardBackground(for: colorScheme))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                  RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.Colors.separator(for: colorScheme), lineWidth: 1)
                )
              }
.buttonStyle(.bordered)
            }
          }
          .padding(24)
        }
        .padding(.horizontal, 24)

        // Actions
        VStack(spacing: 16) {
          Button(action: { Task { await viewModel.submit() } }) {
            HStack {
              if viewModel.isSubmitting {
                ProgressView()
                  .tint(.white)
                  .padding(.trailing, 8)
              }
              Text("Sign up")
                .font(.headline.weight(.semibold))
              Image(systemName: "arrow.right")
                .font(.subheadline.weight(.bold))
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(AppTheme.Colors.tint(for: colorScheme))
          .disabled(viewModel.isSubmitting || !viewModel.canSubmitSignup)

          SocialAuthSection(viewModel: viewModel, intentLabel: "sign up")

          Button(action: { viewModel.hideSignup() }) {
            HStack(spacing: 8) {
              Text("Already have an account?")
                .foregroundStyle(.secondary)
              Text("Log in instead")
                .foregroundStyle(.primary)
                .fontWeight(.semibold)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.Colors.cardBackground(for: colorScheme))
            .clipShape(.rect(cornerRadius: 12))
          }
.buttonStyle(.bordered)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)

        // Promo Card
//        VaultPlatinumCard()
//          .padding(.horizontal, 24)
//          .padding(.top, 40)
//          .padding(.bottom, 40)

        Spacer(minLength: 40)

        AuthFooter()
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .sheet(isPresented: $isDatePickerPresented) {
      DatePickerSheet(
        date: $viewModel.dateOfBirth,
        maxDate: Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
      )
    }
  }
}

// MARK: - Date Picker Sheet

private struct DatePickerSheet: View {
  @Binding var date: Date
  let maxDate: Date
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack {
        DatePicker(
          "Date of Birth",
          selection: $date,
          in: ...maxDate,
          displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .padding()

        Spacer()
      }
      .navigationTitle("Select Date")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}
