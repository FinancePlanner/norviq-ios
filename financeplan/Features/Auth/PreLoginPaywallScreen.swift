import Factory
import RevenueCat
import SwiftUI

struct PreLoginPaywallScreen: View {
  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @InjectedObservable(\Container.billingManager) private var billingManager

  var onContinue: () -> Void

  @State private var featuresAppeared = false

  var body: some View {
    ZStack {
      MeshGradientBackground()

      ScrollView {
        VStack(spacing: 24) {
          PaywallHeroSection(
            headline: "Unlock your\nfinancial potential",
            subtitle: "Get full clarity on your net worth and make better decisions with Pro."
          )

          featuresList

          planCards

          PaywallCTAFooter(
            ctaTitle: billingManager.purchaseCTATitle,
            isLoading: billingManager.isPurchasing,
            isDisabled: !billingManager.canPurchaseSelectedPackage,
            onPurchase: {
              Task {
                let success = await billingManager.purchaseSelectedPackage()
                if success { onContinue() }
              }
            },
            skipTitle: "Continue with Free",
            onSkip: onContinue,
            onRestore: {
              Task { await billingManager.restorePurchases() }
            },
            isRestoring: billingManager.isRestoring,
            errorMessage: billingManager.errorMessage,
            restoreStatusMessage: billingManager.restoreStatusMessage,
            restoreStatusIsSuccess: billingManager.restoreStatusIsSuccess,
            disclosureText: billingManager.subscriptionDisclosureText,
            isSticky: false
          )

          PaywallTrustStrip(showsTrialChargeMessage: billingManager.selectedPlanHasFreeTrial)

          AuthFooter()
        }
        .padding(.horizontal, 20)
        .padding(.top, 40)
        .padding(.bottom, 16)
      }
    }
    .task {
      await billingManager.loadOfferings()
    }
  }

  // MARK: - Features

  private var featuresList: some View {
    GlassCard(cornerRadius: 20) {
      VStack(spacing: 16) {
        ForEach(Array(PreLoginPaywallScreen.features.enumerated()), id: \.element.title) { index, feature in
          featureRow(feature: feature)
            .opacity(featuresAppeared ? 1 : 0)
            .offset(y: featuresAppeared ? 0 : 12)
            .animation(
              reduceMotion
                ? .easeOut(duration: 0.15)
                : .spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.08),
              value: featuresAppeared
            )
        }
      }
    }
    .onAppear { featuresAppeared = true }
  }

  private func featureRow(feature: FeatureInfo) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Image(systemName: feature.icon)
        .font(.title2)
        .foregroundStyle(
          feature.isPro
            ? AppTheme.Colors.secondaryTint(for: scheme)
            : .secondary
        )
        .frame(width: 32)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(feature.title)
            .font(.subheadline.weight(.semibold))
          if feature.isPro {
            Text("PRO")
              .font(.caption.weight(.bold))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(
                AppTheme.Colors.premiumGradient(for: scheme),
                in: Capsule()
              )
              .foregroundStyle(.white)
          }
        }
        Text(feature.subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  // MARK: - Plan Cards

  private var planCards: some View {
    VStack(spacing: 12) {
      if let package = billingManager.annualPackage {
        PaywallPlanCard(
          title: "Annual",
          subtitle: "7-day free trial",
          price: package.localizedPriceString,
          priceUnit: "/yr",
          badge: "Save 2 months",
          isSelected: billingManager.selectedProductID == BillingManager.annualProductID,
          onSelect: { billingManager.select(productID: BillingManager.annualProductID) }
        )
      }

      if let package = billingManager.monthlyPackage {
        PaywallPlanCard(
          title: "Monthly",
          subtitle: "Cancel anytime",
          price: package.localizedPriceString,
          priceUnit: "/mo",
          isSelected: billingManager.selectedProductID == "pro_monthly",
          onSelect: { billingManager.select(productID: "pro_monthly") }
        )
      }

      if let package = billingManager.weeklyPackage {
        PaywallPlanCard(
          title: "Weekly",
          subtitle: "Short term",
          price: package.localizedPriceString,
          priceUnit: "/wk",
          isSelected: billingManager.selectedProductID == "pro_weekly",
          onSelect: { billingManager.select(productID: "pro_weekly") }
        )
      }
    }
  }

  // MARK: - Feature Data

  private struct FeatureInfo: Hashable {
    let icon: String
    let title: String
    let subtitle: String
    let isPro: Bool
  }

  private static let features: [FeatureInfo] = [
    FeatureInfo(icon: "chart.line.uptrend.xyaxis", title: "Unlimited Syncing", subtitle: "Connect all your brokers for real-time updates.", isPro: true),
    FeatureInfo(icon: "waveform.path.ecg", title: "Advanced Projections", subtitle: "See where your money is going years ahead.", isPro: true),
    FeatureInfo(icon: "bolt.fill", title: "Real-time Market Data", subtitle: "Instant quotes without delays.", isPro: true),
    FeatureInfo(icon: "lock.shield", title: "Basic Portfolio", subtitle: "Track your main assets manually.", isPro: false),
  ]
}
