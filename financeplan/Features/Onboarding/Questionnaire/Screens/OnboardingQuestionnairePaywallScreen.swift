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

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        logoBlock
        headlineBlock
        testimonialCard
        featuresCard
        packageSelector
        primaryCTA
        secondaryLinks
        trustStrip
        finePrint
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)
      .padding(.bottom, 24)
    }
    .task {
      await billingManager.loadOfferings()
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
    VStack(spacing: 8) {
      NorviqLogo(size: 56)
    }
  }

  // MARK: - Headline

  private var headlineBlock: some View {
    VStack(spacing: 8) {
      Text("Your full financial picture, locked in.")
        .typography(.title, weight: .bold)
        .multilineTextAlignment(.center)

      Text("7 days free. Cancel anytime.")
        .typography(.label)
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
              .font(.caption2)
              .foregroundStyle(AppTheme.Colors.warning)
          }
        }

        Text("\u{201C}Found $200/month I didn't know I was wasting. Paid for itself in week one.\u{201D}")
          .typography(.small, weight: .medium)
          .fixedSize(horizontal: false, vertical: true)

        Text("— Marcus R. · Saver-investor")
          .typography(.nano)
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
        feature(icon: "chart.line.uptrend.xyaxis", text: "Unlimited holdings, watchlists & alerts")
        feature(icon: "creditcard.fill", text: "Auto-categorised expense tracking")
        feature(icon: "chart.xyaxis.line", text: "10-year projections on every position")
        feature(icon: "scale.3d", text: "Allocation visuals & concentration alerts")
        feature(icon: "icloud.and.arrow.up", text: "Live syncing across devices")
      }
      .padding(.vertical, 4)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func feature(icon: String, text: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.body.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
        .frame(width: 24)
      Text(text)
        .typography(.small, weight: .medium)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  // MARK: - Package selector

  private var packageSelector: some View {
    VStack(spacing: 10) {
      planRow(
        title: "Annual",
        subtitle: "7-day free trial",
        price: price(for: billingManager.annualPackage, fallback: "$49.99/yr"),
        productID: "pro_annual",
        badge: "Save 2 months"
      )
      planRow(
        title: "Monthly",
        subtitle: "Cancel anytime",
        price: price(for: billingManager.monthlyPackage, fallback: "$4.99/mo"),
        productID: "pro_monthly",
        badge: nil
      )
      planRow(
        title: "Weekly",
        subtitle: "Short term",
        price: price(for: billingManager.weeklyPackage, fallback: "$0.99/wk"),
        productID: "pro_weekly",
        badge: nil
      )
    }
  }

  private func planRow(title: String, subtitle: String, price: String, productID: String, badge: String?) -> some View {
    let selected = billingManager.selectedProductID == productID
    return Button {
      billingManager.select(productID: productID)
    } label: {
      HStack(spacing: 14) {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
          .imageScale(.large)
          .foregroundStyle(selected ? AppTheme.Colors.tint(for: colorScheme) : .secondary)

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Text(title)
              .typography(.label, weight: .bold)
            if let badge {
              Text(badge)
                .typography(.nano, weight: .bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(AppTheme.Colors.success, in: Capsule())
            }
          }
          Text(subtitle)
            .typography(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Text(price)
          .typography(.label, weight: .semibold)
      }
      .padding(16)
      .background(AppTheme.Colors.elevatedCardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .stroke(selected ? AppTheme.Colors.tint(for: colorScheme) : .clear, lineWidth: 2)
      }
    }
    .buttonStyle(PressEffectStyle())
  }

  // MARK: - Primary CTA

  private var primaryCTA: some View {
    OnboardingPrimaryButton(
      title: "Start my 7-day free trial",
      isLoading: billingManager.isPurchasing,
      action: {
        Task {
          let success = await billingManager.purchaseSelectedPackage()
          if success {
            onCompleted(true)
          }
        }
      }
    )
  }

  // MARK: - Secondary links

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
            .typography(.small, weight: .semibold)
        }
        .foregroundStyle(.secondary)
      }

      Button {
        onCompleted(false)
      } label: {
        Text("Continue with limited Norviq")
          .typography(.caption, weight: .medium)
          .foregroundStyle(.secondary.opacity(0.8))
      }
    }
  }

  // MARK: - Trust + fine print

  private var trustStrip: some View {
    HStack(spacing: 14) {
      trustItem(icon: "lock.shield.fill", text: "Bank-level encryption")
      trustItem(icon: "clock.fill", text: "Cancel anytime")
      trustItem(icon: "creditcard.fill", text: "Charged after trial")
    }
    .padding(.top, 4)
  }

  private func trustItem(icon: String, text: String) -> some View {
    VStack(spacing: 4) {
      Image(systemName: icon)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(text)
        .typography(.nano)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
  }

  private var finePrint: some View {
    Text("We'll remind you 3 days before billing.")
      .typography(.nano)
      .foregroundStyle(.secondary.opacity(0.7))
      .multilineTextAlignment(.center)
      .padding(.top, 4)
  }

  // MARK: - Helpers

  private func price(for package: Package?, fallback: String) -> String {
    package?.localizedPriceString ?? fallback
  }
}
