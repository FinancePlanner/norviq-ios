//
//  UserProfileView.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import StockPlanShared
import SwiftUI

@MainActor
public struct UserProfileView: View {
    // MARK: - Layout Constants
    private let avatarSize: CGFloat = 72
    private let avatarOverhang: CGFloat = 40
    private let avatarInfoGap: CGFloat = 16
    private var infoTopPadding: CGFloat { avatarOverhang + avatarInfoGap }

    @StateObject private var viewModel: UserProfileViewModel
    @Environment(\.colorScheme) private var scheme

    @State private var isEditPresented = false

    public init(viewModel: UserProfileViewModel = UserProfileViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading profile...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 8) {
                        Text(error)
                            .foregroundStyle(.red)
                        Button("Retry") { Task { await viewModel.load() } }
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if let profile = viewModel.profile {
                    profileContent(profile)
                } else {
                    Text("No profile data")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .background(AppTheme.Colors.pageBackground(for: scheme))
            //.navigationTitle("Profile")
            .task { await viewModel.load() }
            .sheet(isPresented: $isEditPresented) {
                if let profile = viewModel.profile {
                    EditProfileView(viewModel: viewModel, profile: profile)
                }
            }
        }
    }

    // MARK: - Profile Content

    private func profileContent(_ profile: UserProfile) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Banner + Avatar
                headerSection(profile)

                // Info below the avatar
                infoSection(profile)
                    .padding(.top, infoTopPadding)
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Header (Banner + Avatar + Edit Button)

    private func headerSection(_ profile: UserProfile) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Banner
            bannerView(profile)
                .frame(height: 150)
                .clipped()

            // Avatar
            avatarView(profile)
                .offset(x: 16, y: avatarOverhang)

            // Edit (pencil) button — top right
            editButton
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(y: avatarOverhang + avatarInfoGap - 4)
                .padding(.trailing, 16)
        }
    }

    private func bannerView(_ profile: UserProfile) -> some View {
        ZStack {
            if let bannerURL = profile.bannerAvatarURL {
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

    private func avatarView(_ profile: UserProfile) -> some View {
        ZStack {
            if let avatarURL = profile.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        avatarPlaceholder(profile)
                    }
                }
            } else {
                avatarPlaceholder(profile)
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppTheme.Colors.pageBackground(for: scheme), lineWidth: 3)
        )
    }

    private func avatarPlaceholder(_ profile: UserProfile) -> some View {
        LinearGradient(
            colors: AppTheme.avatarGradient(for: scheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(placeholderInitial(for: profile))
                .font(.title2.bold())
                .foregroundStyle(.white)
        )
    }

    private var editButton: some View {
        Button {
            isEditPresented = true
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tint(for: scheme))
                .padding(8)
                .background(
                    Circle()
                        .fill(AppTheme.Colors.cardBackground(for: scheme))
                )
                .overlay(
                    Circle()
                        .stroke(AppTheme.Colors.tertiaryFill(for: scheme), lineWidth: 1)
                )
        }
    }

    // MARK: - Info Section

    private func infoSection(_ profile: UserProfile) -> some View {
        let fullName = fullName(for: profile)
        let username = formattedUsername(for: profile)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(displayTitle(fullName: fullName, username: username, email: profile.email))
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

//                if let username {
//                    Text(username)
//                        .font(.footnote.weight(.semibold))
//                        .foregroundStyle(.secondary)
//                        .padding(.horizontal, 8)
//                        .padding(.vertical, 3)
//                        .background(
//                            Capsule()
//                                .fill(AppTheme.Colors.tertiaryFill(for: scheme))
//                        )
//                }
            }


            // Bio
            if let bio = normalized(profile.bio) {
                Text(bio)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(.top, 4)
            }
            
            if let fullName {
                HStack(spacing: 4) {
                    Image(systemName: "person.crop.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(fullName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            // Email
            HStack(spacing: 4) {
                Image(systemName: "envelope")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(profile.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            Divider()
                .padding(.top, 12)
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func fullName(for profile: UserProfile) -> String? {
        let parts = [normalized(profile.firstName), normalized(profile.lastName)].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    private func formattedUsername(for profile: UserProfile) -> String? {
        guard let username = normalized(profile.username) else { return nil }
        return "@\(username)"
    }

    private func placeholderInitial(for profile: UserProfile) -> String {
        let seed =
            normalized(profile.username)
            ?? normalized(profile.firstName)
            ?? normalized(profile.lastName)
            ?? normalized(profile.email)
            ?? "?"

        return String(seed.prefix(1)).uppercased()
    }

    private func displayTitle(fullName: String?, username: String?, email: String) -> String {
        fullName ?? username ?? normalized(email) ?? "Profile"
    }
}

#Preview {
    UserProfileView(viewModel: UserProfileViewModel(service: UserProfileServiceStub()))
}
