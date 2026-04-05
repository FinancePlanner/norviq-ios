//
//  UserProfileView.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import StockPlanShared
import SwiftUI
import Factory

@MainActor
public struct UserProfileView: View {
    @StateObject private var viewModel: UserProfileViewModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    // Appearance State
    @AppStorage("appAppearance") private var appAppearance: String = "System"
    
    // Security State
    @AppStorage("useFaceID") private var useFaceID: Bool = true
    
    public init(viewModel: UserProfileViewModel = UserProfileViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    settingsList(profile: viewModel.profile)
                }
            }
            .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
            }
            .task { await viewModel.load() }
        }
    }

    private func settingsList(profile: UserProfile?) -> some View {
        List {
            // Profile Card
            Section {
                NavigationLink(destination: ProfileDetailView(viewModel: viewModel, profile: profile)) {
                    HStack(spacing: 16) {
                        avatarView(profile)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fullName(for: profile) ?? "User")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                            Text("View and edit your account")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
            
            // Security
            Section("SECURITY") {
                Toggle(isOn: $useFaceID) {
                    HStack(spacing: 12) {
                        iconView("faceid", backgroundColor: Color(red: 0.15, green: 0.25, blue: 0.35), foregroundColor: .blue)
                        Text("Face ID")
                    }
                }
                
                NavigationLink(destination: Text("Security Code")) {
                    HStack(spacing: 12) {
                        iconView("lock.fill", backgroundColor: Color(red: 0.15, green: 0.25, blue: 0.35), foregroundColor: .blue)
                        Text("Security Code")
                    }
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Appearance
            Section("APPEARANCE") {
                Picker("Appearance", selection: $appAppearance) {
                    Text("System").tag("System")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .padding(.horizontal, 4)
            }
            
            // Integrations
            Section("INTEGRATIONS") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Connected Models")
                            .font(.body)
                        Spacer()
                        Text("3 ACTIVE")
                            .font(.caption2.bold())
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
            Section("ABOUT") {
                NavigationLink(destination: Text("Help & Support")) {
                    Text("Help & Support")
                }
                NavigationLink(destination: Text("Share Feedback")) {
                    Text("Share Feedback")
                }
                NavigationLink(destination: Text("About Aurelius Finance")) {
                    Text("About Aurelius Finance")
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
            
            // Log Out
            Section {
                Button(action: {
                    Task {
                        await Container.shared.authSessionManager().logout()
                    }
                }) {
                    Text("Log out")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color(red: 0.8, green: 0.4, blue: 0.4))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
            
            // Footer
            Section {
                Text("AURELIUS FINANCE V2.4.1 (BUILD 108)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
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

    private func fullName(for profile: UserProfile?) -> String? {
        guard let profile else { return nil }
        let parts = [normalized(profile.firstName), normalized(profile.lastName)].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    private func placeholderInitial(for profile: UserProfile?) -> String {
        guard let profile else { return "?" }
        let seed =
            normalized(profile.username)
            ?? normalized(profile.firstName)
            ?? normalized(profile.lastName)
            ?? normalized(profile.email)
            ?? "?"
        return String(seed.prefix(1)).uppercased()
    }
}

// MARK: - Profile Detail View

public struct ProfileDetailView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    let profile: UserProfile?
    @Environment(\.colorScheme) private var scheme
    
    @State private var isEditPresented = false
    @State private var biometricUnlock = true

    public var body: some View {
        List {
            // Avatar Section
            Section {
                VStack(spacing: 12) {
                    avatarView(profile)
                    
                    Button("Change Photo") {
                        isEditPresented = true
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            
            // Profile Info Section
            Section {
                infoRow(title: "First Name", value: normalized(profile?.firstName) ?? "")
                infoRow(title: "Last Name", value: normalized(profile?.lastName) ?? "")
                infoRow(title: "Username", value: formattedUsername(for: profile) ?? "")
                infoRow(title: "Email", value: profile?.email ?? "")
            } footer: {
                Text("Your email is used for account security and transactional alerts.")
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
            
            // Privacy & Protection
            Section("PRIVACY & PROTECTION") {
                Toggle(isOn: $biometricUnlock) {
                    HStack(spacing: 12) {
                        iconView("faceid", backgroundColor: Color(red: 0.15, green: 0.25, blue: 0.35), foregroundColor: .blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Biometric Unlock")
                            Text("FaceID active for all vault access")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                NavigationLink(destination: Text("Data handling")) {
                    HStack(spacing: 12) {
                        iconView("shield.fill", backgroundColor: Color(red: 0.35, green: 0.15, blue: 0.15), foregroundColor: .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Data handling")
                            Text("Manage how your metadata is processed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                NavigationLink(destination: Text("Sensitive actions")) {
                    HStack(spacing: 12) {
                        iconView("lock.rotation", backgroundColor: Color(white: 0.25), foregroundColor: .white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sensitive actions")
                            Text("Step-up authentication for large trades")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.blue)
                    Text("Your personal information is encrypted and stored in a decentralized hardware enclave. No one at the Vault can access your private identifiers or transaction history.")
                }
                .padding(.top, 8)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
            
            // Close Account
            Section {
                Button(action: {
                    // Close account action
                }) {
                    Text("Close Account")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color(red: 0.8, green: 0.4, blue: 0.4))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    isEditPresented = true
                }
            }
        }
        .sheet(isPresented: $isEditPresented) {
            if let profile = profile {
                EditProfileView(viewModel: viewModel, profile: profile)
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
    }

    private func iconView(_ systemName: String, backgroundColor: Color, foregroundColor: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .frame(width: 28, height: 28)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
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
        .frame(width: 96, height: 96)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppTheme.Colors.pageBackground(for: scheme), lineWidth: 4))
    }
    
    private func avatarPlaceholder(_ profile: UserProfile?) -> some View {
        LinearGradient(
            colors: AppTheme.avatarGradient(for: scheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(placeholderInitial(for: profile))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
        )
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func formattedUsername(for profile: UserProfile?) -> String? {
        guard let username = normalized(profile?.username) else { return nil }
        return "@\(username)"
    }

    private func placeholderInitial(for profile: UserProfile?) -> String {
        guard let profile else { return "?" }
        let seed =
            normalized(profile.username)
            ?? normalized(profile.firstName)
            ?? normalized(profile.lastName)
            ?? normalized(profile.email)
            ?? "?"
        return String(seed.prefix(1)).uppercased()
    }
}
