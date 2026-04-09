//
//  LoginScreen.swift
//  financeplan
//
//  Created by Fernando Correia on 20.02.26.
//

import Factory
import SwiftUI
import StockPlanShared

// MARK: - Shared Colors & Styles
private struct VaultColors {
    static let background = Color(red: 0.07, green: 0.07, blue: 0.08) // Deep Charcoal #121214
    static let cardBackground = Color(red: 0.11, green: 0.11, blue: 0.12) // #1C1C1E
    static let fieldBackgroundDark = Color(red: 0.15, green: 0.15, blue: 0.16) // Slightly lighter for contrast
    static let fieldBackgroundLight = Color.white
    static let primaryBlue = Color(red: 0.35, green: 0.65, blue: 1.0) // Bright Blue #5A9CFF
    static let textSecondary = Color(white: 0.6)
}

private enum SocialAuthProvider: String, CaseIterable, Identifiable {
    case apple
    case google
    case x

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple:
            return "Continue with Apple"
        case .google:
            return "Continue with Google"
        case .x:
            return "Continue with X"
        }
    }

    var platformName: String {
        switch self {
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        case .x:
            return "X"
        }
    }

    var oauthProvider: OAuthProviderKind? {
        switch self {
        case .apple:
            return .apple
        case .google:
            return .google
        case .x:
            return .x
        }
    }
}

private struct SocialAuthButton: View {
    let provider: SocialAuthProvider
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon
                    .frame(width: 20, height: 20)

                Text(provider.title)
                    .font(.system(size: 15, weight: .semibold))

                Spacer()
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var icon: some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
        case .google:
            Image("GoogleLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        case .x:
            Image("XLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        }
    }

    private var foregroundColor: Color {
        switch provider {
        case .google:
            return .black
        case .apple, .x:
            return .white
        }
    }

    private var backgroundColor: Color {
        switch provider {
        case .google:
            return .white
        case .apple:
            return .black
        case .x:
            return Color(red: 0.02, green: 0.02, blue: 0.02)
        }
    }

    private var borderColor: Color {
        switch provider {
        case .google:
            return Color.black.opacity(0.08)
        case .apple, .x:
            return Color.white.opacity(0.08)
        }
    }
}

private struct SocialAuthSection: View {
    @ObservedObject var viewModel: LoginViewModel
    let intentLabel: String

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                Text("OR")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(VaultColors.textSecondary)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }

            VStack(spacing: 10) {
                ForEach(SocialAuthProvider.allCases) { provider in
                    SocialAuthButton(provider: provider) {
                        if let oauthProvider = provider.oauthProvider {
                            Task { await viewModel.signInWithOAuth(oauthProvider) }
                            return
                        }

                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.error = nil
                            viewModel.infoMessage = "\(provider.platformName) \(intentLabel) will be available soon."
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Logo Component
private struct NorviqaLogo: View {
    var size: CGFloat = 64

    var body: some View {
        Image("NorviqaLogoLight")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: VaultColors.primaryBlue.opacity(0.3), radius: 15, x: 0, y: 8)
    }
}

// MARK: - Custom Text Field
private struct VaultTextField<RightAccessory: View>: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var icon: String?
    var isSecure: Bool = false
    var isLight: Bool = false
    let rightAccessory: RightAccessory
    var showsRightAccessory: Bool = true

    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .default))
                .tracking(1.2)
                .foregroundStyle(VaultColors.textSecondary)

            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(VaultColors.textSecondary)
                        .frame(width: 20)
                }

                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .foregroundStyle(isLight ? .black : .white)
                .tint(VaultColors.primaryBlue)

                if showsRightAccessory {
                    rightAccessory
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(isLight ? VaultColors.fieldBackgroundLight : VaultColors.fieldBackgroundDark)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? VaultColors.primaryBlue : Color.clear, lineWidth: 1)
            )
        }
    }
}

private extension VaultTextField where RightAccessory == EmptyView {
    init(
        label: String,
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        isSecure: Bool = false,
        isLight: Bool = false,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
        self.isLight = isLight
        self.rightAccessory = EmptyView()
        self.showsRightAccessory = false
        self.keyboardType = keyboardType
        self.textContentType = textContentType
    }
}

// MARK: - Main Screen
struct LoginScreen: View {
    @InjectedObject(\Container.windowSize) private var windowSize
    @InjectedObservable(\Container.appEnvironment) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: LoginViewModel

    @State private var termsURL: URL?
    @State private var privacyURL: URL?
    @State private var isEnvironmentPresented = false
    @State private var isPasswordVisible = false

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
        ZStack {
            VaultColors.background.ignoresSafeArea()

            if viewModel.isSignup {
                SignUpView(viewModel: viewModel, isEnvironmentPresented: $isEnvironmentPresented)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                SignInView(viewModel: viewModel, isEnvironmentPresented: $isEnvironmentPresented)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            if let error = viewModel.error {
                VStack {
                    FormErrorBanner(message: error)
                        .padding()
                    Spacer()
                }
                .zIndex(100)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let info = viewModel.infoMessage {
                VStack {
                    ToastBanner(message: info, style: .success)
                        .padding()
                    Spacer()
                }
                .zIndex(100)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isSignup)
        .sheet(isPresented: $viewModel.isForgotPasswordPresented) {
            VaultForgotPasswordView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .task(id: viewModel.infoMessage) {
            guard let currentMessage = viewModel.infoMessage else { return }
            try? await Task.sleep(for: .seconds(3))
            guard viewModel.infoMessage == currentMessage else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.infoMessage = nil
            }
        }
        .confirmationDialog(
            "Switch from \(environment.current.title) to",
            isPresented: $isEnvironmentPresented,
            titleVisibility: .visible
        ) {
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
}

// MARK: - Sign In View
private struct SignInView: View {
    @ObservedObject var viewModel: LoginViewModel
    @Binding var isEnvironmentPresented: Bool
    @State private var isPasswordVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                // Header
                VStack(spacing: 16) {
                    NorviqaLogo(size: 78)
                        .padding(.top, 60)

                    VStack(spacing: 8) {
                        Text("Welcome back")
                            .font(.system(size: 34, weight: .bold, design: .default))
                            .foregroundStyle(.white)

                        Text("Securely access your private financial\neditorial and curated portfolio.")
                            .font(.system(size: 15))
                            .foregroundStyle(VaultColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.top, 8)
                }

                // Form Card
                VStack(spacing: 24) {
                    VaultTextField(
                        label: "Email Address",
                        placeholder: "name@domain.com",
                        text: $viewModel.username,
                        icon: "envelope.fill",
                        isLight: false,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )

                    VStack(alignment: .trailing, spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            VaultTextField(
                                label: "Security Code",
                                placeholder: "••••••••",
                                text: $viewModel.password,
                                icon: "lock.fill",
                                isSecure: !isPasswordVisible,
                                isLight: false,
                                rightAccessory:
                                    Button(action: { isPasswordVisible.toggle() }) {
                                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                            .foregroundStyle(VaultColors.textSecondary)
                                    }
                                    .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password"),
                                textContentType: .password
                            )

                            Button(action: { viewModel.isForgotPasswordPresented = true }) {
                                Text("FORGOT PASSWORD?")
                                    .font(.system(size: 10, weight: .bold, design: .default))
                                    .tracking(1.0)
                                    .foregroundStyle(VaultColors.primaryBlue)
                            }
                            .offset(y: 2)
                        }
                    }

                    Button(action: { Task { await viewModel.submit() } }) {
                        HStack {
                            if viewModel.isSubmitting {
                                ProgressView().tint(.black)
                                    .padding(.trailing, 8)
                            }
                            Text("Sign in")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(Color(white: 0.1))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(VaultColors.primaryBlue)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .disabled(viewModel.isSubmitting)
                    .padding(.top, 8)

                    SocialAuthSection(viewModel: viewModel, intentLabel: "sign in")
                        .padding(.top, 6)
                }
                .padding(24)
                .background(VaultColors.cardBackground)
                .clipShape(.rect(cornerRadius: 24))
                .padding(.horizontal, 24)

                // Switch to Sign Up
                Button(action: { viewModel.showSignup() }) {
                    HStack(spacing: 8) {
                        Text("No account? Sign up instead")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(VaultColors.textSecondary)

                        Circle()
                            .fill(VaultColors.cardBackground)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(VaultColors.textSecondary)
                            )
                    }
                }
                .padding(.top, 8)

                Spacer(minLength: 40)

                // Footer
                HStack(spacing: 24) {
                    Text("Privacy Policy")
                    Text("Terms of Service")
                    Text("Help Center")
                    #if DEBUG
                    Button("Environment") {
                        isEnvironmentPresented = true
                    }
                    #endif
                }
                .font(.system(size: 12))
                .foregroundStyle(VaultColors.textSecondary)

                Text("© 2024 The Editorial Financial Experience. All rights reserved.")
                    .font(.system(size: 10))
                    .foregroundStyle(VaultColors.textSecondary.opacity(0.6))
                    .padding(.top, 8)
                    .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Sign Up View
private struct SignUpView: View {
    @ObservedObject var viewModel: LoginViewModel
    @Binding var isEnvironmentPresented: Bool
    @State private var isPasswordVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Header (Top Bar)
                HStack {
                    Text("Norviqa")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: { viewModel.hideSignup() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(VaultColors.textSecondary)
                    }
                    .accessibilityLabel("Close sign up")
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // Hero
                VStack(alignment: .center, spacing: 16) {
                    NorviqaLogo(size: 78)
                        .padding(.top, 60)

                    Text("Create your\naccount")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Join an elite community and experience\nthe future of editorial financial\nmanagement.")
                        .font(.system(size: 15))
                        .foregroundStyle(VaultColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                // Form Fields
                VStack(spacing: 20) {
                    VaultTextField(
                        label: "Username",
                        placeholder: "johndoe",
                        text: $viewModel.username,
                        isLight: true,
                        textContentType: .username
                    )

                    VaultTextField(
                        label: "Email Address",
                        placeholder: "john@example.com",
                        text: $viewModel.email,
                        isLight: true,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )

                    VaultTextField(
                        label: "Password",
                        placeholder: "••••••••",
                        text: $viewModel.password,
                        isSecure: !isPasswordVisible,
                        isLight: true,
                        rightAccessory:
                            Button(action: { isPasswordVisible.toggle() }) {
                                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(Color(white: 0.8))
                            }
                            .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password"),
                        textContentType: .newPassword
                    )

                    // Custom Date Picker mimicking text field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DATE OF BIRTH")
                            .font(.system(size: 10, weight: .bold, design: .default))
                            .tracking(1.2)
                            .foregroundStyle(VaultColors.textSecondary)

                        HStack {
                            Text(formatter.string(from: viewModel.dateOfBirth))
                                .foregroundStyle(.black)
                            Spacer()
                            Image(systemName: "calendar")
                                .foregroundStyle(Color(white: 0.6))
                                .overlay {
                                    DatePicker("", selection: $viewModel.dateOfBirth, in: ...eighteenYearsAgo, displayedComponents: .date)
                                        .blendMode(.destinationOver)
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(VaultColors.fieldBackgroundLight)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)

                // Actions
                VStack(spacing: 16) {
                    Button(action: { Task { await viewModel.submit() } }) {
                        HStack {
                            if viewModel.isSubmitting {
                                ProgressView().tint(.black)
                                    .padding(.trailing, 8)
                            }
                            Text("Sign up")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(Color(white: 0.1))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(VaultColors.primaryBlue)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .disabled(viewModel.isSubmitting)

                    SocialAuthSection(viewModel: viewModel, intentLabel: "sign up")

                    Button(action: { viewModel.hideSignup() }) {
                        HStack(spacing: 8) {
                            Text("Already have an account?")
                                .foregroundStyle(VaultColors.textSecondary)
                            Text("Log in instead")
                                .foregroundStyle(.white)
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(VaultColors.cardBackground)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)

                // Promo Card
                VaultPlatinumCard()
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                    .padding(.bottom, 40)

                // Footer
                VStack(spacing: 16) {
                    HStack(spacing: 24) {
                        Text("Privacy Policy").multilineTextAlignment(.center)
                        Text("Terms of Service").multilineTextAlignment(.center)
                        Text("Help Center").multilineTextAlignment(.center)
                        #if DEBUG
                        Button(action: { isEnvironmentPresented = true }) {
                            Text("Environment").multilineTextAlignment(.center)
                        }
                        #endif
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(VaultColors.textSecondary)

                    Text("© 2024 The Editorial Financial Experience. All rights reserved.")
                        .font(.system(size: 10))
                        .foregroundStyle(VaultColors.textSecondary.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var eighteenYearsAgo: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    private var formatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        return dateFormatter
    }
}

// MARK: - Promo Card
private struct VaultPlatinumCard: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.15), Color(white: 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 8) {
                Text("NORDIQ")
                    .font(.system(size: 10, weight: .bold, design: .default))
                    .tracking(1.5)
                    .foregroundStyle(VaultColors.primaryBlue)

                Text("Your data forever yours only")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .padding(.top, 4)

                Text("EDIT THIS MUCH LATER")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.7))
                    .lineSpacing(4)
                    .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(height: 180)
    }
}

// MARK: - Forgot Password View
private struct VaultForgotPasswordView: View {
    @ObservedObject var viewModel: LoginViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isSubmitting = false
    @State private var message: String?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            VaultColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(VaultColors.primaryBlue)
                    }
                    .accessibilityLabel("Back to sign in")
                    Spacer()
                    Text("Norviqa")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    // Invisible placeholder to center the title
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .medium))
                        .opacity(0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 32) {

                        // Norviqa Logo
                        NorviqaLogo(size: 80)
                            .padding(.top, 40)

                        // Titles
                        VStack(spacing: 12) {
                            Text("Reset Password")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)

                            Text("Enter the email address associated with\nyour account and we'll send a code to\nreset your password.")
                                .font(.system(size: 16))
                                .foregroundStyle(VaultColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }

                        // Form
                        VStack(spacing: 24) {
                            TextField("Email Address", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding()
                                .foregroundStyle(.white)
                                .background(VaultColors.cardBackground)
                                .clipShape(.rect(cornerRadius: 12))

                            if let message {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(message)
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if let errorMessage {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                    Text(errorMessage)
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button(action: { Task { await submit() } }) {
                                HStack {
                                    if isSubmitting {
                                        ProgressView().tint(.black)
                                            .padding(.trailing, 8)
                                    }
                                    Text(isSubmitting ? "Sending..." : "Send Reset Link")
                                        .font(.system(size: 16, weight: .semibold))
                                    if !isSubmitting {
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                }
                                .foregroundStyle(Color(white: 0.1))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(email.isEmpty ? VaultColors.primaryBlue.opacity(0.5) : VaultColors.primaryBlue)
                                .clipShape(.rect(cornerRadius: 12))
                            }
                            .disabled(email.isEmpty || isSubmitting)

                            Button(action: { dismiss() }) {
                                Text("Back to Sign In")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(VaultColors.primaryBlue)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                        Spacer(minLength: 60)

                        // Secure Vault Protection Badge
                        HStack(spacing: 8) {
                            Image(systemName: "shield.fill")
                            Text("SECURE NORVIQA PROTECTION")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(VaultColors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(VaultColors.cardBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(VaultColors.textSecondary.opacity(0.2), lineWidth: 1)
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
            try await viewModel.requestForgotPassword(for: trimmed)
            message = "Instructions sent successfully."
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not send reset instructions."
            message = nil
        }
    }
}
