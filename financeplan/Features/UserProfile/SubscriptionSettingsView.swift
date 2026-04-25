import Factory
import SwiftUI
import RevenueCat

struct SubscriptionSettingsView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
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
                    if let days = billingManager.trialDaysRemaining, days > 0 {
                        Text("Trial: \(days) day\(days == 1 ? "" : "s") remaining")
                            .typography(.body)
                            .foregroundStyle(.secondary)
                    }
                    Text(currentPlanName)
                        .typography(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Free Plan", systemImage: "star")
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    Text("Upgrade to Pro to unlock all features.")
                        .typography(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.elevatedCardBackground(for: scheme), in: RoundedRectangle(cornerRadius: 20))

            // Actions
            VStack(spacing: 12) {
                if billingManager.isPro {
                    Button {
                        openManageSubscriptions()
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
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(billingManager.isRestoring || billingManager.isPurchasing)
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

    private var currentPlanName: String {
        switch billingManager.selectedProductID {
        case Constants.annualProductID: "Annual Plan"
        case Constants.monthlyProductID: "Monthly Plan"
        case Constants.weeklyProductID: "Weekly Plan"
        default: "Pro"
        }
    }

    private func openManageSubscriptions() {
        let urlString: String
        if scheme == .dark {
            urlString = "https://apps.apple.com/account/subscriptions"
        } else {
            urlString = "https://apps.apple.com/account/subscriptions"
        }
        if let url = URL(string: urlString) {
            openURL(url)
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
