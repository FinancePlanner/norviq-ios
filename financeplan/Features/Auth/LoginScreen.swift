//
//  LoginScreen.swift
//  financeplan
//
//  Created by Fernando Correia on 20.02.26.
//

import Factory
import SwiftUI

struct GlassTextFieldStyle: TextFieldStyle {
  @Environment(\.colorScheme) private var colorScheme
  func _body(configuration: TextField<Self._Label>) -> some View {
    configuration
      .padding(14)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(AppTheme.Colors.elevatedCardBackground(for: colorScheme))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(
            AppTheme.Colors.separator(for: colorScheme).opacity(colorScheme == .dark ? 0.35 : 0.18),
            lineWidth: 0.8
          )
      )
  }
}

struct LoginScreen: View {
  @InjectedObject(\Container.windowSize) private var windowSize
  @InjectedObservable(\Container.appEnvironment) private var environment
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var viewModel: LoginViewModel

  @State private var termsURL: URL?
  @State private var privacyURL: URL?
  @State private var isEnvironmentPresented = false

  @FocusState private var focusedField: LoginViewModel.Field?

  @MainActor
  init(onAuthenticated: @escaping () -> Void = {}) {
    _viewModel = StateObject(
      wrappedValue: LoginViewModel(
        authService: Container.shared.authService(),
        sessionStore: Container.shared.authSessionStore(),
        onAuthenticated: onAuthenticated
      )
    )
  }

  var body: some View {
    mainLayout
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
      .overlay(alignment: .top) {
        successToastOverlay
      }
      .sheet(isPresented: termsSheetIsPresented) {
        termsSheetContent
      }
      .sheet(isPresented: privacySheetIsPresented) {
        privacySheetContent
      }
      .sheet(isPresented: forgotPasswordSheetIsPresented) {
        ForgotPasswordSheet(
          onSubmit: { submittedEmail in
            try await viewModel.requestForgotPassword(for: submittedEmail)
          }
        )
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
      }
      .task(id: viewModel.infoMessage) {
        guard let currentMessage = viewModel.infoMessage else {
          return
        }

        try? await Task.sleep(nanoseconds: 3_000_000_000)
        guard viewModel.infoMessage == currentMessage else {
          return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
          viewModel.infoMessage = nil
        }
      }
      .confirmationDialog(
        "Switch from \(environment.current.title) to",
        isPresented: $isEnvironmentPresented,
        titleVisibility: .visible
      ) {
        confirmationDialog
      }
  }

  private var formTextFieldsState: [String] {
    [
      viewModel.username, viewModel.password, viewModel.email, viewModel.firstName,
      viewModel.lastName,
    ]
  }

  private var mainLayout: some View {
    VStack(spacing: 0) {
      authScrollView
      legalLinksFooter
    }
  }

  private var authScrollView: some View {
    ScrollView {
      formContent
        .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .scrollBounceBehavior(.basedOnSize)
    .scrollDismissesKeyboard(.interactively)
  }

  private var formContent: some View {
    VStack(spacing: 20) {
      content
    }
    .frame(maxWidth: windowSize.effectiveFormMaxWidth)
    .onChange(of: formTextFieldsState) { _, _ in
      viewModel.clearError()
    }
    .onChange(of: viewModel.username) { _, newValue in
      viewModel.sanitizeUsernameInput(newValue)
      viewModel.clearFieldError(.username)
    }
    .onChange(of: viewModel.password) { _, _ in viewModel.clearFieldError(.password) }
    .onChange(of: viewModel.email) { _, _ in viewModel.clearFieldError(.email) }
    .onChange(of: viewModel.firstName) { _, _ in viewModel.clearFieldError(.firstName) }
    .onChange(of: viewModel.lastName) { _, _ in viewModel.clearFieldError(.lastName) }
    .padding(.horizontal, 20)
    .padding(.top, 24)
  }

  private var legalLinksFooter: some View {
    VStack(spacing: 0) {
      Divider()
        .opacity(0.3)

      legalLinks
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
    .background(.clear)
    .ignoresSafeArea(.keyboard)
  }

  private var termsSheetIsPresented: Binding<Bool> {
    Binding(
      get: { termsURL != nil },
      set: { if !$0 { termsURL = nil } }
    )
  }

  private var privacySheetIsPresented: Binding<Bool> {
    Binding(
      get: { privacyURL != nil },
      set: { if !$0 { privacyURL = nil } }
    )
  }

  private var forgotPasswordSheetIsPresented: Binding<Bool> {
    Binding(
      get: { viewModel.isForgotPasswordPresented },
      set: { viewModel.isForgotPasswordPresented = $0 }
    )
  }

  @ViewBuilder
  private var termsSheetContent: some View {
    if let termsURL {
      ExternalBrowserLinkSheet(
        url: termsURL,
        openActionTitle: "Open terms of service",
        message: "Terms open in your default browser."
      )
    }
  }

  @ViewBuilder
  private var privacySheetContent: some View {
    if let privacyURL {
      ExternalBrowserLinkSheet(
        url: privacyURL,
        openActionTitle: "Open privacy policy",
        message: "Privacy policy opens in your default browser."
      )
    }
  }

  @ViewBuilder
  private var successToastOverlay: some View {
    if let info = viewModel.infoMessage {
      ToastBanner(
        message: info,
        style: .success
      )
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .transition(.move(edge: .top).combined(with: .opacity))
      .accessibilityAddTraits(.isStaticText)
    }
  }

  // MARK: - Content

  var content: some View {
    VStack(spacing: 20) {
      // MARK: - Hero
      VStack(alignment: .leading, spacing: 14) {
        PulsingLogo()

        VStack(alignment: .leading, spacing: 6) {
          Text(viewModel.isSignup ? "Create your account" : "Welcome back")
            .typography(.heading, weight: .bold)
            .accessibilityAddTraits(.isHeader)

          Text(
            viewModel.isSignup
              ? "Build your investing workspace with portfolio planning and monthly spending visibility."
              : "Sign in to review your portfolio, plan expenses, and keep your financial system in one place."
          )
          .typography(.small)
          .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // MARK: - Connected Field Card
      connectedFieldCard

      // MARK: - Forgot Password
      forgotPasswordLink

      // MARK: - Error
      if let error = viewModel.error {
        FormErrorBanner(message: error)
      }

      // MARK: - Action
      actionButton
        .padding(.top, 4)

      // MARK: - Toggle
      insteadButton
    }
  }

  // MARK: - Connected Field Card

  /// Groups all fields into a single card with thin dividers between them.
  private var connectedFieldCard: some View {
    VStack(spacing: 0) {
      // --- Username / Email ---
      connectedField(
        icon: viewModel.isSignup ? "person" : "envelope",
        iconColor: AppTheme.Colors.tint(for: colorScheme)
      ) {
        TextField(viewModel.isSignup ? "Username" : "Email", text: $viewModel.username)
          .textContentType(viewModel.isSignup ? .username : .emailAddress)
          .keyboardType(viewModel.isSignup ? .default : .emailAddress)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .focused($focusedField, equals: .username)
          .submitLabel(.next)
          .onSubmit { focusedField = viewModel.isSignup ? .email : .password }
          .accessibilityLabel(viewModel.isSignup ? "Username" : "Email")
      }
      fieldError(for: .username)

      connectedDivider

      // --- Email (signup only) ---
      if viewModel.isSignup {
        connectedField(icon: "envelope", iconColor: .orange) {
          TextField("Email", text: $viewModel.email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit { focusedField = .password }
            .accessibilityLabel("Email Address")
        }
        .opacity(viewModel.signupFieldsOpacity)
        fieldError(for: .email)

        connectedDivider
      }

      // --- Password ---
      connectedField(icon: "lock", iconColor: .secondary) {
        SecureField("Password", text: $viewModel.password)
          .textContentType(viewModel.isSignup ? .newPassword : .password)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .focused($focusedField, equals: .password)
          .submitLabel(viewModel.isSignup ? .next : .go)
          .onSubmit {
            if viewModel.isSignup {
              focusedField = .firstName
            } else {
              Task { await viewModel.submit() }
            }
          }
          .accessibilityLabel(viewModel.isSignup ? "New Password" : "Password")
      }
      fieldError(for: .password)

      // --- Signup-only fields ---
      if viewModel.isSignup {
        connectedDivider

        connectedField(icon: "person.text.rectangle", iconColor: AppTheme.Colors.secondaryTint(for: colorScheme)) {
          TextField("First Name", text: $viewModel.firstName)
            .textContentType(.givenName)
            .textInputAutocapitalization(.words)
            .focused($focusedField, equals: .firstName)
            .submitLabel(.next)
            .onSubmit { focusedField = .lastName }
            .accessibilityLabel("First Name")
        }
        .opacity(viewModel.signupFieldsOpacity)
        fieldError(for: .firstName)

        connectedDivider

        connectedField(icon: "person.text.rectangle", iconColor: AppTheme.Colors.secondaryTint(for: colorScheme)) {
          TextField("Last Name", text: $viewModel.lastName)
            .textContentType(.familyName)
            .textInputAutocapitalization(.words)
            .focused($focusedField, equals: .lastName)
            .submitLabel(.done)
            .onSubmit { focusedField = nil }
            .accessibilityLabel("Last Name")
        }
        .opacity(viewModel.signupFieldsOpacity)
        fieldError(for: .lastName)

        connectedDivider

        // Date of birth
        HStack(spacing: 12) {
          Image(systemName: "calendar")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.orange)
            .frame(width: 24, alignment: .center)

          DatePicker(
            "Date of Birth",
            selection: $viewModel.dateOfBirth,
            in: ...eighteenYearsAgo,
            displayedComponents: .date
          )
          .datePickerStyle(.compact)
          .accessibilityLabel("Date of Birth")
          .accessibilityHint("Must be 18 years or older")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .opacity(viewModel.signupFieldsOpacity)
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(AppTheme.Colors.cardBackground(for: colorScheme))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(
          AppTheme.Colors.separator(for: colorScheme)
            .opacity(colorScheme == .dark ? 0.25 : 0.12),
          lineWidth: 0.8
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  /// A single connected field row with leading icon.
  private func connectedField<Content: View>(
    icon: String,
    iconColor: Color,
    @ViewBuilder content: () -> Content
  ) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(iconColor)
        .frame(width: 24, alignment: .center)

      content()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 13)
  }

  /// Thin internal divider for the connected card.
  private var connectedDivider: some View {
    Rectangle()
      .fill(AppTheme.Colors.separator(for: colorScheme).opacity(0.35))
      .frame(height: 0.5)
      .padding(.leading, 52)
  }

  /// Field-level error displayed below a field in the card.
  @ViewBuilder
  private func fieldError(for field: LoginViewModel.Field) -> some View {
    if let message = viewModel.fieldErrors[field] {
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.circle.fill")
          .foregroundStyle(AppTheme.Colors.danger)
          .font(.caption2)

        Text(message)
          .typography(.nano)
          .foregroundStyle(AppTheme.Colors.danger)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 52)
      .padding(.vertical, 4)
    }
  }

  // MARK: - Links & Buttons

  @ViewBuilder
  var forgotPasswordLink: some View {
    if !viewModel.isSignup {
      Button {
        viewModel.isForgotPasswordPresented = true
      } label: {
        Text("Forgot password?")
          .typography(.small)
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
  }

  var insteadButton: some View {
    Button {
      if viewModel.isSignup {
        viewModel.hideSignup()
      } else {
        viewModel.showSignup()
      }
    } label: {
      Text(
        viewModel.isSignup
          ? "Already have an account? Log in instead" : "No account? Sign up instead"
      )
      .typography(.small)
      .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
      .padding(.vertical, 10)
      .padding(.horizontal, 20)
      .background(
        Capsule()
          .stroke(AppTheme.Colors.tint(for: colorScheme).opacity(0.3), lineWidth: 1)
      )
    }
  }

  var legalLinks: some View {
    HStack(spacing: 16) {
      Button {
        termsURL = URL(string: "https://www.finplannerapp.com/terms")
      } label: {
        Text("Terms of Service")
          .typography(.nano)
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
      }

      Button {
        privacyURL = URL(string: "https://www.finplannerapp.com/privacy")
      } label: {
        Text("Privacy Policy")
          .typography(.nano)
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
      }

      if !environment.allowedEnvironmentsWhen(isLoggedIn: false).isEmpty {
        Button {
          isEnvironmentPresented = true
        } label: {
          Text("Environment")
            .typography(.nano)
            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  var confirmationDialog: some View {
    Group {
      ForEach(environment.allowedEnvironmentsWhen(isLoggedIn: false), id: \.title) { env in
        Button(action: {
          environment.change(to: env)
        }) {
          Text(env.title)
        }
        .disabled(env == environment.current)
      }
    }
  }

  private var eighteenYearsAgo: Date {
    Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
  }

  // MARK: - Action Button

  var actionButton: some View {
    Button {
      Task { await viewModel.submit() }
    } label: {
      HStack(spacing: 8) {
        if viewModel.isSubmitting {
          ProgressView()
            .tint(.white)
        }
        Text(viewModel.isSignup ? "Sign up" : "Sign in")
          .font(.headline)
          .fontWeight(.bold)
        if !viewModel.isSubmitting {
          Image(systemName: "arrow.right")
            .font(.subheadline.weight(.bold))
        }
      }
    }
    .buttonStyle(GlowingButtonStyle())
    .disabled(viewModel.isSubmitting)
  }
}

// MARK: - Pulsing Logo

private struct PulsingLogo: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var pulse = false

  var body: some View {
    ZStack {
      // Outer glow ring
      Circle()
        .fill(AppTheme.Colors.tint(for: colorScheme).opacity(0.08))
        .frame(width: 96, height: 96)
        .scaleEffect(pulse ? 1.08 : 0.92)

      // Inner fill
      Circle()
        .fill(AppTheme.Colors.tintSoft(for: colorScheme))
        .frame(width: 72, height: 72)

      Image(systemName: "chart.line.uptrend.xyaxis")
        .font(.system(size: 28, weight: .bold))
        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
    }
    .frame(width: 96, height: 96)
    .onAppear {
      withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
        pulse = true
      }
    }
  }
}

// MARK: - Forgot Password Sheet

private struct ForgotPasswordSheet: View {
  let onSubmit: (String) async throws -> String

  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  @State private var email = ""
  @State private var isSubmitting = false
  @State private var message: String?
  @State private var errorMessage: String?

  var body: some View {
    VStack(spacing: 0) {
      FormSheetHeader(title: "Reset Password", onDismiss: { dismiss() })

      ScrollView {
        VStack(spacing: 16) {
          // Icon
          ZStack {
            Circle()
              .fill(AppTheme.Colors.tintSoft(for: colorScheme))
              .frame(width: 64, height: 64)

            Image(systemName: "key.fill")
              .font(.system(size: 24, weight: .semibold))
              .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          }

          Text("Enter your account email and we'll send reset instructions.")
            .typography(.small)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)

          FormCard {
            FormTextField(
              icon: "envelope",
              iconColor: AppTheme.Colors.tint(for: colorScheme),
              placeholder: "Email address",
              text: $email,
              keyboardType: .emailAddress,
              autocapitalization: .never,
              disableAutocorrection: true
            )
          }

          if let message {
            HStack(spacing: 8) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.Colors.success)
              Text(message)
                .typography(.small)
                .foregroundStyle(AppTheme.Colors.success)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.success.opacity(0.08))
            )
          }

          if let errorMessage {
            FormErrorBanner(message: errorMessage)
          }

          Spacer(minLength: 60)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
      }
      .scrollDismissesKeyboard(.interactively)

      FormActionBar(
        primaryLabel: isSubmitting ? "Sending…" : "Send Instructions",
        isLoading: isSubmitting,
        isDisabled: email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting
      ) {
        Task { await submit() }
      }
    }
    .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
  }

  @MainActor
  private func submit() async {
    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      errorMessage = "Email is required"
      message = nil
      return
    }

    isSubmitting = true
    defer { isSubmitting = false }

    do {
      message = try await onSubmit(trimmed)
      errorMessage = nil
    } catch {
      errorMessage =
        (error as? LocalizedError)?.errorDescription ?? "Could not send reset instructions."
      message = nil
    }
  }
}
