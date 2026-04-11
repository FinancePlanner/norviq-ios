//
//  UserProfileView.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import StockPlanShared
import SwiftUI
import Factory

private enum UserProfileDestination: Hashable {
    case securityCode
    case badges
    case helpSupport
    case shareFeedback
    case about
    case dataHandling
    case sensitiveActions
}

@MainActor
public struct UserProfileView: View {
    @StateObject private var viewModel: UserProfileViewModel
    @StateObject private var pushNotificationsCoordinator: PushNotificationsCoordinator
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var path: [UserProfileDestination] = []
    @State private var isEditPresented = false
    @State private var isLoggingOut = false

    // Appearance State
    @AppStorage(AppAppearance.storageKey) private var appAppearanceRawValue = AppAppearance.system.rawValue

    // Security State
    @AppStorage("useFaceID") private var useFaceID: Bool = true

    public init(viewModel: UserProfileViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? UserProfileViewModel())
        _pushNotificationsCoordinator = StateObject(
            wrappedValue: Container.shared.pushNotificationsCoordinator()
        )
    }

    public var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.isLoading && viewModel.profile == nil {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    settingsList(profile: viewModel.profile)
                }
            }
            .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.tint(for: scheme))
                }
            }
            .task {
                await viewModel.load()
                pushNotificationsCoordinator.handleAuthenticatedSessionBecameActive()
            }
            .sheet(isPresented: $isEditPresented) {
                if let profile = viewModel.profile {
                    EditProfileView(viewModel: viewModel, profile: profile)
                }
            }
            .navigationDestination(for: UserProfileDestination.self) { destination in
                switch destination {
                case .securityCode:
                    Text("Security Code")
                case .badges:
                    BadgesView()
                case .helpSupport:
                    Text("Help & Support")
                case .shareFeedback:
                    Text("Share Feedback")
                case .about:
                    Text("About Norviqa")
                case .dataHandling:
                    Text("Data handling")
                case .sensitiveActions:
                    Text("Sensitive actions")
                }
            }
        }
    }

    private func settingsList(profile: UserProfile?) -> some View {
        List {
            // Profile Card
            Section {
                Button {
                    isEditPresented = true
                } label: {
                    HStack(spacing: 14) {
                        avatarView(profile)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile?.username ?? "Unknown User")
                                .typography(.label, weight: .semibold)
                                .foregroundStyle(.primary)
                            Text("View and edit your account")
                                .typography(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Security
            Section("Security") {
                Toggle(isOn: $useFaceID) {
                    HStack(spacing: 12) {
                        Label("Face ID", systemImage: "faceid")
                    }
                }

                NavigationLink(value: UserProfileDestination.securityCode) {
                    Label("Security Code", systemImage: "lock.fill")
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            Section("Notifications") {
                Toggle(isOn: notificationsToggleBinding) {
                    Label("Price target alerts", systemImage: "bell.badge")
                }

                HStack {
                    Label("Status", systemImage: "info.circle")
                    Spacer()
                    Text(pushNotificationsCoordinator.statusDescription)
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = pushNotificationsCoordinator.lastErrorMessage, !error.isEmpty {
                    Text(error)
                        .typography(.caption)
                        .foregroundStyle(AppTheme.Colors.danger)
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Appearance
            Section("Appearance") {
                Picker("Appearance", selection: appAppearanceBinding) {
                    ForEach(AppAppearance.allCases, id: \.self) { appearance in
                        Text(appearance.title)
                            .tag(appearance)
                    }
                }
                .pickerStyle(.segmented)

                Text(selectedAppearance.subtitle)
                    .typography(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Achievements
            Section("Achievements") {
                NavigationLink(value: UserProfileDestination.badges) {
                    Label("Badges", systemImage: "trophy.fill")
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Integrations
            Section("Integrations") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Connected Models")
                            .typography(.body)
                        Spacer()
                        Text("3 ACTIVE")
                            .typography(.nano, weight: .bold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(white: 0.2))
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 12) {
                        integrationPill("Claude")
                        integrationPill("ChatGPT")
                        integrationPill("Grok")
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // About
            Section("Support") {
                NavigationLink(value: UserProfileDestination.helpSupport) {
                    Label("Help & Support", systemImage: "questionmark.circle")
                }
                NavigationLink(value: UserProfileDestination.shareFeedback) {
                    Label("Share Feedback", systemImage: "quote.bubble")
                }
                NavigationLink(value: UserProfileDestination.about) {
                    Label("About Norviqa", systemImage: "info.circle")
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Connect
            Section("Connect") {
                if let discordURL = URL(string: "https://discord.gg/norviqa") {
                    Link(destination: discordURL) {
                        Label("Join Discord", systemImage: "bubble.left.and.bubble.right")
                    }
                    .foregroundStyle(.primary)
                }

                if let xURL = URL(string: "https://x.com/norviqa") {
                    Link(destination: xURL) {
                        Label("Follow on X", systemImage: "x.circle")
                    }
                    .foregroundStyle(.primary)
                }

                if let tiktokURL = URL(string: "https://tiktok.com/@norviqa") {
                    Link(destination: tiktokURL) {
                        Label("Follow on TikTok", systemImage: "music.note")
                    }
                    .foregroundStyle(.primary)
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Log Out
            Section {
                Button(role: .destructive) {
                    Task {
                        guard !isLoggingOut else { return }
                        isLoggingOut = true
                        await Container.shared.authSessionManager().logout()
                        isLoggingOut = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isLoggingOut {
                            ProgressView()
                        }
                        Text("Log out")
                            .typography(.button, weight: .semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(AppTheme.Colors.danger)
                }
                .disabled(isLoggingOut)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Footer
            Section {
                Text("NORVIQA V2.4.1 (BUILD 108)")
                    .typography(.nano)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
    }

    private var appAppearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { AppAppearance.from(appAppearanceRawValue) },
            set: { appAppearanceRawValue = $0.rawValue }
        )
    }

    private var selectedAppearance: AppAppearance {
        AppAppearance.from(appAppearanceRawValue)
    }

    private var notificationsToggleBinding: Binding<Bool> {
        Binding(
            get: { pushNotificationsCoordinator.isOptedIn },
            set: { enabled in
                Task {
                    await pushNotificationsCoordinator.setNotificationsEnabled(enabled)
                }
            }
        )
    }

    // MARK: - Components

    private func iconView(_ systemName: String, backgroundColor: Color, foregroundColor: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .frame(width: 28, height: 28)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func integrationPill(_ name: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.green)
                .frame(width: 6, height: 6)
            Text(name)
                .font(.footnote)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.15))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func avatarView(_ profile: UserProfile?) -> some View {
        ZStack {
            if let url = profile?.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarPlaceholder(profile)
                    }
                }
            } else {
                avatarPlaceholder(profile)
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(Circle())
    }

    private func avatarPlaceholder(_ profile: UserProfile?) -> some View {
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

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func placeholderInitial(for profile: UserProfile?) -> String {
        guard let profile else { return "?" }
        let seed =
            normalized(profile.username)
            ?? normalized(profile.email)
            ?? "?"
        return String(seed.prefix(1)).uppercased()
    }
}
