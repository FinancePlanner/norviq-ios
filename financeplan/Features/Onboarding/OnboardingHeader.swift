//
//  OnboardingHeader.swift
//  financeplan
//
//  Created by Fernando Correia on 28.02.26.
//

import SwiftUI

struct OnboardingHeader: View {
  let icon: String
  let title: String
  let subtitle: String?
  @Environment(\.colorScheme) private var colorScheme
  var namespace: Namespace.ID? = nil

  var body: some View {
    VStack(spacing: 16) {
      ZStack {
        // Outer glow
        Circle()
          .fill(
            RadialGradient(
              colors: [
                AppTheme.Colors.tint(for: colorScheme).opacity(0.15),
                AppTheme.Colors.tint(for: colorScheme).opacity(0.03),
                .clear,
              ],
              center: .center,
              startRadius: 5,
              endRadius: 48
            )
          )
          .frame(width: 88, height: 88)

        Circle()
          .fill(AppTheme.Colors.tintSoft(for: colorScheme))
          .frame(width: 56, height: 56)

        Image(systemName: icon)
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          .modifier(
            MatchedGeometryIfAvailableHeader(id: "onboarding.header.icon", namespace: namespace))
      }

      VStack(spacing: 8) {
        Text(title)
          .typography(.title, weight: .bold)
          .foregroundStyle(.primary)
          .multilineTextAlignment(.center)
          .modifier(
            MatchedGeometryIfAvailableHeader(id: "onboarding.header.title", namespace: namespace))

        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .typography(.small)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 20)
  }
}

private struct MatchedGeometryIfAvailableHeader: ViewModifier {
  let id: String
  let namespace: Namespace.ID?
  func body(content: Content) -> some View {
    if let ns = namespace {
      content.matchedGeometryEffect(id: id, in: ns)
    } else {
      content
    }
  }
}
