import Factory
import RevenueCat
import SwiftUI

/// Screen 13 — paywall reusing existing `BillingManager` / RevenueCat wiring.
/// Soft-gated: "Continue with limited Norviq" link below the trial CTA matches the
/// pattern in `PreLoginPaywallScreen`.
struct OnboardingQuestionnairePaywallScreen: View {
  let onCompleted: (_ purchased: Bool) -> Void

  @InjectedObservable(\Container.billingManager) private var billingManager
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var featuresAppeared = false

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        logoBlock
        headlineBlock
        testimonialCard
        featuresCard
        planCards

        OnboardingPrimaryButton(
          title: billingManager.purchaseCTATitle,
          isEnabled: billingManager.canPurchaseSelectedPackage,
          isLoading: billingManager.isPurchasing,
          action: {
            Task {
              let success = await billingManager.purchaseSelectedPackage()
              if success { onCompleted(true) }
            }
          }
        )

        Text(billingManager.subscriptionDisclosureText)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)

        secondaryLinks

        PaywallTrustStrip(showsTrialChargeMessage: billingManager.selectedPlanHasFreeTrial)
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)
      .padding(.bottom, 24)
    }
    .task {
      await billingManager.loadOfferings()
    }
    .sensoryFeedback(.success, trigger: billingManager.isPro) { _, newValue in
      newValue
    }
    .overlay(alignment: .top) {
      if let error = billingManager.errorMessage {
        ToastBanner(message: error, style: .error)
          .padding(.horizontal, 16)
          .padding(.top, 8)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
  }

  // MARK: - Logo

  private var logoBlock: some View {
    NorviqFullLogo(width: 190)
  }

  // MARK: - Headline

  private var headlineBlock: some View {
    VStack(spacing: 8) {
      Text("Your full financial picture, locked in.")
        .font(.title.bold())
        .multilineTextAlignment(.center)

      Text(billingManager.selectedPlanHasFreeTrial ? "7 days free. Cancel anytime." : "Cancel anytime.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - Testimonial
  // TODO: replace placeholder testimonial with real beta-user review before App Store submission.

  private var testimonialCard: some View {
    GlassCard(cornerRadius: 18) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 4) {
          ForEach(0..<5, id: \.self) { _ in
            Image(systemName: "star.fill")
              .font(.caption)
              .foregroundStyle(AppTheme.Colors.warning)
          }
        }
        .accessibilityLabel("5 stars")

        Text("\u{201C}Found $200/month I didn't know I was wasting. Paid for itself in week one.\u{201D}")
          .font(.subheadline.weight(.medium))
          .fixedSize(horizontal: false, vertical: true)

        Text("— Marcus R. · Saver-investor")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.vertical, 4)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - Features

  private var featuresCard: some View {
    GlassCard(cornerRadius: 20) {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(Array(OnboardingQuestionnairePaywallScreen.features.enumerated()), id: \.element.title) { index, feature in
          HStack(spacing: 12) {
            Image(systemName: feature.icon)
              .font(.body.weight(.semibold))
              .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme))
              .frame(width: 24)
              .accessibilityHidden(true)
            Text(feature.title)
              .font(.subheadline.weight(.medium))
              .fixedSize(horizontal: false, vertical: true)
          }
          .opacity(featuresAppeared ? 1 : 0)
          .offset(y: featuresAppeared ? 0 : 10)
          .animation(
            reduceMotion
              ? .easeOut(duration: 0.15)
              : .spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.06),
            value: featuresAppeared
          )
          .accessibilityElement(children: .combine)
        }
      }
      .padding(.vertical, 4)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .onAppear { featuresAppeared = true }
  }

  // MARK: - Plan Cards

  private var planCards: some View {
    VStack(spacing: 10) {
      if let package = billingManager.annualPackage {
        PaywallPlanCard(
          title: "Annual",
          subtitle: "7-day free trial",
          price: package.localizedPriceString,
          priceUnit: "/yr",
          badge: "Save 2 months",
          isSelected: billingManager.selectedProductID == "pro_annual",
          onSelect: { billingManager.select(productID: "pro_annual") }
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

  // MARK: - Secondary Links

  private var secondaryLinks: some View {
    VStack(spacing: 14) {
      Button {
        Task { await billingManager.restorePurchases() }
      } label: {
        HStack(spacing: 6) {
          if billingManager.isRestoring {
            ProgressView().scaleEffect(0.7)
          }
          Text("Restore purchases")
            .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.secondary)
      }

      Button {
        onCompleted(false)
      } label: {
        Text("Continue with limited Norviq")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary.opacity(0.8))
      }

      HStack(spacing: 16) {
        Link("Privacy Policy", destination: Constants.Norviq.privacyPolicyUrl)
        Text("•").foregroundStyle(.tertiary)
        Link("Terms of Use", destination: Constants.Norviq.termsOfUseUrl)
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  // MARK: - Feature Data

  private struct FeatureInfo: Hashable {
    let icon: String
    let title: String
  }

  private static let features: [FeatureInfo] = [
    FeatureInfo(icon: "chart.line.uptrend.xyaxis", title: "Unlimited holdings, watchlists & alerts"),
    FeatureInfo(icon: "creditcard.fill", title: "Auto-categorised expense tracking"),
    FeatureInfo(icon: "chart.xyaxis.line", title: "10-year projections on every position"),
    FeatureInfo(icon: "scale.3d", title: "Allocation visuals & concentration alerts"),
    FeatureInfo(icon: "icloud.and.arrow.up", title: "Live syncing across devices"),
  ]
}
