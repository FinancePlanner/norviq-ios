//
//  UserProfileView.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import Factory
import PostHog
import StockPlanShared
import StoreKit
import SwiftUI

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
    @State private var viewModel: UserProfileViewModel
    @State private var accountLinkingViewModel: AccountLinkingViewModel
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
    @State private var isDeletingAccount = false
    @State private var isDeleteAccountConfirmPresented = false
    @State private var deleteAccountErrorMessage: String?
    @State private var securityCodeEnabled = false
    @State private var faceIDErrorMessage: String?
    @State private var isNotificationsOn = false
    @State private var isEarningsAlertsOn = false

    // Appearance State
    @AppStorage(AppAppearance.storageKey) private var appAppearanceRawValue = AppAppearance.system
        .rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english
        .rawValue

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
        _viewModel = State(initialValue: viewModel ?? UserProfileViewModel())
        _accountLinkingViewModel = State(initialValue: AccountLinkingViewModel())
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
                .onReceive(pushNotificationsCoordinator.$isOptedIn) { isNotificationsOn = $0 }
                .onReceive(pushNotificationsCoordinator.$earningsAlertsEnabled) { isEarningsAlertsOn = $0 }
                .alert(
                    "Face ID",
                    isPresented: Binding(
                        get: { faceIDErrorMessage != nil },
                        set: { if !$0 { faceIDErrorMessage = nil } }
                    )
                ) {
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
                        Task { await billingManager.manageSubscription() }
                    } label: {
                        Label(
                            LocalizedStringKey("Manage Subscription"),
                            systemImage: "creditcard.fill")
                    }
                } else {
                    Button {
                        // PostHog: Track upgrade to Pro button tap
                        PostHogSDK.shared.capture(
                            "upgrade_to_pro_tapped",
                            properties: [
                                "source": "settings"
                            ])
                        PostHogSDK.shared.capture(
                            "paywall_viewed",
                            properties: [
                                "source": "settings_upgrade"
                            ])
                        isPaywallPresented = true
                    } label: {
                        Label(LocalizedStringKey("Upgrade to Pro"), systemImage: "sparkles")
                    }
                }

                Button {
                    restorePurchases()
                } label: {
                    HStack {
                        Label(
                            LocalizedStringKey("Restore Purchases"), systemImage: "arrow.clockwise")
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
                            .accessibilityIdentifier(
                                billingManager.isPro
                                    ? "settings.subscription.pro" : "settings.subscription.free")
                    }
                }

                if let message = billingManager.errorMessage, !message.isEmpty {
                    Text(message)
                        .typography(.caption)
                        .foregroundStyle(AppTheme.Colors.danger)
                }

                if let message = billingManager.restoreStatusMessage, !message.isEmpty {
                    Label(
                        message,
                        systemImage: billingManager.restoreStatusIsSuccess ? "checkmark.circle.fill" : "info.circle")
                        .typography(.caption)
                        .foregroundStyle(
                            billingManager.restoreStatusIsSuccess
                                ? AppTheme.Colors.success
                                : AppTheme.Colors.tint(for: scheme))
                        .accessibilityIdentifier("settings.subscription.restoreStatus")
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
                    updateFaceID(enabled)
                }

                NavigationLink(value: UserProfileDestination.securityCode) {
                    HStack {
                        Label(LocalizedStringKey("Security Code"), systemImage: "lock.fill")
                        Spacer()
                        Text(
                            securityCodeEnabled
                                ? LocalizedStringKey("On") : LocalizedStringKey("Off")
                        )
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                ForEach([OAuthProviderKind.apple, .google, .x], id: \.self) { provider in
                    connectedAccountRow(provider)
                }

                if accountLinkingViewModel.isLoading {
                    HStack {
                        ProgressView()
                        Text(LocalizedStringKey("Loading connected accounts..."))
                            .typography(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let message = accountLinkingViewModel.successMessage, !message.isEmpty {
                    Label(message, systemImage: "checkmark.circle.fill")
                        .typography(.caption)
                        .foregroundStyle(.green)
                }

                if let message = accountLinkingViewModel.errorMessage, !message.isEmpty {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .typography(.caption)
                        .foregroundStyle(AppTheme.Colors.danger)
                }
            }
            .listRowBackground(AppTheme.Colors.elevatedCardBackground(for: scheme))

            Section(LocalizedStringKey("Alerts")) {
                Toggle(isOn: $isNotificationsOn) {
                    Label(LocalizedStringKey("Push notifications"), systemImage: "bell.badge")
                }
                .onChange(of: isNotificationsOn) { _, enabled in
                    updateNotifications(enabled)
                }

                Toggle(isOn: $isEarningsAlertsOn) {
                    Label(LocalizedStringKey("Earnings reminders"), systemImage: "calendar.badge.clock")
                }
                .disabled(!pushNotificationsCoordinator.isOptedIn || pushNotificationsCoordinator.isEarningsAlertsLoading)
                .onChange(of: isEarningsAlertsOn) { _, enabled in
                    updateEarningsAlerts(enabled)
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
                        enableNotifications()
                    } label: {
                        Label(LocalizedStringKey("Open Notification Settings"), systemImage: "gear")
                    }
                } else if pushNotificationsCoordinator.authorizationStatus == .notDetermined {
                    Button {
                        enableNotifications()
                    } label: {
                        Label(LocalizedStringKey("Enable Notification Alerts"), systemImage: "bell")
                    }
                }

                if let error = pushNotificationsCoordinator.lastErrorMessage, !error.isEmpty {
                    Text(error)
                        .typography(.caption)
                        .foregroundStyle(AppTheme.Colors.danger)
                }

                if let error = pushNotificationsCoordinator.earningsAlertsErrorMessage, !error.isEmpty {
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
                if let mailURL = URL(string: "mailto:fernandocorreia316@gmail.com") {
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
                ShareLink(
                    item: ShareURLBuilder.app(),
                    subject: Text("Norviqa"),
                    message: Text("Plan, track, and understand your investments with Norviqa."),
                    preview: SharePreview(
                        "Norviqa — your portfolio companion",
                        image: Image(systemName: "chart.line.uptrend.xyaxis")
                    )
                ) {
                    Label("Share App", systemImage: "square.and.arrow.up")
                        .foregroundStyle(.primary)
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
                    logOut()
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

            // Delete Account
            Section {
                Button(role: .destructive) {
                    isDeleteAccountConfirmPresented = true
                } label: {
                    HStack(spacing: 8) {
                        if isDeletingAccount {
                            ProgressView()
                        }
                        Text(LocalizedStringKey("Delete account"))
                            .typography(.button, weight: .semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(AppTheme.Colors.danger)
                }
                .disabled(isDeletingAccount || isLoggingOut)
            } footer: {
                Text(LocalizedStringKey(
                    "Permanently deletes your account and all associated data. This can't be undone."
                ))
                .typography(.nano)
                .foregroundStyle(.secondary)
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
            await accountLinkingViewModel.load()
        }
        .confirmationDialog(
            LocalizedStringKey("Delete account?"),
            isPresented: $isDeleteAccountConfirmPresented,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                deleteAccount()
            } label: {
                Text(LocalizedStringKey("Delete account"))
            }
            Button(role: .cancel) {} label: {
                Text(LocalizedStringKey("Cancel"))
            }
        } message: {
            Text(LocalizedStringKey(
                "This permanently deletes your account and all associated data. This can't be undone."
            ))
        }
        .alert(
            LocalizedStringKey("Couldn't delete account"),
            isPresented: Binding(
                get: { deleteAccountErrorMessage != nil },
                set: { if !$0 { deleteAccountErrorMessage = nil } }
            )
        ) {
            Button(role: .cancel) {} label: { Text(LocalizedStringKey("OK")) }
        } message: {
            Text(deleteAccountErrorMessage ?? "")
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
        await accountLinkingViewModel.load()
        pushNotificationsCoordinator.handleAuthenticatedSessionBecameActive()
        securityCodeEnabled = securityCodeManager.isEnabled
        isNotificationsOn = pushNotificationsCoordinator.isOptedIn
        isEarningsAlertsOn = pushNotificationsCoordinator.earningsAlertsEnabled
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

    private func iconView(_ systemName: String, backgroundColor: Color, foregroundColor: Color)
        -> some View
    {
        Image(systemName: systemName)
            .typography(.small, weight: .semibold)
            .foregroundStyle(foregroundColor)
            .frame(width: 28, height: 28)
            .background(backgroundColor)
            .clipShape(.rect(cornerRadius: 6))
    }

    private func connectedAccountRow(_ provider: OAuthProviderKind) -> some View {
        let account = accountLinkingViewModel.account(for: provider)
        let isActive = accountLinkingViewModel.activeProvider == provider

        return HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(accountLinkingViewModel.label(for: provider))
                        .foregroundStyle(.primary)
                    if account.connected, let email = account.email, !email.isEmpty {
                        Text(email)
                            .typography(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(LocalizedStringKey("Not connected"))
                            .typography(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: signInProviderIcon(for: provider))
            }

            Spacer()

            if account.connected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel(LocalizedStringKey("Connected"))
            } else {
                Button {
                    connectSignInProvider(provider)
                } label: {
                    if isActive {
                        ProgressView()
                    } else {
                        Text(LocalizedStringKey("Connect"))
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isActive || accountLinkingViewModel.activeProvider != nil)
            }
        }
        .accessibilityIdentifier("settings.connectedAccount.\(provider.rawValue)")
    }

    private func signInProviderIcon(for provider: OAuthProviderKind) -> String {
        switch provider {
        case .apple:
            return "apple.logo"
        case .google:
            return "g.circle"
        case .x:
            return "xmark"
        @unknown default:
            return "person.crop.circle.badge.checkmark"
        }
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
            faceIDErrorMessage =
                "Face ID is not available. Set up Face ID or a device passcode in iOS Settings first."
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

    // MARK: - Private async actions

    private func restorePurchases() {
        Task { await billingManager.restorePurchases() }
    }

    private func updateFaceID(_ enabled: Bool) {
        Task { await setFaceIDEnabled(enabled) }
    }

    private func updateNotifications(_ enabled: Bool) {
        Task { await pushNotificationsCoordinator.setNotificationsEnabled(enabled) }
    }

    private func updateEarningsAlerts(_ enabled: Bool) {
        Task { await pushNotificationsCoordinator.setEarningsAlertsEnabled(enabled) }
    }

    private func enableNotifications() {
        Task { await pushNotificationsCoordinator.setNotificationsEnabled(true) }
    }

    private func connectSignInProvider(_ provider: OAuthProviderKind) {
        Task { await accountLinkingViewModel.connect(provider) }
    }

    private func logOut() {
        Task {
            guard !isLoggingOut else { return }
            isLoggingOut = true
            // PostHog: Track logout before resetting the session
            PostHogSDK.shared.capture("user_logged_out")
            PostHogSDK.shared.reset()
            await Container.shared.authSessionManager().logout()
            isLoggingOut = false
        }
    }

    private func deleteAccount() {
        Task {
            guard !isDeletingAccount else { return }
            isDeletingAccount = true
            defer { isDeletingAccount = false }

            let success = await viewModel.deleteAccount()
            guard success else {
                deleteAccountErrorMessage = viewModel.errorMessage
                    ?? String(localized: "Failed to delete account.")
                return
            }

            // Account removed server-side: tear down the local session so the
            // app returns to the signed-out state.
            PostHogSDK.shared.capture("user_account_deleted")
            PostHogSDK.shared.reset()
            await Container.shared.authSessionManager().logout()
        }
    }
}
