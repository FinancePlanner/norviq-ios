//
//  LoginScreen.swift
//  financeplan
//
//  Created by Fernando Correia on 20.02.26.
//

import Factory
import SwiftUI

// MARK: - Shared Colors & Styles
private struct VaultColors {
    static let background = Color(red: 0.07, green: 0.07, blue: 0.08) // Deep Charcoal #121214
    static let cardBackground = Color(red: 0.11, green: 0.11, blue: 0.12) // #1C1C1E
    static let fieldBackgroundDark = Color(red: 0.15, green: 0.15, blue: 0.16) // Slightly lighter for contrast
    static let fieldBackgroundLight = Color.white
    static let primaryBlue = Color(red: 0.35, green: 0.65, blue: 1.0) // Bright Blue #5A9CFF
    static let textSecondary = Color(white: 0.6)
}

// MARK: - Logo Component
private struct VaultLogo: View {
    var isSignUp: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VaultColors.primaryBlue)
                .frame(width: 56, height: 56)
            
            Image(systemName: isSignUp ? "shield.fill" : "wallet.bifold.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(white: 0.1))
        }
        .shadow(color: VaultColors.primaryBlue.opacity(0.2), radius: 15, x: 0, y: 8)
    }
}

// MARK: - Custom Text Field
private struct VaultTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var isLight: Bool = false
    var rightAccessory: AnyView? = nil
    
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .default))
                .tracking(1.2)
                .foregroundColor(VaultColors.textSecondary)
            
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(VaultColors.textSecondary)
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
                .foregroundColor(isLight ? .black : .white)
                .accentColor(VaultColors.primaryBlue)
                
                if let rightAccessory = rightAccessory {
                    rightAccessory
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(isLight ? VaultColors.fieldBackgroundLight : VaultColors.fieldBackgroundDark)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? VaultColors.primaryBlue : Color.clear, lineWidth: 1)
            )
        }
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
                SignUpView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                SignInView(viewModel: viewModel)
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
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard viewModel.infoMessage == currentMessage else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.infoMessage = nil
            }
        }
    }
}

// MARK: - Sign In View
private struct SignInView: View {
    @ObservedObject var viewModel: LoginViewModel
    @State private var isPasswordVisible = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                
                // Header
                VStack(spacing: 16) {
                    VaultLogo(isSignUp: false)
                        .padding(.top, 60)
                    
                    Text("Vault")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .tracking(0.5)
                    
                    VStack(spacing: 8) {
                        Text("Welcome back")
                            .font(.system(size: 34, weight: .bold, design: .default))
                            .foregroundColor(.white)
                        
                        Text("Securely access your private financial\neditorial and curated portfolio.")
                            .font(.system(size: 15))
                            .foregroundColor(VaultColors.textSecondary)
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
                                rightAccessory: AnyView(
                                    Button(action: { isPasswordVisible.toggle() }) {
                                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(VaultColors.textSecondary)
                                    }
                                ),
                                textContentType: .password
                            )
                            
                            Button(action: { viewModel.isForgotPasswordPresented = true }) {
                                Text("FORGOT PASSWORD?")
                                    .font(.system(size: 10, weight: .bold, design: .default))
                                    .tracking(1.0)
                                    .foregroundColor(VaultColors.primaryBlue)
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
                        .foregroundColor(Color(white: 0.1))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(VaultColors.primaryBlue)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isSubmitting)
                    .padding(.top, 8)
                }
                .padding(24)
                .background(VaultColors.cardBackground)
                .cornerRadius(24)
                .padding(.horizontal, 24)
                
                // Switch to Sign Up
                Button(action: { viewModel.showSignup() }) {
                    HStack(spacing: 8) {
                        Text("No account? Sign up instead")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(VaultColors.textSecondary)
                        
                        Circle()
                            .fill(VaultColors.cardBackground)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(VaultColors.textSecondary)
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
                }
                .font(.system(size: 12))
                .foregroundColor(VaultColors.textSecondary)
                
                Text("© 2024 The Editorial Financial Experience. All rights reserved.")
                    .font(.system(size: 10))
                    .foregroundColor(VaultColors.textSecondary.opacity(0.6))
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
    @State private var isPasswordVisible = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // Header (Top Bar)
                HStack {
                    Text("Vault")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { viewModel.hideSignup() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(VaultColors.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                // Hero
                VStack(alignment: .center, spacing: 16) {
                    VaultLogo(isSignUp: true)
                        .padding(.top, 32)
                    
                    Text("Create your\naccount")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Join an elite community and experience\nthe future of editorial financial\nmanagement.")
                        .font(.system(size: 15))
                        .foregroundColor(VaultColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                
                // Form Fields
                VStack(spacing: 20) {
                    VaultTextField(
                        label: "First Name",
                        placeholder: "John",
                        text: $viewModel.firstName,
                        isLight: true,
                        textContentType: .givenName
                    )
                    
                    VaultTextField(
                        label: "Last Name",
                        placeholder: "Doe",
                        text: $viewModel.lastName,
                        isLight: true,
                        textContentType: .familyName
                    )
                    
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
                        rightAccessory: AnyView(
                            Button(action: { isPasswordVisible.toggle() }) {
                                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(Color(white: 0.8))
                            }
                        ),
                        textContentType: .newPassword
                    )
                    
                    // Custom Date Picker mimicking text field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DATE OF BIRTH")
                            .font(.system(size: 10, weight: .bold, design: .default))
                            .tracking(1.2)
                            .foregroundColor(VaultColors.textSecondary)
                        
                        HStack {
                            Text(formatter.string(from: viewModel.dateOfBirth))
                                .foregroundColor(.black)
                            Spacer()
                            Image(systemName: "calendar")
                                .foregroundColor(Color(white: 0.6))
                                .overlay {
                                    DatePicker("", selection: $viewModel.dateOfBirth, in: ...eighteenYearsAgo, displayedComponents: .date)
                                        .blendMode(.destinationOver)
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(VaultColors.fieldBackgroundLight)
                        .cornerRadius(12)
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
                        .foregroundColor(Color(white: 0.1))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(VaultColors.primaryBlue)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isSubmitting)
                    
                    Button(action: { viewModel.hideSignup() }) {
                        HStack(spacing: 8) {
                            Text("Already have an account?")
                                .foregroundColor(VaultColors.textSecondary)
                            Text("Log in instead")
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(VaultColors.cardBackground)
                        .cornerRadius(12)
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
                        Text("PRIVACY\nPOLICY").multilineTextAlignment(.center)
                        Text("TERMS OF\nSERVICE").multilineTextAlignment(.center)
                        Text("HELP\nCENTER").multilineTextAlignment(.center)
                    }
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(VaultColors.textSecondary)
                    
                    Text("© 2024 THE EDITORIAL FINANCIAL EXPERIENCE. ALL\nRIGHTS RESERVED.")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(VaultColors.textSecondary.opacity(0.6))
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
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
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
                Text("MEMBER BENEFIT")
                    .font(.system(size: 10, weight: .bold, design: .default))
                    .tracking(1.5)
                    .foregroundColor(VaultColors.primaryBlue)
                
                Text("Vault Platinum\nConcierge")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .padding(.top, 4)
                
                Text("Access 24/7 dedicated financial advisors\nafter verification.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.7))
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
                            .foregroundColor(VaultColors.primaryBlue)
                    }
                    Spacer()
                    Text("Vault")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
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
                        
                        // Lock Icon
                        ZStack {
                            Circle()
                                .fill(VaultColors.cardBackground)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "lock.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(VaultColors.primaryBlue)
                        }
                        .padding(.top, 40)
                        
                        // Titles
                        VStack(spacing: 12) {
                            Text("Reset Password")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Enter the email address associated with\nyour account and we'll send a code to\nreset your password.")
                                .font(.system(size: 16))
                                .foregroundColor(VaultColors.textSecondary)
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
                                .foregroundColor(.white)
                                .background(VaultColors.cardBackground)
                                .cornerRadius(12)
                            
                            if let message {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(message)
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            if let errorMessage {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                    Text(errorMessage)
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
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
                                .foregroundColor(Color(white: 0.1))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(email.isEmpty ? VaultColors.primaryBlue.opacity(0.5) : VaultColors.primaryBlue)
                                .cornerRadius(12)
                            }
                            .disabled(email.isEmpty || isSubmitting)
                            
                            Button(action: { dismiss() }) {
                                Text("Back to Sign In")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(VaultColors.primaryBlue)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        
                        Spacer(minLength: 60)
                        
                        // Secure Vault Protection Badge
                        HStack(spacing: 8) {
                            Image(systemName: "shield.fill")
                            Text("SECURE VAULT PROTECTION")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.0)
                        .foregroundColor(VaultColors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(VaultColors.cardBackground)
                        .clipShape(Capsule())
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
