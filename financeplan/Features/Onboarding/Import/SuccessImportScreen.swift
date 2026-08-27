//
//  SuccessImportScreen.swift
//  financeplan
//
import StockPlanShared
import SwiftUI

struct SuccessImportScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  let optionalNextActionTitle: String?
  let onOptionalNextAction: () -> Void
  let onDone: () -> Void

  var body: some View {
    VStack(spacing: 32) {
      Spacer()

      VStack(spacing: 24) {
        Text(VigilWatch.vigilActive.eyebrow)
          .vigilOverline()
          .foregroundStyle(.secondary)

        ZStack {
          Circle()
            .fill(AppTheme.Colors.success.opacity(0.12))
            .frame(width: 100, height: 100)

          Image(systemName: "checkmark.seal.fill")
            .font(.largeTitle.bold())
            .foregroundStyle(AppTheme.Colors.success)
        }

        VStack(spacing: 12) {
          Text("All Set!")
            .typography(.hero, weight: .bold)

          Text("Your data has been imported. You can now explore your workspace insights.")
            .typography(.label)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
        }
      }
      .onboardingStepCard(cornerRadius: 28)
      .padding(.horizontal, 24)

      VStack(spacing: 16) {
        if let optionalNextActionTitle {
          Button {
            onOptionalNextAction()
          } label: {
            Text(optionalNextActionTitle)
              .typography(.label, weight: .semibold)
          }
          .buttonStyle(GlowingButtonStyle())
          .padding(.horizontal, 24)
        }

        // "Go to Home" now leads. A review ask used to sit above this as the glowing
        // primary CTA, before the user had seen a single screen of their own data.
        Button {
          onDone()
        } label: {
          Text("Go to Home")
            .typography(.label, weight: .semibold)
        }
        .buttonStyle(GlowingButtonStyle())
        .padding(.horizontal, 24)
      }

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(MeshGradientBackground().ignoresSafeArea())
  }
}
