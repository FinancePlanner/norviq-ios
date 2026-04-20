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
    case language
    case dataHandling
    case sensitiveActions
}

@MainActor
public struct UserProfileView: View {
    @StateObject private var viewModel: UserProfileViewModel
    @StateObject private var pushNotificationsCoordinator: PushNotificationsCoordinator
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var path: [UserProfileDestination] = []
    @State private var isEditPresented = false
    @State private var isLoggingOut = false
    @State private var securityCodeEnabled = false
    @State private var faceIDErrorMessage: String?

    // Appearance State
    @AppStorage(AppAppearance.storageKey) private var appAppearanceRawValue = AppAppearance.system.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue

    // Security State
    @AppStorage("useFaceID") private var useFaceID: Bool = true
    private var appLockManager: AppLockManaging { Container.shared.appLockManager() }
    private var securityCodeManager: SecurityCodeManaging { Container.shared.securityCodeManager() }

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
                securityCodeEnabled = securityCodeManager.isEnabled
            }
            .alert("Face ID", isPresented: faceIDAlertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(faceIDErrorMessage ?? "")
            }
            .sheet(isPresented: $isEditPresented) {
                if let profile = viewModel.profile {
                    EditProfileView(viewModel: viewModel, profile: profile)
                }
            }
            .navigationDestination(for: UserProfileDestination.self) { destination in
                switch destination {
                case .securityCode:
                    SecurityCodeView(
                        manager: securityCodeManager,
                        isEnabled: $securityCodeEnabled
                    )
                case .badges:
                    BadgesView()
                case .helpSupport:
                    HelpSupportView()
                case .shareFeedback:
                    ShareFeedbackView()
                case .about:
                    AboutNorviqaView()
                case .language:
                    LanguageSettingsView()
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
                            .typography(.small, weight: .semibold)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Security
            Section("Security") {
                Toggle(isOn: faceIDToggleBinding) {
                    HStack(spacing: 12) {
                        Label("Face ID", systemImage: "faceid")
                    }
                }

                NavigationLink(value: UserProfileDestination.securityCode) {
                    HStack {
                        Label("Security Code", systemImage: "lock.fill")
                        Spacer()
                        Text(securityCodeEnabled ? LocalizedStringKey("On") : LocalizedStringKey("Off"))
                            .typography(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            Section("Alerts") {
                Toggle(isOn: notificationsToggleBinding) {
                    Label("Price target alerts", systemImage: "bell.badge")
                }

                HStack(spacing: 12) {
                    Label("Notification Status", systemImage: "info.circle")
                    Spacer()
                    Text(pushNotificationsCoordinator.statusDescription)
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                }

                if pushNotificationsCoordinator.authorizationStatus == .denied {
                    Button {
                        Task { await pushNotificationsCoordinator.setNotificationsEnabled(true) }
                    } label: {
                        Label("Open Notification Settings", systemImage: "gear")
                    }
                } else if pushNotificationsCoordinator.authorizationStatus == .notDetermined {
                    Button {
                        Task { await pushNotificationsCoordinator.setNotificationsEnabled(true) }
                    } label: {
                        Label("Enable Notification Alerts", systemImage: "bell")
                    }
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

            // Language
            Section("Language") {
                NavigationLink(value: UserProfileDestination.language) {
                    HStack {
                        Label("Language", systemImage: "globe")
                        Spacer()
                        Text(selectedLanguage.displayName)
                            .typography(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Achievements
            Section("Achievements") {
                NavigationLink(value: UserProfileDestination.badges) {
                    Label("Badges", systemImage: "trophy.fill")
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Integrations (Coming Soon)
            Section("Integrations") {
                HStack {
                    Label("AI Model Integrations", systemImage: "cpu")
                    Spacer()
                    Text("Soon")
                        .typography(.nano, weight: .bold).fontDesign(.rounded)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                }
                .opacity(0.6)
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
                Menu {
                    socialButton("Follow on Instagram", systemImage: "camera", url: "https://instagram.com/norviqa")
                    socialButton("Follow on X", systemImage: "x.circle", url: "https://x.com/norviqa")
                    socialButton("Follow on TikTok", systemImage: "music.note", url: "https://tiktok.com/@norviqa")
                    socialButton("Join Discord", systemImage: "bubble.left.and.bubble.right", url: "https://discord.gg/norviqa")
                } label: {
                    HStack {
                        Label("Connect", systemImage: "link.circle")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("Instagram, X, TikTok, Discord")
                            .typography(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
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
                Text(versionString)
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

    private var selectedLanguage: AppLanguage {
        AppLanguage.from(appLanguageRawValue)
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

    private var faceIDToggleBinding: Binding<Bool> {
        Binding(
            get: { useFaceID },
            set: { enabled in
                Task { await setFaceIDEnabled(enabled) }
            }
        )
    }

    private var faceIDAlertBinding: Binding<Bool> {
        Binding(
            get: { faceIDErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    faceIDErrorMessage = nil
                }
            }
        )
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "NORVIQA V\(version) (BUILD \(build))"
    }

    // MARK: - Components

    private func iconView(_ systemName: String, backgroundColor: Color, foregroundColor: Color) -> some View {
        Image(systemName: systemName)
            .typography(.small, weight: .semibold)
            .foregroundStyle(foregroundColor)
            .frame(width: 28, height: 28)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func socialButton(_ title: LocalizedStringKey, systemImage: String, url: String) -> some View {
        if let destination = URL(string: url) {
            Button {
                openURL(destination)
            } label: {
                Label(title, systemImage: systemImage)
            }
        }
    }

    private func setFaceIDEnabled(_ enabled: Bool) async {
        if !enabled {
            useFaceID = false
            return
        }

        let result = await appLockManager.authenticateDevice(
            localizedReason: "Enable Face ID to unlock Norviqa"
        )

        switch result {
        case .authenticated:
            useFaceID = true
        case .failed:
            useFaceID = false
            faceIDErrorMessage = "Face ID was not enabled because authentication did not complete."
        case .unavailable:
            useFaceID = false
            faceIDErrorMessage = "Face ID is not available. Set up Face ID or a device passcode in iOS Settings first."
        }
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

private struct SecurityCodeView: View {
    let manager: SecurityCodeManaging
    @Binding var isEnabled: Bool
    @Environment(\.colorScheme) private var scheme

    @State private var setupCode = ""
    @State private var setupConfirmation = ""
    @State private var currentCode = ""
    @State private var replacementCode = ""
    @State private var replacementConfirmation = ""
    @State private var removalCode = ""
    @State private var message: String?
    @State private var isErrorMessage = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    let title: LocalizedStringKey = isEnabled ? "Security Code is enabled" : "Security Code is off"
                    Label(title, systemImage: isEnabled ? "lock.shield.fill" : "lock.open.fill")
                    .typography(.label, weight: .semibold)

                    Text("Use a 6-digit code to unlock Norviqa when Face ID or device passcode is unavailable.")
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            if isEnabled {
                changeSection
                removeSection
            } else {
                setupSection
            }

            if let message {
                Section {
                    Text(message)
                        .typography(.caption)
                        .foregroundStyle(isErrorMessage ? AppTheme.Colors.danger : AppTheme.Colors.success)
                }
                .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .navigationTitle("Security Code")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isEnabled = manager.isEnabled
        }
    }

    private var setupSection: some View {
        Section {
            codeField("New 6-digit code", text: $setupCode)
            codeField("Confirm code", text: $setupConfirmation)

            Button {
                setCode()
            } label: {
                Label("Turn On Security Code", systemImage: "lock.fill")
            }
            .disabled(setupCode.count != 6 || setupConfirmation.count != 6)
        } header: {
            Text("Set Up")
        }
        .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
    }

    private var changeSection: some View {
        Section {
            codeField("Current code", text: $currentCode)
            codeField("New 6-digit code", text: $replacementCode)
            codeField("Confirm new code", text: $replacementConfirmation)

            Button {
                changeCode()
            } label: {
                Label("Change Security Code", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(currentCode.count != 6 || replacementCode.count != 6 || replacementConfirmation.count != 6)
        } header: {
            Text("Change")
        }
        .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
    }

    private var removeSection: some View {
        Section {
            codeField("Current code", text: $removalCode)

            Button(role: .destructive) {
                removeCode()
            } label: {
                Label("Turn Off Security Code", systemImage: "lock.slash")
            }
            .disabled(removalCode.count != 6)
        } header: {
            Text("Remove")
        }
        .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
    }

    private func codeField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .font(.body.monospacedDigit())
            .onChange(of: text.wrappedValue) { _, newValue in
                text.wrappedValue = String(newValue.filter(\.isNumber).prefix(6))
            }
    }

    private func setCode() {
        guard setupCode == setupConfirmation else {
            show("Security Code confirmation does not match.", isError: true)
            return
        }

        do {
            try manager.setCode(setupCode)
            setupCode = ""
            setupConfirmation = ""
            isEnabled = true
            show("Security Code is enabled.", isError: false)
        } catch {
            show(errorMessage(for: error), isError: true)
        }
    }

    private func changeCode() {
        guard replacementCode == replacementConfirmation else {
            show("New Security Code confirmation does not match.", isError: true)
            return
        }

        do {
            try manager.changeCode(currentCode: currentCode, newCode: replacementCode)
            currentCode = ""
            replacementCode = ""
            replacementConfirmation = ""
            isEnabled = true
            show("Security Code was changed.", isError: false)
        } catch {
            show(errorMessage(for: error), isError: true)
        }
    }

    private func removeCode() {
        do {
            try manager.removeCode(currentCode: removalCode)
            removalCode = ""
            isEnabled = false
            show("Security Code is off.", isError: false)
        } catch {
            show(errorMessage(for: error), isError: true)
        }
    }

    private func show(_ value: String, isError: Bool) {
        message = value
        isErrorMessage = isError
    }

    private func errorMessage(for error: any Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Unable to update Security Code."
    }
}
