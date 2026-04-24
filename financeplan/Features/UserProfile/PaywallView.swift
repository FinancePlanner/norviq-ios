import RevenueCat
import SwiftUI

@MainActor
struct PaywallView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var scheme
  let billingManager: BillingManager

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          hero
          planCards
          featureList
          purchaseButton
          restoreButton
          errorMessage
        }
        .padding(24)
      }
      .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
      .navigationTitle("Upgrade to Pro")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
        }
      }
      .task {
        await billingManager.loadOfferings()
      }
      .onChange(of: billingManager.isPro) { _, isPro in
        if isPro {
          dismiss()
        }
      }
    }
  }

  private var hero: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Norviqa Pro")
        .typography(.title, weight: .bold)
        .foregroundStyle(.primary)

      Text("Sync your portfolio, unlock real fundamentals, build projections, and automate alerts.")
        .typography(.body)
        .foregroundStyle(.secondary)

      Text("14-day free trial on annual")
        .typography(.caption, weight: .bold)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(AppTheme.Colors.tint(for: scheme), in: Capsule())
        .accessibilityLabel("14-day free trial on annual plan")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(22)
    .background(AppTheme.Colors.elevatedCardBackground(for: scheme), in: RoundedRectangle(cornerRadius: 28))
  }

  private var planCards: some View {
    VStack(spacing: 12) {
      planCard(
        title: "Annual",
        subtitle: "Best value",
        price: price(for: billingManager.annualPackage, fallback: "$59.99/yr"),
        productID: "pro_annual",
        badge: "Save 17%"
      )

      planCard(
        title: "Monthly",
        subtitle: "Flexible access",
        price: price(for: billingManager.monthlyPackage, fallback: "$5.99/mo"),
        productID: "pro_monthly",
        badge: nil
      )
    }
  }

  private func planCard(
    title: String,
    subtitle: String,
    price: String,
    productID: String,
    badge: String?
  ) -> some View {
    let selected = billingManager.selectedProductID == productID
    return Button {
      billingManager.select(productID: productID)
    } label: {
      HStack(spacing: 14) {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
          .imageScale(.large)
          .foregroundStyle(selected ? AppTheme.Colors.tint(for: scheme) : .secondary)
          .accessibilityHidden(true)

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
                .background(Color.green, in: Capsule())
            }
          }
          Text(subtitle)
            .typography(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Text(price)
          .typography(.label, weight: .semibold)
          .foregroundStyle(.primary)
      }
      .padding(18)
      .background(AppTheme.Colors.elevatedCardBackground(for: scheme), in: RoundedRectangle(cornerRadius: 22))
      .overlay {
        RoundedRectangle(cornerRadius: 22)
          .stroke(selected ? AppTheme.Colors.tint(for: scheme) : .clear, lineWidth: 2)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(title) Pro plan, \(price), \(subtitle)")
  }

  private var featureList: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Included")
        .typography(.label, weight: .bold)

      ForEach(features, id: \.self) { feature in
        Label(feature, systemImage: "checkmark.seal.fill")
          .typography(.body)
          .foregroundStyle(.primary)
      }
    }
    .padding(20)
    .background(AppTheme.Colors.elevatedCardBackground(for: scheme), in: RoundedRectangle(cornerRadius: 24))
  }

  private var purchaseButton: some View {
    Button {
      Task { await billingManager.purchaseSelectedPackage() }
    } label: {
      HStack {
        if billingManager.isPurchasing {
          ProgressView()
            .tint(.white)
        }
        Text(billingManager.isPurchasing ? "Purchasing..." : "Start Pro")
          .typography(.button, weight: .bold)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
    }
    .buttonStyle(.borderedProminent)
    .disabled(billingManager.isPurchasing || billingManager.selectedPackage == nil)
  }

  private var restoreButton: some View {
    Button {
      Task { await billingManager.restorePurchases() }
    } label: {
      Text(billingManager.isRestoring ? "Restoring..." : "Restore Purchases")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.bordered)
    .disabled(billingManager.isRestoring)
  }

  @ViewBuilder
  private var errorMessage: some View {
    if let message = billingManager.errorMessage, !message.isEmpty {
      Text(message)
        .typography(.caption)
        .foregroundStyle(AppTheme.Colors.danger)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var features: [String] {
    [
      "Cloud sync for expenses and reports",
      "Real broker auto-sync",
      "Real stock fundamentals",
      "Bear, base, and bull projections",
      "Reports with SwiftUI charts",
      "Price, dividend, and earnings alerts"
    ]
  }

  private func price(for package: Package?, fallback: String) -> String {
    package?.storeProduct.localizedPriceString ?? fallback
  }
}
