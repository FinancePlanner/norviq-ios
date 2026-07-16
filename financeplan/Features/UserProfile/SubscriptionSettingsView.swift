import Factory
import RevenueCat
import StockPlanShared
import SwiftUI

struct SubscriptionSettingsView: View {
    @Environment(\.colorScheme) private var scheme
    @InjectedObservable(\Container.billingManager) private var billingManager
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statusCard
                changePlanSection
                actionsSection
                retentionNote
            }
            .padding()
        }
        .background(AppTheme.Colors.pageBackground(for: scheme))
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(billingManager.isPurchasing || billingManager.isRestoring)
        .sheet(isPresented: $showPaywall) {
            PaywallView(billingManager: billingManager)
        }
        .task {
            await billingManager.refreshBillingContext()
            await billingManager.loadOfferings()
        }
    }

    private var statusCard: some View {
        VStack(spacing: 12) {
            if billingManager.isPro {
                Label(
                    billingManager.isCancelledButActive ? "Pro Active Until Period End" : "Pro Active",
                    systemImage: billingManager.isCancelledButActive ? "calendar.badge.clock" : "checkmark.seal.fill"
                )
                .font(.title2).fontWeight(.bold)
                .foregroundStyle(billingManager.isCancelledButActive ? AppTheme.Colors.tint(for: scheme) : .green)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("subscription.status.pro")

                Text(billingManager.currentPlanDisplayName)
                    .typography(.body, weight: .semibold)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("subscription.planName")

                if let days = billingManager.trialDaysRemaining, days > 0 {
                    Text("Trial watch ends in \(days) day\(days == 1 ? "" : "s").")
                        .typography(.body)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("subscription.status.trial")
                }
                if let pendingPlan = billingManager.pendingPlanDisplayName {
                    Text("Scheduled change: \(pendingPlan)\(dateSuffix(billingManager.pendingPlanEffectiveAt))")
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if billingManager.isCancelledButActive {
                    Text("Canceled. Pro access continues\(untilSuffix(billingManager.subscriptionAccessEndsAt)).")
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else if let renewsAt = billingManager.subscriptionRenewsOrExpiresAt {
                    Text("Renews or expires \(formattedDate(renewsAt))")
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                }
                if billingManager.hasBillingIssue {
                    Label("There is a billing issue on your subscription.", systemImage: "exclamationmark.triangle.fill")
                        .typography(.caption)
                        .foregroundStyle(AppTheme.Colors.danger)
                        .multilineTextAlignment(.leading)
                }
            } else {
                Label("Free Plan", systemImage: "star")
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("subscription.status.free")
                Text("Upgrade to Pro to unlock all features.")
                    .typography(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.elevatedCardBackground(for: scheme), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityIdentifier("subscription.statusCard")
    }

    @ViewBuilder
    private var changePlanSection: some View {
        if billingManager.isPro, !billingManager.availableUpgradePlanOptions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Change plan")
                    .typography(.headline, weight: .semibold)
                Text("Switch to a longer billing interval when you want a lower effective price. Downgrades and cancellation are handled from subscription management.")
                    .typography(.caption)
                    .foregroundStyle(.secondary)
                ForEach(billingManager.availableUpgradePlanOptions, id: \.productId) { option in
                    upgradeOptionRow(option)
                }
            }
            .padding(16)
            .background(AppTheme.Colors.elevatedCardBackground(for: scheme), in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func upgradeOptionRow(_ option: BillingPlanOptionDTO) -> some View {
        Button {
            billingManager.select(productID: option.productId)
            Task { await billingManager.purchaseSelectedPackage() }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(option.displayName)
                            .typography(.body, weight: .semibold)
                        if let badge = option.badge, !badge.isEmpty {
                            Text(badge)
                                .typography(.caption, weight: .semibold)
                                .foregroundStyle(AppTheme.Colors.tint(for: scheme))
                        }
                    }
                    Text(upgradeSubtitle(for: option))
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(billingManager.isPurchasing || package(for: option.productId) == nil)
        .accessibilityIdentifier("subscription.upgrade.\(option.productId)")
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if billingManager.isPro {
                Button {
                    Task { await billingManager.manageSubscription() }
                } label: {
                    Label("Manage or Cancel Subscription", systemImage: "ellipsis.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.tint(for: scheme))
            } else {
                Button {
                    showPaywall = true
                } label: {
                    Label("Upgrade to Pro", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                Task { await billingManager.restorePurchases() }
            } label: {
                HStack(spacing: 8) {
                    if billingManager.isRestoring {
                        ProgressView()
                    }
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(billingManager.isRestoring || billingManager.isPurchasing)

            restoreStatusMessage
            billingErrorMessage
        }
    }

    private var retentionNote: some View {
        Text("Your data is retained even if you cancel. Resubscribe anytime to restore full access.")
            .typography(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var restoreStatusMessage: some View {
        if let message = billingManager.restoreStatusMessage, !message.isEmpty {
            Label(
                message,
                systemImage: billingManager.restoreStatusIsSuccess ? "checkmark.circle.fill" : "info.circle")
                .font(.caption)
                .foregroundStyle(
                    billingManager.restoreStatusIsSuccess
                        ? AppTheme.Colors.success
                        : AppTheme.Colors.tint(for: scheme))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("subscription.restoreStatus")
        }
    }

    @ViewBuilder
    private var billingErrorMessage: some View {
        if let message = billingManager.errorMessage, !message.isEmpty {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.danger)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("subscription.error")
        }
    }

    private func upgradeSubtitle(for option: BillingPlanOptionDTO) -> String {
        if let package = package(for: option.productId) {
            return "\(package.storeProduct.localizedPriceString) · \(option.interval.capitalized)"
        }
        return "Available in subscription management"
    }

    private func package(for productID: String) -> RevenueCat.Package? {
        billingManager.packages.first { $0.storeProduct.productIdentifier == productID }
    }

    private func dateSuffix(_ date: Date?) -> String {
        guard let date else { return "" }
        return " on \(formattedDate(date))"
    }

    private func untilSuffix(_ date: Date?) -> String {
        guard let date else { return "" }
        return " until \(formattedDate(date))"
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview {
    SubscriptionSettingsView()
}
