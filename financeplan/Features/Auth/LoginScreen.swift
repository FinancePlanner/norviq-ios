//
//  LoginScreen.swift
//  financeplan
//
//  Created by Fernando Correia on 20.02.26.
//

import Factory
import SwiftUI

struct LoginScreen: View {
  @InjectedObject(\Container.windowSize) private var windowSize
  @InjectedObservable(\Container.appEnvironment) private var environment
  @StateObject private var viewModel: LoginViewModel

  @State private var contentSize = CGSize.zero
  @State private var screenSize = CGSize.zero
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
      .background(Color(.systemBackground).ignoresSafeArea())
      .overlay(alignment: .center) {
        forgotPasswordOverlay
      }
      .sheet(isPresented: termsSheetIsPresented) {
        termsSheetContent
      }
      .sheet(isPresented: privacySheetIsPresented) {
        privacySheetContent
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
    [viewModel.username, viewModel.password, viewModel.email, viewModel.firstName, viewModel.lastName]
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
    }
    .readSize(into: $screenSize)
    .scrollBounceBehavior(.basedOnSize)
    .scrollDismissesKeyboard(.interactively)
  }

  private var formContent: some View {
    content
      .readSize(into: $contentSize)
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
      .onAppear {
        focusedField = .username
      }
  }

  private var legalLinksFooter: some View {
    VStack(spacing: 0) {
      Divider()
        .opacity(0.3)

      legalLinks
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
    .background(Color(.systemBackground))
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

  @ViewBuilder
  private var termsSheetContent: some View {
    if let termsURL {
      SafariView(url: termsURL)
    }
  }

  @ViewBuilder
  private var privacySheetContent: some View {
    if let privacyURL {
      SafariView(url: privacyURL)
    }
  }

  @ViewBuilder
  private var forgotPasswordOverlay: some View {
    if viewModel.isForgotPasswordPresented {
      ForgotPasswordView(
        isPresented: Binding(
          get: { viewModel.isForgotPasswordPresented },
          set: { viewModel.isForgotPasswordPresented = $0 }
        ),
        onSubmit: { submittedEmail in
          try await viewModel.requestForgotPassword(for: submittedEmail)
        }
      )
    }
  }

  var content: some View {
    VStack(spacing: 10) {
      Spacer(minLength: 0)

      PulsingLogo()
        .padding(.bottom, 8)

      VStack(spacing: 8) {
        usernameTextField

        if viewModel.isSignup {
          emailTextField
            .opacity(viewModel.signupFieldsOpacity)
        }

        passwordTextField
        forgotPasswordLink

        if viewModel.isSignup {
          firstNameTextField
            .opacity(viewModel.signupFieldsOpacity)

          lastNameTextField
            .opacity(viewModel.signupFieldsOpacity)

          datePicker
            .padding(.top, 8)
            .opacity(viewModel.signupFieldsOpacity)
        }
      }

      if let error = viewModel.error {
        Text(error)
          .font(.footnote)
          .foregroundStyle(.red)
      }

      VStack(spacing: 4) {
        actionButton
        insteadButton
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(12)
  }

  @ViewBuilder
  var forgotPasswordLink: some View {
    if !viewModel.isSignup {
      Button {
        viewModel.isForgotPasswordPresented = true
      } label: {
        Text("Forgot password?")
          .font(.footnote)
          .foregroundStyle(.blue)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .padding(.bottom, 2)
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
      Text(viewModel.isSignup ? "Already have an account? Log in instead" : "No account? Sign up instead")
        .font(.footnote)
        .foregroundStyle(.blue)
        .padding(.top, 8)
    }
  }

  var legalLinks: some View {
    HStack(spacing: 16) {
      Button {
        termsURL = URL(string: "https://www.finplannerapp.com/terms")
      } label: {
        Text("Terms of Service")
          .font(.footnote)
          .foregroundStyle(.blue)
          .underline()
      }

      Button {
        privacyURL = URL(string: "https://www.finplannerapp.com/privacy")
      } label: {
        Text("Privacy Policy")
          .font(.footnote)
          .foregroundStyle(.blue)
          .underline()
      }

      if !environment.allowedEnvironmentsWhen(isLoggedIn: false).isEmpty {
        Button {
          isEnvironmentPresented = true
        } label: {
          Text("Environment")
            .font(.footnote)
            .foregroundStyle(.blue)
            .underline()
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

  var firstNameTextField: some View {
    fieldWithError(field: .firstName) {
      TextField("First Name", text: $viewModel.firstName)
        .textContentType(.givenName)
        .textInputAutocapitalization(.words)
        .focused($focusedField, equals: .firstName)
        .submitLabel(.next)
        .onSubmit { focusedField = .lastName }
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel("First Name")
    }
  }

  var lastNameTextField: some View {
    fieldWithError(field: .lastName) {
      TextField("Last Name", text: $viewModel.lastName)
        .textContentType(.familyName)
        .textInputAutocapitalization(.words)
        .focused($focusedField, equals: .lastName)
        .submitLabel(.next)
        .onSubmit { focusedField = nil }
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel("Last Name")
    }
  }

  private var eighteenYearsAgo: Date {
    Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
  }

  var datePicker: some View {
    DatePicker(
      "Date of Birth",
      selection: $viewModel.dateOfBirth,
      in: ...eighteenYearsAgo,
      displayedComponents: .date
    )
    .datePickerStyle(.compact)
    .padding(.top, 4)
    .accessibilityLabel("Date of Birth")
    .accessibilityHint("Must be 18 years or older")
  }

  var passwordTextField: some View {
    fieldWithError(field: .password) {
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
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel(viewModel.isSignup ? "New Password" : "Password")
    }
  }

  var emailTextField: some View {
    fieldWithError(field: .email) {
      TextField("Email", text: $viewModel.email)
        .textContentType(.emailAddress)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($focusedField, equals: .email)
        .submitLabel(.next)
        .onSubmit { focusedField = .password }
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel("Email Address")
    }
  }

  var usernameTextField: some View {
    fieldWithError(field: .username) {
      TextField(viewModel.isSignup ? "Username" : "Email", text: $viewModel.username)
        .textContentType(viewModel.isSignup ? .username : .emailAddress)
        .keyboardType(viewModel.isSignup ? .default : .emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($focusedField, equals: .username)
        .submitLabel(.next)
        .onSubmit { focusedField = viewModel.isSignup ? .email : .password }
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel(viewModel.isSignup ? "Username" : "Email")
    }
  }

  var actionButton: some View {
    Button {
      Task { await viewModel.submit() }
    } label: {
      HStack {
        if viewModel.isSubmitting {
          ProgressView()
            .tint(.white)
        }
        Text(viewModel.isSignup ? "Sign up" : "Sign in")
          .fontWeight(.semibold)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .foregroundStyle(.white)
      .background(viewModel.isSubmitting ? Color.gray : Color.blue)
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .disabled(viewModel.isSubmitting)
  }

  @ViewBuilder
  private func fieldWithError(
    field: LoginViewModel.Field,
    @ViewBuilder content: () -> some View
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      content()

      if let message = viewModel.fieldErrors[field] {
        HStack(alignment: .top, spacing: 6) {
          Image(systemName: "exclamationmark.circle.fill")
            .foregroundStyle(.red)
            .font(.caption)

          Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }
}

private struct PulsingLogo: View {
  @State private var pulse = false

  var body: some View {
    ZStack {
      Circle()
        .fill(Color.blue.opacity(0.16))
        .frame(width: pulse ? 86 : 72, height: pulse ? 86 : 72)

      Image(systemName: "chart.line.uptrend.xyaxis")
        .font(.system(size: 26, weight: .bold))
        .foregroundStyle(.blue)
    }
    .onAppear {
      withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
        pulse = true
      }
    }
  }
}

private struct ForgotPasswordView: View {
  @Binding var isPresented: Bool
  let onSubmit: (String) async throws -> String

  @State private var email = ""
  @State private var isSubmitting = false
  @State private var message: String?
  @State private var errorMessage: String?

  var body: some View {
    ZStack {
      Color.black.opacity(0.35)
        .ignoresSafeArea()
        .onTapGesture {
          isPresented = false
        }

      VStack(alignment: .leading, spacing: 12) {
        Text("Reset password")
          .font(.headline)

        Text("Enter your account email and we will send reset instructions.")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        TextField("Email", text: $email)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .textFieldStyle(.roundedBorder)

        if let message {
          Text(message)
            .font(.footnote)
            .foregroundStyle(.green)
        }

        if let errorMessage {
          Text(errorMessage)
            .font(.footnote)
            .foregroundStyle(.red)
        }

        HStack {
          Button("Close") {
            isPresented = false
          }

          Spacer()

          Button {
            Task { await submit() }
          } label: {
            HStack {
              if isSubmitting {
                ProgressView()
                  .tint(.white)
              }
              Text("Send")
                .fontWeight(.semibold)
            }
          }
          .buttonStyle(.borderedProminent)
          .disabled(isSubmitting)
        }
      }
      .padding(16)
      .frame(maxWidth: 420)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
      .padding(20)
    }
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
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not send reset instructions."
      message = nil
    }
  }
}
