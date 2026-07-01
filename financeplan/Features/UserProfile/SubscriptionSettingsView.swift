import Factory
import SwiftUI

struct SubscriptionSettingsView: View {
    @Environment(\.colorScheme) private var scheme
    @InjectedObservable(\Container.billingManager) private var billingManager
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 20) {
            // Status card
            VStack(spacing: 12) {
                if billingManager.isPro {
                    Label("Pro Active", systemImage: "checkmark.seal.fill")
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("subscription.status.pro")
                    if let days = billingManager.trialDaysRemaining, days > 0 {
                        Text("Trial: \(days) day\(days == 1 ? "" : "s") remaining")
                            .typography(.body)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("subscription.status.trial")
                    }
                    Text(currentPlanName)
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("subscription.planName")
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
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.elevatedCardBackground(for: scheme), in: RoundedRectangle(cornerRadius: 20))
            .accessibilityIdentifier("subscription.statusCard")

            // Actions
            VStack(spacing: 12) {
                if billingManager.isPro {
                    Button {
                        Task { await billingManager.manageSubscription() }
                    } label: {
                        Label("Manage Subscription", systemImage: "ellipsis.circle")
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

            Spacer()

            // Info
            VStack(spacing: 8) {
                Text("Your data is retained even if you cancel. Resubscribe anytime to restore full access.")
                    .typography(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .padding()
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(billingManager.isPurchasing || billingManager.isRestoring)
        .sheet(isPresented: $showPaywall) {
            PaywallView(billingManager: billingManager)
        }
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

    private var currentPlanName: String {
        switch billingManager.selectedProductID {
        case Constants.annualProductID: "Annual Plan"
        case Constants.monthlyProductID: "Monthly Plan"
        case Constants.weeklyProductID: "Weekly Plan"
        default: "Pro"
        }
    }

    private enum Constants {
        static let annualProductID = "pro_annual"
        static let monthlyProductID = "pro_monthly"
        static let weeklyProductID = "pro_weekly"
    }
}

#Preview {
    SubscriptionSettingsView()
}
