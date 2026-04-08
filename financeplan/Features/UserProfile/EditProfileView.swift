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
    @State private var successFeedbackTrigger = 0

    @FocusState private var focusedField: Field?

    private let originalProfile: UserProfile

    private enum Field { case username, bio }

    init(viewModel: UserProfileViewModel, profile: UserProfile) {
        self.viewModel = viewModel
        self.originalProfile = profile
        _username = State(initialValue: profile.username ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Banner + Avatar
                    headerSection

                    // MARK: - Editable Fields
                    fieldsSection
                        .padding(.top, fieldsTopPadding)
                }
            }
            .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.large)
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

    // MARK: - Header (Banner + Avatar)

    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Banner
            bannerView
                .frame(height: 150)
                .clipped()
                .overlay(alignment: .center) {
                    // Camera icon on banner
                    cameraOverlayButton
                }

            // Avatar
            avatarView
                .offset(x: 16, y: avatarOverhang)
        }
    }

    private var bannerView: some View {
        ZStack {
            if let bannerURL = originalProfile.bannerAvatarURL {
                AsyncImage(url: bannerURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        bannerPlaceholder
                    }
                }
            } else {
                bannerPlaceholder
            }
        }
    }

    private var bannerPlaceholder: some View {
        LinearGradient(
            colors: AppTheme.heroGradient(for: scheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var avatarView: some View {
        ZStack {
            if let avatarURL = originalProfile.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppTheme.Colors.pageBackground(for: scheme), lineWidth: 3)
        )
        .overlay(
            // Camera icon on avatar
            Image(systemName: "camera.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(6)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
                .accessibilityLabel("Change profile photo")
        )
    }

    private var avatarPlaceholder: some View {
        LinearGradient(
            colors: AppTheme.avatarGradient(for: scheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(avatarInitial)
                .font(.title2.bold())
                .foregroundStyle(.white)
        )
    }

    private var avatarInitial: String {
        let seed =
            normalized(username)
            ?? normalized(originalProfile.username)
            ?? normalized(originalProfile.email)
            ?? "?"

        return String(seed.prefix(1)).uppercased()
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var cameraOverlayButton: some View {
        Image(systemName: "camera.fill")
            .font(.system(size: 18))
            .foregroundStyle(.white)
            .padding(10)
            .background(Color.black.opacity(0.5))
            .clipShape(Circle())
            .accessibilityLabel("Change banner photo")
    }

    // MARK: - Fields

    private var fieldsSection: some View {
        VStack(spacing: 0) {
            editableRow(label: "Username", text: $username)
            divider
        }
        .padding(.horizontal, 16)
    }

    private func editableRow(label: String, text: Binding<String>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            TextField(label, text: text)
                .font(.body)
                .foregroundStyle(.primary)
                .focused($focusedField, equals: label == "Username" ? .username : label == "Bio" ? .bio : nil)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(label == "Username")
        }
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.Colors.tertiaryFill(for: scheme))
            .frame(height: 1)
    }

    // MARK: - Actions

    private func saveProfile() {
        var updated = originalProfile
        updated.username = username.isEmpty ? nil : username

        Task {
            if await viewModel.save(profile: updated) {
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
