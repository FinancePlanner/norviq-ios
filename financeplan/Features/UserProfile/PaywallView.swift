import RevenueCat
import SwiftUI

@MainActor
struct PaywallView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let billingManager: BillingManager

  @State private var featuresAppeared = false

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        ScrollView {
          VStack(spacing: 0) {
            PaywallHeroSection(
              headline: "Unlock your\nfinancial potential",
              subtitle: "Get full clarity on your net worth and make better decisions with Pro."
            )
            .padding(.top, 32)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)

            featureList
              .padding(.horizontal, 20)
              .padding(.bottom, 28)

            planCards
              .padding(.horizontal, 20)
              .padding(.bottom, 16)

            PaywallTrustStrip()
              .padding(.horizontal, 20)
              .padding(.bottom, 120) // space for sticky CTA
          }
          .maxContentWidth(regularSizeClass: ContentWidth.marketing)
        }
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())

        PaywallCTAFooter(
          ctaTitle: "Start Free Trial",
          isLoading: billingManager.isPurchasing,
          onPurchase: {
            Task { await billingManager.purchaseSelectedPackage() }
          },
          onSkip: { dismiss() },
          onRestore: {
            Task { await billingManager.restorePurchases() }
          },
          isRestoring: billingManager.isRestoring,
          errorMessage: billingManager.errorMessage
        )
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Close", systemImage: "xmark") {
            dismiss()
          }
          .font(.body.weight(.semibold))
          .foregroundStyle(.secondary)
          .labelStyle(.iconOnly)
          .padding(8)
          .background(AppTheme.Colors.elevatedCardBackground(for: scheme), in: Circle())
        }
        ToolbarItem(placement: .principal) {
          Text("NORVIQ")
            .font(.caption.weight(.bold))
            .tracking(2)
            .foregroundStyle(.secondary)
        }
      }
      .task {
        await billingManager.loadOfferings()
      }
      .onChange(of: billingManager.isPro) { _, isPro in
        if isPro { dismiss() }
      }
      .sensoryFeedback(.success, trigger: billingManager.isPro) { _, newValue in
        newValue
      }
      .accessibilityIdentifier("PaywallView")
    }
  }

  // MARK: - Feature List

  private var featureList: some View {
    VStack(spacing: 12) {
      ForEach(Array(PaywallView.proFeatures.enumerated()), id: \.element.title) { index, feature in
        PaywallFeatureRow(icon: feature.icon, title: feature.title, badge: .pro)
          .opacity(featuresAppeared ? 1 : 0)
          .offset(y: featuresAppeared ? 0 : 16)
          .animation(
            reduceMotion
              ? .easeOut(duration: 0.15)
              : .spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.08),
            value: featuresAppeared
          )
      }
    }
    .onAppear {
      featuresAppeared = true
    }
  }

  // MARK: - Plan Cards

  private var planCards: some View {
    VStack(spacing: 12) {
      PaywallPlanCard(
        title: "Annual",
        subtitle: "7-day free trial",
        price: price(for: billingManager.annualPackage, fallback: "$49.99"),
        priceUnit: "/yr",
        badge: "Save 2 months",
        isSelected: billingManager.selectedProductID == "pro_annual",
        onSelect: { billingManager.select(productID: "pro_annual") }
      )

      PaywallPlanCard(
        title: "Monthly",
        subtitle: "Cancel anytime",
        price: price(for: billingManager.monthlyPackage, fallback: "$4.99"),
        priceUnit: "/mo",
        isSelected: billingManager.selectedProductID == "pro_monthly",
        onSelect: { billingManager.select(productID: "pro_monthly") }
      )

      PaywallPlanCard(
        title: "Weekly",
        subtitle: "Short term",
        price: price(for: billingManager.weeklyPackage, fallback: "$0.99"),
        priceUnit: "/wk",
        isSelected: billingManager.selectedProductID == "pro_weekly",
        onSelect: { billingManager.select(productID: "pro_weekly") }
      )
    }
  }

  // MARK: - Helpers

  private func price(for package: Package?, fallback: String) -> String {
    package?.storeProduct.localizedPriceString ?? fallback
  }

  // MARK: - Feature Data

  private struct FeatureInfo: Hashable {
    let icon: String
    let title: String
  }

  private static let proFeatures: [FeatureInfo] = [
    FeatureInfo(icon: "person.2.fill", title: "Cloud sync across devices"),
    FeatureInfo(icon: "chart.bar.fill", title: "Real fundamentals & financial statements"),
    FeatureInfo(icon: "bell.badge.fill", title: "Price, dividend & earnings alerts"),
    FeatureInfo(icon: "arrow.up.arrow.down", title: "Bear/base/bull projections"),
  ]
}
