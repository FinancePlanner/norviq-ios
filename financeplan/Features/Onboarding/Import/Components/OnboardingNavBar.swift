//
//  OnboardingNavBar.swift
//  financeplan
//
import StockPlanShared
import SwiftUI

struct OnboardingNavBar: View {
  let title: String
  let icon: String
  var namespace: Namespace.ID?
  let onBack: () -> Void

  init(
    title: String,
    icon: String,
    namespace: Namespace.ID? = nil,
    onBack: @escaping () -> Void
  ) {
    self.title = title
    self.icon = icon
    self.namespace = namespace
    self.onBack = onBack
  }

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onBack) {
        HStack(spacing: 4) {
          Image(systemName: "chevron.left")
            .font(.body.weight(.semibold))
          Text("Back")
            .typography(.label)
        }
        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
      }

      Spacer()

      HStack(spacing: 8) {
        Image(systemName: icon)
          .imageScale(.medium)
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          .modifier(
            MatchedGeometryIfAvailable(
              id: "onboarding.header.icon", namespace: namespace, isSource: false))

        Text(title)
          .typography(.label, weight: .semibold)
          .modifier(
            MatchedGeometryIfAvailable(
              id: "onboarding.header.title", namespace: namespace, isSource: false))
      }

      Spacer()

      // Balance spacer for back button
      Color.clear
        .frame(width: 64, height: 1)
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.vertical, 12)
    .appGlassEffect(.rect(cornerRadius: 0))
    .overlay(alignment: .bottom) {
      Divider().opacity(0.2)
    }
  }
}
