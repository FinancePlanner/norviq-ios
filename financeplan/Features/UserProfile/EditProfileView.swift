//
//  EditProfileView.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import StockPlanShared
import SwiftUI

@MainActor
struct EditProfileView: View {
    // MARK: - Layout Constants
    private let avatarSize: CGFloat = 72
    private let avatarOverhang: CGFloat = 40
    private let avatarInfoGap: CGFloat = 16
    private var fieldsTopPadding: CGFloat { avatarOverhang + avatarInfoGap }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @ObservedObject var viewModel: UserProfileViewModel

    // Local editable copy
    @State private var username: String
    @State private var email: String
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var successFeedbackTrigger = 0

    @FocusState private var focusedField: Field?

    private let originalProfile: UserProfile

    private enum Field { case username, email, currentPassword, newPassword }

    init(viewModel: UserProfileViewModel, profile: UserProfile) {
        self.viewModel = viewModel
        self.originalProfile = profile
        _username = State(initialValue: profile.username ?? "")
        _email = State(initialValue: profile.email)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Username") {
                    TextField("Username", text: $username)
                        .focused($focusedField, equals: .username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Email") {
                    TextField("Email", text: $email)
                        .focused($focusedField, equals: .email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }

                Section("Change Password") {
                    SecureField("Current Password", text: $currentPassword)
                        .focused($focusedField, equals: .currentPassword)
                    SecureField("New Password", text: $newPassword)
                        .focused($focusedField, equals: .newPassword)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .background(AppTheme.Colors.pageBackground(for: scheme))
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.Colors.tint(for: scheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.tint(for: scheme))
                    .disabled(viewModel.isLoading)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
        .appSensoryFeedback(success: successFeedbackTrigger)
    }

    // MARK: - Actions

    private func saveProfile() {
        Task {
            var success = true

            // 1. Update Username if changed
            if username != (originalProfile.username ?? "") {
                success = await viewModel.updateUsername(username)
            }

            // 2. Update Email if changed
            if success && email != originalProfile.email {
                success = await viewModel.updateEmail(email)
            }

            // 3. Update Password if provided
            if success && !newPassword.isEmpty {
                if currentPassword.isEmpty {
                    viewModel.save(profile: originalProfile) // Trigger an error if needed or manual setting
                    // Custom error handling would be better here
                    success = false
                } else {
                    success = await viewModel.updatePassword(current: currentPassword, new: newPassword)
                }
            }

            if success {
                successFeedbackTrigger += 1
                dismiss()
            }
        }
    }
}

#Preview {
    let vm = UserProfileViewModel(service: UserProfileServiceStub())
    let stubProfile = UserProfile(
        id: "preview-id",
        email: "preview@example.com",
        username: "previewuser"
    )

    EditProfileView(viewModel: vm, profile: stubProfile)
}
