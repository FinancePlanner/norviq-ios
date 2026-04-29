import Factory
import RevenueCat
import SwiftUI

struct PreLoginPaywallScreen: View {
  @Environment(\.colorScheme) private var scheme
  @InjectedObservable(\Container.billingManager) private var billingManager
  
  var onContinue: () -> Void

  var body: some View {
    ZStack {
      AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea()

      ScrollView {
        VStack(spacing: 24) {
          hero
          featuresList
          packageSelector
          actionButtons
          
          if let error = billingManager.errorMessage {
            Text(error)
              .typography(.caption)
              .foregroundStyle(AppTheme.Colors.danger)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }
          
          AuthFooter()
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .padding(.bottom, 16)
      }
    }
    .task {
      await billingManager.loadOfferings()
    }
  }

  private var hero: some View {
    VStack(spacing: 12) {
      Text("Unlock your financial potential")
        .typography(.title, weight: .bold)
        .multilineTextAlignment(.center)
        .foregroundStyle(.primary)

      Text("Get full clarity on your net worth and make better decisions with Pro.")
        .typography(.body)
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
    }
  }

  private var featuresList: some View {
    VStack(spacing: 16) {
      featureRow(icon: "chart.line.uptrend.xyaxis", title: "Unlimited Syncing", desc: "Connect all your brokers for real-time updates.", isPro: true)
      featureRow(icon: "waveform.path.ecg", title: "Advanced Projections", desc: "See where your money is going years ahead.", isPro: true)
      featureRow(icon: "bolt.fill", title: "Real-time Market Data", desc: "Instant quotes without delays.", isPro: true)
      featureRow(icon: "lock.shield", title: "Basic Portfolio", desc: "Track your main assets manually.", isPro: false)
    }
    .padding()
    .background(AppTheme.Colors.elevatedCardBackground(for: scheme), in: RoundedRectangle(cornerRadius: 24))
  }

  private func featureRow(icon: String, title: String, desc: String, isPro: Bool) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundStyle(isPro ? AppTheme.Colors.tint(for: scheme) : .secondary)
        .frame(width: 32)
      
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(title)
            .typography(.label, weight: .semibold)
          if isPro {
            Text("PRO")
              .typography(.nano, weight: .bold)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(AppTheme.Colors.tint(for: scheme).opacity(0.2))
              .foregroundStyle(AppTheme.Colors.tint(for: scheme))
              .clipShape(Capsule())
          }
        }
        Text(desc)
          .typography(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var packageSelector: some View {
    VStack(spacing: 12) {
      planCard(
        title: "Annual",
        subtitle: "7-day free trial",
        price: price(for: billingManager.annualPackage, fallback: "$49.99/yr"),
        productID: "pro_annual",
        badge: "Save 2 months"
      )

      planCard(
        title: "Monthly",
        subtitle: "Cancel anytime",
        price: price(for: billingManager.monthlyPackage, fallback: "$4.99/mo"),
        productID: "pro_monthly",
        badge: nil
      )

      planCard(
        title: "Weekly",
        subtitle: "Short term",
        price: price(for: billingManager.weeklyPackage, fallback: "$0.99/wk"),
        productID: "pro_weekly",
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
  }

  private var actionButtons: some View {
    VStack(spacing: 12) {
      Button {
        Task {
          let success = await billingManager.purchaseSelectedPackage()
          if success {
            onContinue()
          }
        }
      } label: {
        HStack {
          if billingManager.isPurchasing {
            ProgressView().tint(.white).padding(.trailing, 8)
          }
          Text("Start Free Trial")
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.glassProminent)
      .disabled(billingManager.isPurchasing)

      Button(action: onContinue) {
        Text("Continue with Free")
          .font(.headline.weight(.medium))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
      }
    }
  }

  private func price(for package: Package?, fallback: String) -> String {
    package?.localizedPriceString ?? fallback
  }
}
