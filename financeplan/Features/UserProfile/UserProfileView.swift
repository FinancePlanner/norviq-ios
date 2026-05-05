//
//  UserProfileView.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import PostHog
import StockPlanShared
import StoreKit
import SwiftUI
import Factory

private enum UserProfileDestination: Hashable {
    case securityCode
    case badges
    case shareFeedback
    case about
    case language
    case dataHandling
    case dataAvailability
    case connect
    case sensitiveActions
    case subscription
}

@MainActor
public struct UserProfileView: View {
    @StateObject private var viewModel: UserProfileViewModel
    @StateObject private var pushNotificationsCoordinator: PushNotificationsCoordinator
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @InjectedObservable(\Container.appEnvironment) private var environmentManager
    @InjectedObservable(\Container.billingManager) private var billingManager
    @State private var path: [UserProfileDestination] = []
    @State private var isEditPresented = false
    @State private var isAIInfoPresented = false
    @State private var isPaywallPresented = false
    @State private var isLoggingOut = false
    @State private var securityCodeEnabled = false
    @State private var faceIDErrorMessage: String?
    @State private var isNotificationsOn = false

    // Appearance State
    @AppStorage(AppAppearance.storageKey) private var appAppearanceRawValue = AppAppearance.system.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue

    // Security State
    @AppStorage("useFaceID") private var useFaceID: Bool = true
    private var appLockManager: AppLockManaging { Container.shared.appLockManager() }
    private var securityCodeManager: SecurityCodeManaging { Container.shared.securityCodeManager() }

    private var isShowingLoadingState: Bool {
        viewModel.isLoading && viewModel.profile == nil
    }

    private var loadErrorMessage: String? {
        guard viewModel.profile == nil else { return nil }
        return viewModel.errorMessage
    }

    public init(viewModel: UserProfileViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? UserProfileViewModel())
        _pushNotificationsCoordinator = StateObject(
            wrappedValue: Container.shared.pushNotificationsCoordinator()
        )
    }

    public var body: some View {
        NavigationStack(path: $path) {
            rootContent
            .id(appLanguage.rawValue)
            .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
            .navigationTitle(LocalizedStringKey("Settings"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.tint(for: scheme))
                }
            }
            .task {
                await initialLoad()
            }
            .alert("Face ID", isPresented: Binding(
                get: { faceIDErrorMessage != nil },
                set: { if !$0 { faceIDErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(faceIDErrorMessage ?? "")
            }
            .sheet(isPresented: $isEditPresented) {
                editProfileSheet
            }
            .sheet(isPresented: $isAIInfoPresented) {
                AIModelIntegrationsInfoSheet()
            }
            .sheet(isPresented: $isPaywallPresented) {
                PaywallView(billingManager: billingManager)
            }
            .navigationDestination(for: UserProfileDestination.self) { destination in
                destinationView(for: destination)
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if isShowingLoadingState {
            ProgressView(LocalizedStringKey("Loading..."))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if let loadErrorMessage {
            ErrorRetryView(message: loadErrorMessage, onRetry: retryLoad)
        } else {
            settingsList(profile: viewModel.profile)
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
                            Text(profile?.username ?? String(localized: "Unknown User"))
                                .typography(.label, weight: .semibold)
                                .foregroundStyle(.primary)
                            Text(LocalizedStringKey("View and edit your account"))
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

            Section(LocalizedStringKey("Subscription")) {
                if billingManager.isPro {
                    Button {
                        billingManager.manageSubscription()
                    } label: {
                        Label(LocalizedStringKey("Manage Subscription"), systemImage: "creditcard.fill")
                    }
                } else {
                    Button {
                        // PostHog: Track upgrade to Pro button tap
                        PostHogSDK.shared.capture("upgrade_to_pro_tapped", properties: [
                            "source": "settings",
                        ])
                        PostHogSDK.shared.capture("paywall_viewed", properties: [
                            "source": "settings_upgrade",
                        ])
                        isPaywallPresented = true
                    } label: {
                        Label(LocalizedStringKey("Upgrade to Pro"), systemImage: "sparkles")
                    }
                }

                Button {
                    Task { await billingManager.restorePurchases() }
                } label: {
                    HStack {
                        Label(LocalizedStringKey("Restore Purchases"), systemImage: "arrow.clockwise")
                        Spacer()
                        if billingManager.isRestoring {
                            ProgressView()
                        }
                    }
                }
                .disabled(billingManager.isRestoring)

                if let days = billingManager.trialDaysRemaining {
                    Label("Trial: \(days) days remaining", systemImage: "calendar.badge.clock")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.subscription.trial")
                } else {
                    HStack {
                        Label(LocalizedStringKey("Status"), systemImage: "checkmark.seal")
                        Spacer()
                        Text(billingManager.isPro ? "Pro" : "Free")
                            .typography(.caption, weight: .semibold)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier(billingManager.isPro ? "settings.subscription.pro" : "settings.subscription.free")
                    }
                }

                if let message = billingManager.errorMessage, !message.isEmpty {
                    Text(message)
                        .typography(.caption)
                        .foregroundStyle(AppTheme.Colors.danger)
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Security
            Section(LocalizedStringKey("Security")) {
                Toggle(isOn: $useFaceID) {
                    HStack(spacing: 12) {
                        Label(LocalizedStringKey("Face ID"), systemImage: "faceid")
                    }
                }
                .onChange(of: useFaceID) { _, enabled in
                    Task { await setFaceIDEnabled(enabled) }
                }

                NavigationLink(value: UserProfileDestination.securityCode) {
                    HStack {
                        Label(LocalizedStringKey("Security Code"), systemImage: "lock.fill")
                        Spacer()
                        Text(securityCodeEnabled ? LocalizedStringKey("On") : LocalizedStringKey("Off"))
                            .typography(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            Section(LocalizedStringKey("Alerts")) {
                Toggle(isOn: $isNotificationsOn) {
                    Label(LocalizedStringKey("Price target alerts"), systemImage: "bell.badge")
                }
                .onChange(of: isNotificationsOn) { _, enabled in
                    Task { await pushNotificationsCoordinator.setNotificationsEnabled(enabled) }
                }

                HStack(spacing: 12) {
                    Label(LocalizedStringKey("Notification Status"), systemImage: "info.circle")
                    Spacer()
                    Text(pushNotificationsCoordinator.statusDescription)
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                }

                if pushNotificationsCoordinator.authorizationStatus == .denied {
                    Button {
                        Task { await pushNotificationsCoordinator.setNotificationsEnabled(true) }
                    } label: {
                        Label(LocalizedStringKey("Open Notification Settings"), systemImage: "gear")
                    }
                } else if pushNotificationsCoordinator.authorizationStatus == .notDetermined {
                    Button {
                        Task { await pushNotificationsCoordinator.setNotificationsEnabled(true) }
                    } label: {
                        Label(LocalizedStringKey("Enable Notification Alerts"), systemImage: "bell")
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
            Section(LocalizedStringKey("Appearance")) {
                Picker(LocalizedStringKey("Appearance"), selection: $appAppearanceRawValue) {
                    ForEach(AppAppearance.allCases, id: \.self) { appearance in
                        Text(appearance.title)
                            .tag(appearance.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text(selectedAppearance.subtitle)
                    .typography(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Language
            Section(LocalizedStringKey("Language")) {
                NavigationLink(value: UserProfileDestination.language) {
                    HStack {
                        Label(LocalizedStringKey("Language"), systemImage: "globe")
                        Spacer()
                        Text(appLanguage.displayName)
                            .typography(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Achievements
            Section(LocalizedStringKey("Achievements")) {
                NavigationLink(value: UserProfileDestination.badges) {
                    Label(LocalizedStringKey("Badges"), systemImage: "trophy.fill")
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Integrations (Coming Soon)
            Section(LocalizedStringKey("Integrations")) {
                HStack {
                    Label(LocalizedStringKey("AI Model Integrations"), systemImage: "cpu")
                        .opacity(0.6)
                    Spacer()
                    Text(LocalizedStringKey("Soon"))
                        .typography(.nano, weight: .bold).fontDesign(.rounded)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                    Button {
                        isAIInfoPresented = true
                    } label: {
                        Image(systemName: "info.circle")
                            .imageScale(.large)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.Colors.tint(for: scheme))
                    .accessibilityLabel("Why connect AI models?")
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Subscription
            Section(LocalizedStringKey("Subscription")) {
                NavigationLink(value: UserProfileDestination.subscription) {
                    HStack {
                        Label(LocalizedStringKey("Subscription"), systemImage: "star.fill")
                        Spacer()
                        if billingManager.isPro {
                            Text("Pro")
                                .typography(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("Free")
                                .typography(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Support
            Section(LocalizedStringKey("Support")) {
                if let mailURL = URL(string: "mailto:support@norviqa.com") {
                    Link(destination: mailURL) {
                        Label("Contact Developer", systemImage: "envelope.fill")
                            .foregroundStyle(.primary)
                    }
                }
                Button {
                    requestReview()
                } label: {
                    Label("Rate on App Store", systemImage: "star.fill")
                        .foregroundStyle(.primary)
                }
                if let appStoreURL = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID") {
                    ShareLink(item: appStoreURL) {
                        Label("Share App", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.primary)
                    }
                }
                NavigationLink(value: UserProfileDestination.dataAvailability) {
                    Label("Data Availability", systemImage: "chart.line.uptrend.xyaxis")
                }
                NavigationLink(value: UserProfileDestination.shareFeedback) {
                    Label(LocalizedStringKey("Share Feedback"), systemImage: "quote.bubble")
                }
                NavigationLink(value: UserProfileDestination.about) {
                    Label(LocalizedStringKey("About Norviq"), systemImage: "info.circle")
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            // Connect
            Section(LocalizedStringKey("Connect")) {
                NavigationLink(value: UserProfileDestination.connect) {
                    HStack {
                        Label(LocalizedStringKey("Connect"), systemImage: "link.circle")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("Instagram, X, TikTok, Discord")
                            .typography(.caption)
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
                        // PostHog: Track logout before resetting the session
                        PostHogSDK.shared.capture("user_logged_out")
                        PostHogSDK.shared.reset()
                        await Container.shared.authSessionManager().logout()
                        isLoggingOut = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isLoggingOut {
                            ProgressView()
                        }
                        Text(LocalizedStringKey("Log out"))
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
                VStack(spacing: 4) {
                    if environmentManager.current != AppEnvironments.production {
                        Text("Environment: \(environmentManager.current.title.capitalized) testing")
                    }
                    Text(versionString)
                }
                    .typography(.nano)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .refreshable {
            await viewModel.load(force: true)
        }
    }

    @ViewBuilder
    private var editProfileSheet: some View {
        if let profile = viewModel.profile {
            EditProfileView(viewModel: viewModel, profile: profile)
        }
    }

    @ViewBuilder
    private func destinationView(for destination: UserProfileDestination) -> some View {
        switch destination {
        case .securityCode:
            SecurityCodeView(
                manager: securityCodeManager,
                isEnabled: $securityCodeEnabled
            )
        case .badges:
            BadgesView()
        case .shareFeedback:
            ShareFeedbackView()
        case .about:
            AboutNorviqView()
        case .language:
            LanguageSettingsView()
        case .dataHandling:
            Text("Data handling")
        case .dataAvailability:
            DataAvailabilityView()
        case .connect:
            ConnectView()
        case .sensitiveActions:
            Text("Sensitive actions")
        case .subscription:
            SubscriptionSettingsView()
        }
    }

    private func initialLoad() async {
        billingManager.configureForCurrentUser()
        await billingManager.refreshBillingContext()
        await viewModel.load()
        pushNotificationsCoordinator.handleAuthenticatedSessionBecameActive()
        securityCodeEnabled = securityCodeManager.isEnabled
        isNotificationsOn = pushNotificationsCoordinator.isOptedIn
    }

    private func retryLoad() {
        Task { await viewModel.load(force: true) }
    }

    private var selectedAppearance: AppAppearance {
        AppAppearance.from(appAppearanceRawValue)
    }

    private var appLanguage: AppLanguage {
        AppLanguage.from(appLanguageRawValue)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "NORVIQ V\(version) (BUILD \(build))"
    }

    // MARK: - Components

    private func iconView(_ systemName: String, backgroundColor: Color, foregroundColor: Color) -> some View {
        Image(systemName: systemName)
            .typography(.small, weight: .semibold)
            .foregroundStyle(foregroundColor)
            .frame(width: 28, height: 28)
            .background(backgroundColor)
            .clipShape(.rect(cornerRadius: 6))
    }

    private func setFaceIDEnabled(_ enabled: Bool) async {
        if !enabled {
            useFaceID = false
            return
        }

        let result = await appLockManager.authenticateDevice(
            localizedReason: "Enable Face ID to unlock Norviq"
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
        .overlay {
            Text(placeholderInitial(for: profile))
                .font(.title2.bold())
                .foregroundStyle(.white)
        }
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

private struct AIModelIntegrationsInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Why connect an AI model?", systemImage: "sparkles")
                            .typography(.headline, weight: .semibold)

                        Text("Connect your AI tools so they can work with your Norviq data directly.")
                            .typography(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

                Section {
                    valueRow(
                        title: "Less manual work",
                        detail: "No exporting files, pasting raw data, or writing small scripts just to prepare a question.",
                        systemImage: "wand.and.stars"
                    )
                    valueRow(
                        title: "More reliable answers",
                        detail: "Your assistant can use current market and portfolio data instead of guessing from memory.",
                        systemImage: "checkmark.seal"
                    )
                    valueRow(
                        title: "Cleaner conversations",
                        detail: "Ask focused questions without pasting long API notes or large data responses.",
                        systemImage: "text.bubble"
                    )
                }
                .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
            .navigationTitle("AI Model Integrations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.tint(for: scheme))
                }
            }
        }
    }

    private func valueRow(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .typography(.label, weight: .semibold)
                .foregroundStyle(AppTheme.Colors.tint(for: scheme))
                .frame(width: 28, height: 28)
                .background(AppTheme.Colors.tint(for: scheme).opacity(0.12))
                .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .typography(.label, weight: .semibold)
                Text(detail)
                    .typography(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ConnectView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                socialButton(LocalizedStringKey("Follow on Instagram"), systemImage: "camera", url: "https://instagram.com/norviqa")
                socialButton(LocalizedStringKey("Follow on X"), systemImage: "x.circle", url: "https://x.com/norviqa")
                socialButton(LocalizedStringKey("Follow on TikTok"), systemImage: "music.note", url: "https://tiktok.com/@norviqa")
                socialButton(LocalizedStringKey("Join Discord"), systemImage: "bubble.left.and.bubble.right", url: "https://discord.gg/norviqa")
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .navigationTitle(LocalizedStringKey("Connect"))
        .navigationBarTitleDisplayMode(.inline)
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
}

private struct DataAvailabilityView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Market data coverage", systemImage: "chart.line.uptrend.xyaxis")
                        .typography(.label, weight: .semibold)

                    Text("Some analysis, statements, consensus, and forecast data depends on the market data coverage currently connected to Norviq.")
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            Section {
                coverageRow(
                    title: "Free data coverage",
                    detail: "Available for the supported symbol list below."
                )
                coverageRow(
                    title: "Starter data coverage",
                    detail: "Available for US exchanges."
                )
                coverageRow(
                    title: "Premium data coverage",
                    detail: "Available for US, UK, and Canada exchanges."
                )
            } header: {
                Text("Data Coverage")
            } footer: {
                Text("Market data coverage is separate from your Norviq subscription. If a data source does not cover a symbol or date range, the app keeps the rest of the stock page usable.")
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            Section("App Subscription Limits") {
                Text("Norviq subscription limits control app features such as portfolio capacity, imports, alerts, reports, and advanced research access.")
                    .typography(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            Section {
                DisclosureGroup("Supported symbols on current free data coverage") {
                    Text(FMPFreeTierCoverage.supportedSymbolsDisplay)
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.vertical, 6)
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
        .navigationTitle("Data Availability")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func coverageRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .typography(.label, weight: .semibold)
            Text(detail)
                .typography(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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

                    Text("Use a 6-digit code to unlock Norviq when Face ID or device passcode is unavailable.")
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
