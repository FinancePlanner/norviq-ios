import RevenueCat
import SwiftUI

@MainActor
struct PaywallView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var scheme
  @Environment(\.openURL) private var openURL
  let billingManager: BillingManager

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        ScrollView {
          VStack(spacing: 0) {
            hero
              .padding(.top, 32)
              .padding(.horizontal, 24)
              .padding(.bottom, 32)

            featureList
              .padding(.horizontal, 24)
              .padding(.bottom, 28)

            planCards
              .padding(.horizontal, 24)
              .padding(.bottom, 120) // space for sticky CTA
          }
        }
        .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())

        stickyFooter
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.body.weight(.semibold))
              .foregroundStyle(.secondary)
              .padding(8)
              .background(AppTheme.Colors.elevatedCardBackground(for: scheme), in: Circle())
          }
          .accessibilityLabel("Close")
        }
        ToolbarItem(placement: .principal) {
          Text("NORVIQA")
            .typography(.caption, weight: .bold)
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
      .accessibilityIdentifier("PaywallView")
  }
  }

  // MARK: - Hero

  private var hero: some View {
    ZStack {
      RadialGradient(
        colors: [AppTheme.Colors.tint(for: scheme).opacity(scheme == .dark ? 0.4 : 0.2), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 200
      )
      .frame(height: 250)
      .offset(y: -20)
      .blur(radius: 20)

      VStack(spacing: 16) {
        Text("Unlock your\nfinancial potential")
          .font(.largeTitle.weight(.heavy))
          .multilineTextAlignment(.center)
          .foregroundStyle(.primary)

        Text("Get full clarity on your net worth and make better decisions with Pro.")
          .typography(.body)
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 24)
      }
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Feature List

  private var featureList: some View {
    VStack(spacing: 12) {
      ForEach(Array(featureRows.filter { $0.tier == .pro }.prefix(4)), id: \.feature) { row in
        featureRow(row: row, scheme: scheme)
      }
    }
  }

  @ViewBuilder
  private func featureRow(row: FeatureRow, scheme: ColorScheme) -> some View {
    HStack(spacing: 16) {
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .fill(AppTheme.Colors.tintSoft(for: scheme).opacity(0.5))
          .frame(width: 44, height: 44)
        Image(systemName: row.icon)
          .font(.body.weight(.semibold))
          .foregroundStyle(AppTheme.Colors.tint(for: scheme))
          .accessibilityHidden(true)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(row.feature)
          .typography(.body, weight: .semibold)
          .foregroundStyle(.primary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Text("PRO")
        .typography(.nano, weight: .bold)
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(colors: [.blue, AppTheme.Colors.tint(for: scheme)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: Capsule()
        )
    }
    .padding(16)
    .background(AppTheme.Colors.cardBackground(for: scheme))
    .clipShape(.rect(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(scheme == .dark ? 0.08 : 0.0), lineWidth: 1)
    )
  }

  private struct FeatureRow {
    let icon: String
    let feature: String
    let tier: Tier // free | pro

    enum Tier: String {
      case free, pro
    }
  }

  private var featureRows: [FeatureRow] {
    [
      // MARK: Free (what you already have)
      FeatureRow(icon: "list.bullet", feature: "Unlimited holdings & watchlist", tier: .free),
      FeatureRow(icon: "chart.line.uptrend.xyaxis", feature: "Current price, news, charts", tier: .free),
      FeatureRow(icon: "note.text", feature: "Research notes & thesis tracking", tier: .free),
      FeatureRow(icon: "square.and.arrow.up", feature: "CSV import & text export", tier: .free),
      FeatureRow(icon: "clock.badge", feature: "End-of-day quotes", tier: .free),
      FeatureRow(icon: "dollarsign.circle", feature: "Basic P&L summary", tier: .free),
      FeatureRow(icon: "checkmark.circle.fill", feature: "Record expenses (local-only)", tier: .free),
      FeatureRow(icon: "calendar", feature: "3-month expense history", tier: .free),
      FeatureRow(icon: "chart.pie", feature: "Current month category breakdown", tier: .free),
      FeatureRow(icon: "target", feature: "Monthly salary & pillars setup", tier: .free),

      // MARK: Pro (upgrade unlocks)
      FeatureRow(icon: "person.2.fill", feature: "Cloud sync across devices", tier: .pro),
      FeatureRow(icon: "chart.bar.fill", feature: "Real fundamentals & financial statements", tier: .pro),
      FeatureRow(icon: "chart.line.uptrend.xyaxis", feature: "Risk analytics (beta, drawdown, correlation)", tier: .pro),
      FeatureRow(icon: "bell.badge.fill", feature: "Price, dividend & earnings alerts (up to 15)", tier: .pro),
      FeatureRow(icon: "doc.text.fill", feature: "Earnings transcripts & summaries", tier: .pro),
      FeatureRow(icon: "arrow.up.arrow.down", feature: "Bear/base/bull projections", tier: .pro),
      FeatureRow(icon: "square.stack.3d.up", feature: "3-stock metric comparison", tier: .pro),
      FeatureRow(icon: "tag.fill", feature: "Valuation tracking & fair value", tier: .pro),
      FeatureRow(icon: "chart.line.uptrend.xyaxis", feature: "Year-over-year expense trends", tier: .pro),
      FeatureRow(icon: "lightbulb.min.fill", feature: "Smart spending suggestions", tier: .pro),
      FeatureRow(icon: "person.2.fill", feature: "Household partner splits", tier: .pro),
      FeatureRow(icon: "arrow.triangle.2.circlepath", feature: "Recurring expense templates", tier: .pro),
      FeatureRow(icon: "chart.line.uptrend.xyaxis", feature: "Full reports & month comparisons", tier: .pro),
      FeatureRow(icon: "arrow.triangle.2.circlepath", feature: "Unlimited historical expense data", tier: .pro),
      FeatureRow(icon: "bitcoinsign.circle.fill", feature: "Crypto tracking & analytics (coming soon)", tier: .pro),

      // MARK: Premium (future)
    ]
  }


  // MARK: - Plan Cards

  private var planCards: some View {
    VStack(spacing: 12) {
      planCard(
        title: "Annual",
        subtitle: "7-day free trial",
        price: price(for: billingManager.annualPackage, fallback: "$49.99"),
        priceUnit: "/yr",
        priceDetail: nil,
        productID: "pro_annual",
        badge: "Save 2 months",
        isProminent: true
      )

      planCard(
        title: "Monthly",
        subtitle: "Cancel anytime",
        price: price(for: billingManager.monthlyPackage, fallback: "$4.99"),
        priceUnit: "/mo",
        priceDetail: nil,
        productID: "pro_monthly",
        badge: nil,
        isProminent: false
      )

      planCard(
        title: "Weekly",
        subtitle: "Short term",
        price: price(for: billingManager.weeklyPackage, fallback: "$0.99"),
        priceUnit: "/wk",
        priceDetail: nil,
        productID: "pro_weekly",
        badge: nil,
        isProminent: false
      )
    }
  }

  private func planCard(
    title: String,
    subtitle: String,
    price: String,
    priceUnit: String,
    priceDetail: String?,
    productID: String,
    badge: String?,
    isProminent: Bool
  ) -> some View {
    let selected = billingManager.selectedProductID == productID

    return Button {
      billingManager.select(productID: productID)
    } label: {
      ZStack(alignment: .topLeading) {
        HStack(spacing: 16) {
          // Radio button
          ZStack {
            Circle()
              .strokeBorder(selected ? AppTheme.Colors.tint(for: scheme) : AppTheme.Colors.separator(for: scheme), lineWidth: selected ? 0 : 1.5)
              .background(Circle().fill(selected ? AppTheme.Colors.tint(for: scheme) : Color.clear))
              .frame(width: 24, height: 24)
            if selected {
              Image(systemName: "checkmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
            }
          }

          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              Text(title)
                .typography(.body, weight: .semibold)
                .foregroundStyle(.primary)
              if let badge {
                Text(badge)
                  .typography(.nano, weight: .bold)
                  .foregroundStyle(.white)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(Color.green.opacity(0.9), in: Capsule())
              }
            }
            Text(subtitle)
              .typography(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer()

          VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 1) {
              Text(price)
                .typography(.body, weight: .semibold)
                .foregroundStyle(.primary)
              Text(priceUnit)
                .typography(.caption)
                .foregroundStyle(.secondary)
            }
            if let priceDetail {
              Text(priceDetail)
                .typography(.nano)
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
          selected
            ? AppTheme.Colors.tintSoft(for: scheme).opacity(0.3)
            : AppTheme.Colors.cardBackground(for: scheme),
          in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 16)
            .stroke(
              selected ? AppTheme.Colors.tint(for: scheme) : AppTheme.Colors.separator(for: scheme),
              lineWidth: selected ? 2 : 1
            )
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(title) plan, \(price)\(priceUnit)")
  }

  // MARK: - Sticky Footer

  private var stickyFooter: some View {
    VStack(spacing: 0) {
      // Fade gradient
      LinearGradient(
        colors: [AppTheme.Colors.pageBackground(for: scheme).opacity(0), AppTheme.Colors.pageBackground(for: scheme)],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 24)

      VStack(spacing: 12) {
        Button {
          Task { await billingManager.purchaseSelectedPackage() }
        } label: {
          HStack(spacing: 10) {
            if billingManager.isPurchasing {
              ProgressView().tint(.white)
            }
            Text(billingManager.isPurchasing ? "Purchasing..." : "Start Free Trial")
              .font(.headline.weight(.semibold))
              .frame(maxWidth: .infinity)
          }
          .padding(.vertical, 16)
          .background(AppTheme.Colors.tint(for: scheme), in: Capsule())
          .foregroundStyle(.white)
          .shadow(color: AppTheme.Colors.tint(for: scheme).opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(billingManager.isPurchasing || billingManager.selectedPackage == nil)

        Button("Continue with Free") {
          dismiss()
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.top, 4)

        if let message = billingManager.errorMessage, !message.isEmpty {
          Text(message)
            .typography(.caption)
            .foregroundStyle(AppTheme.Colors.danger)
            .multilineTextAlignment(.center)
        }

        HStack(spacing: 16) {
          Button("Restore Purchases") {
            Task { await billingManager.restorePurchases() }
          }
          Text("•").foregroundStyle(.tertiary)
          Button("Terms") {
            openURL(URL(string: "https://norviqa.com/terms")!)
          }
          Text("•").foregroundStyle(.tertiary)
          Button("Privacy Policy") {
            openURL(URL(string: "https://norviqa.com/privacy")!)
          }
        }
        .typography(.nano)
        .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 32)
      .padding(.top, 8)
      .background(AppTheme.Colors.pageBackground(for: scheme))
    }
  }

  private func price(for package: Package?, fallback: String) -> String {
    package?.storeProduct.localizedPriceString ?? fallback
  }
}
