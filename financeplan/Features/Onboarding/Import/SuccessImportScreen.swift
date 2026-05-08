//
//  SuccessImportScreen.swift
//  financeplan
//
import StockPlanShared
import StoreKit
import SwiftUI

struct SuccessImportScreen: View {
  @Environment(\.requestReview) var requestReview
  @Environment(\.colorScheme) private var colorScheme
  let optionalNextActionTitle: String?
  let onOptionalNextAction: () -> Void
  let onDone: () -> Void

  var body: some View {
    VStack(spacing: 32) {
      Spacer()

      VStack(spacing: 24) {
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

      VStack(spacing: 16) {
        Button {
          requestReview()
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "star.fill")
            Text("Leave a review")
          }
          .font(.headline)
          .fontWeight(.bold)
        }
        .buttonStyle(GlowingButtonStyle())
        .padding(.horizontal, 24)

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

        Button {
          onDone()
        } label: {
          Text("Go to Home")
            .typography(.label, weight: .semibold)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(MeshGradientBackground().ignoresSafeArea())
  }
}
