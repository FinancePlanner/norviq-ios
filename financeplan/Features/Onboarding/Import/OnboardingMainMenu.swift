//
//  OnboardingMainMenu.swift
//  financeplan
//
import StockPlanShared
import SwiftUI

struct OnboardingMainMenu: View {
  @Environment(\.colorScheme) private var colorScheme

  let onSelectStocks: () -> Void
  let onSelectCrypto: () -> Void
  let onSelectExpenses: () -> Void
  let onSignOut: () -> Void
  let onSkip: () -> Void

  var body: some View {
    VStack(spacing: 32) {
      VStack(spacing: 12) {
        Text(VigilWatch.wealthImport.eyebrow)
          .vigilOverline()
          .foregroundStyle(.secondary)

        NorviqFullLogo(width: 190)
          .padding(.bottom, 4)

        Text("Welcome to Norviq")
          .typography(.hero, weight: .bold)

        Text("How would you like to start building your workspace?")
          .typography(.label)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)
      }
      .onboardingStepCard(cornerRadius: 24)
      .padding(.horizontal, 24)
      .padding(.top, 60)

      VStack(spacing: 16) {
        OnboardingMenuButton(
          title: "Import Stocks",
          subtitle: "Connect accounts or upload CSVs",
          icon: "chart.line.uptrend.xyaxis",
          color: .blue,
          accessibilityIdentifier: "onboarding.importStocksButton",
          action: onSelectStocks
        )

        OnboardingMenuButton(
          title: "Add Crypto",
          subtitle: "Track coins on your watchlist",
          icon: "bitcoinsign.circle.fill",
          color: .yellow,
          accessibilityIdentifier: "onboarding.addCryptoButton",
          action: onSelectCrypto
        )

        OnboardingMenuButton(
          title: "Import Expenses",
          subtitle: "Track your spending and budget",
          icon: "creditcard.fill",
          color: .orange,
          accessibilityIdentifier: "onboarding.importExpensesButton",
          action: onSelectExpenses
        )
      }
      .padding(.horizontal, 24)

      Spacer()

      // No review ask here. This is the first onboarding screen — the user has not
      // imported anything yet, so there is nothing to have an opinion about. Reviews are
      // now requested from earned moments (see ReviewPromptCoordinator).
      HStack(spacing: 24) {
        Button("Sign Out", action: onSignOut)
          .typography(.caption, weight: .medium)
          .foregroundStyle(.red)

        Button("Skip for Now", action: onSkip)
          .typography(.caption, weight: .medium)
          .foregroundStyle(.secondary)
      }
      .padding(.bottom, 40)
    }
    .background {
      MeshGradientBackground()
        .vigilScreenBackground()
        .ignoresSafeArea()
    }
    .accessibilityIdentifier("onboardingMainMenu")
  }
}

private struct OnboardingMenuButtonChrome: ViewModifier {
  func body(content: Content) -> some View {
    // Both branches already resolved to appGlassEffect — Vigil via
    // vigilGlassCard, Classic directly — so GlassCard is a proven no-op
    // collapse: same background for both, plus the Vigil-only stroke that
    // vigilGlassCard already applied.
    GlassCard(cornerRadius: 20, padding: 0) {
      content
    }
  }
}

struct OnboardingMenuButton: View {
  let title: String
  let subtitle: String
  let icon: String
  let color: Color
  var accessibilityIdentifier: String?
  var isDisabled: Bool = false
  let action: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        ZStack {
          Circle()
            .fill(color.opacity(0.15))
            .frame(width: 48, height: 48)

          Image(systemName: icon)
            .font(.title3.weight(.bold))
            .foregroundStyle(color)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .typography(.label, weight: .bold)
            .foregroundStyle(isDisabled ? .secondary : .primary)

          Text(subtitle)
            .typography(.nano)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.subheadline.weight(.bold))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .modifier(OnboardingMenuButtonChrome())
      .opacity(isDisabled ? 0.6 : 1.0)
    }
    .buttonStyle(PressableStyle())
    .accessibilityIdentifier(accessibilityIdentifier ?? "onboarding.menuButton.\(title)")
    .disabled(isDisabled)
  }
}
