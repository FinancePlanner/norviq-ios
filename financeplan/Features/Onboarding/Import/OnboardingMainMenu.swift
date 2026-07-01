//
//  OnboardingMainMenu.swift
//  financeplan
//
import StockPlanShared
import StoreKit
import SwiftUI

struct OnboardingMainMenu: View {
  @Environment(\.requestReview) private var requestReview
  @Environment(\.colorScheme) private var colorScheme

  let onSelectStocks: () -> Void
  let onSelectExpenses: () -> Void
  let onSignOut: () -> Void
  let onSkip: () -> Void

  var body: some View {
    VStack(spacing: 32) {
      VStack(spacing: 12) {
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

      VStack(spacing: 20) {
        Button {
          requestReview()
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "star.fill")
            Text("Enjoying the app? Leave a review")
          }
          .typography(.caption, weight: .semibold)
          .foregroundStyle(.secondary)
        }

        HStack(spacing: 24) {
          Button("Sign Out", action: onSignOut)
            .typography(.caption, weight: .medium)
            .foregroundStyle(.red)

          Button("Skip for Now", action: onSkip)
            .typography(.caption, weight: .medium)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.bottom, 40)
    }
    .background(MeshGradientBackground().ignoresSafeArea())
    .accessibilityIdentifier("onboardingMainMenu")
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
          .foregroundStyle(.secondary.opacity(0.5))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .appGlassEffect(.rect(cornerRadius: 20))
      .opacity(isDisabled ? 0.6 : 1.0)
    }
    .buttonStyle(PressEffectStyle())
    .accessibilityIdentifier(accessibilityIdentifier ?? "onboarding.menuButton.\(title)")
    .disabled(isDisabled)
  }
}
