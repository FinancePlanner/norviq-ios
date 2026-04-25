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
    }
  }

  // MARK: - Hero

  private var hero: some View {
    VStack(spacing: 16) {
      // Logo
      ZStack {
        Circle()
          .fill(AppTheme.Colors.tintSoft(for: scheme))
          .frame(width: 80, height: 80)
        Image(scheme == .dark ? "NorviqaLogo" : "NorviqaLogoLight")
          .resizable()
          .scaledToFit()
          .frame(width: 52, height: 52)
      }

      VStack(spacing: 10) {
        Text("Unlock Norviqa Pro")
          .typography(.heading, weight: .bold)
          .multilineTextAlignment(.center)
          .foregroundStyle(.primary)

        Text("Get unlimited tracking, cloud sync, and deep portfolio insights.")
          .typography(.body)
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Feature List

  private var featureList: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Pro Features")
        .typography(.label, weight: .bold)
        .foregroundStyle(.primary)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)

      ForEach(Array(featureRows.enumerated()), id: \.element.feature) { index, row in
        HStack(spacing: 14) {
          ZStack {
            Circle()
              .fill(AppTheme.Colors.tintSoft(for: scheme))
              .frame(width: 36, height: 36)
            Image(systemName: row.icon)
              .font(.caption.weight(.medium))
              .symbolRenderingMode(.hierarchical)
              .foregroundStyle(AppTheme.Colors.tint(for: scheme))
          }

          Text(row.feature)
            .typography(.body)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)

          // Free column
          Image(systemName: "xmark")
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tertiaryFill(for: scheme).opacity(3))
            .frame(width: 28)

          // Pro column
          Image(systemName: "checkmark.circle.fill")
            .font(.body)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(AppTheme.Colors.tint(for: scheme))
            .frame(width: 28)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)

        if index < featureRows.count - 1 {
          Rectangle()
            .fill(AppTheme.Colors.separator(for: scheme))
            .frame(height: 0.5)
            .padding(.leading, 70)
        }
      }

      Spacer(minLength: 20)
    }
    .background(AppTheme.Colors.cardBackground(for: scheme), in: RoundedRectangle(cornerRadius: 20))
  }

  private struct FeatureRow {
    let icon: String
    let feature: String
  }

  private var featureRows: [FeatureRow] {
    [
      FeatureRow(icon: "arrow.triangle.2.circlepath", feature: "Broker auto-sync"),
      FeatureRow(icon: "person.2.fill", feature: "Cloud sync across devices"),
      FeatureRow(icon: "chart.bar.fill", feature: "Real fundamentals and projections"),
      FeatureRow(icon: "chart.line.uptrend.xyaxis", feature: "Risk analytics and comparisons"),
      FeatureRow(icon: "bell.badge.fill", feature: "Advanced alerts and exports"),
    ]
  }

  // MARK: - Plan Cards

  private var planCards: some View {
    VStack(spacing: 12) {
      planCard(
        title: "Yearly",
        subtitle: "Save 33%",
        price: price(for: billingManager.annualPackage, fallback: "$79.99"),
        priceUnit: "/yr",
        priceDetail: "Billed annually",
        productID: "pro_annual",
        badge: "BEST VALUE",
        isProminent: true
      )

      planCard(
        title: "Monthly",
        subtitle: "Flexible billing",
        price: price(for: billingManager.monthlyPackage, fallback: "$9.99"),
        priceUnit: "/mo",
        priceDetail: nil,
        productID: "pro_monthly",
        badge: nil,
        isProminent: false
      )

      planCard(
        title: "Weekly",
        subtitle: "Short-term access",
        price: price(for: billingManager.weeklyPackage, fallback: "$2.99"),
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
        HStack(spacing: 0) {
          VStack(alignment: .leading, spacing: 4) {
            Text(title)
              .typography(.label, weight: .bold)
              .foregroundStyle(.primary)
            Text(subtitle)
              .typography(.caption)
              .foregroundStyle(isProminent ? AppTheme.Colors.tint(for: scheme) : .secondary)
          }

          Spacer()

          VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 1) {
              Text(price)
                .typography(.title, weight: .bold)
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
        .padding(.vertical, isProminent ? 22 : 18)
        .background(
          isProminent
            ? AppTheme.Colors.elevatedCardBackground(for: scheme)
            : AppTheme.Colors.pageBackground(for: scheme),
          in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 18)
            .stroke(
              selected || isProminent ? AppTheme.Colors.tint(for: scheme) : AppTheme.Colors.separator(for: scheme),
              lineWidth: selected || isProminent ? 1.5 : 0.5
            )
        }

        if let badge {
          Text(badge)
            .typography(.nano, weight: .bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppTheme.Colors.tint(for: scheme), in: Capsule())
            .offset(x: 16, y: -10)
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
            Text(billingManager.isPurchasing ? "Purchasing..." : "Get Pro Access")
              .font(.headline.weight(.semibold))
              .frame(maxWidth: .infinity)
          }
        }
        .buttonStyle(.glassProminent)
        .disabled(billingManager.isPurchasing || billingManager.selectedPackage == nil)

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
