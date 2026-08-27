import Factory
import RevenueCat
import SwiftUI

struct PreLoginPaywallScreen: View {
  @InjectedObservable(\Container.billingManager) private var billingManager

  var onContinue: () -> Void

  var body: some View {
    ZStack {
      MeshGradientBackground()

      ScrollView {
        VStack(spacing: 24) {
          VigilPageHeader(
            watch: .auth("Pro vigil"),
            title: "Norviq Pro",
            subtitle: "Unlock research, bank sync, the assistant, tax, and advanced reports."
          )
          .frame(maxWidth: .infinity, alignment: .leading)

          PaywallComparisonTable()

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

  // MARK: - Plan Cards

  private var planCards: some View {
    VStack(spacing: 12) {
      if let package = billingManager.annualPackage {
        PaywallPlanCard(
          title: "Annual",
          subtitle: billingManager.annualPlanSubtitle,
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

}
