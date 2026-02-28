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
    HStack(alignment: .top, spacing: 12) {
      // Gradient badge
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: AppTheme.avatarGradient(for: colorScheme),
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 44, height: 44)
        Image(systemName: icon)
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(.white)
          .modifier(MatchedGeometryIfAvailable(id: "onboarding.header.icon", namespace: namespace))
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .typography(.title, weight: .bold)
          .foregroundStyle(.primary)
          .modifier(MatchedGeometryIfAvailable(id: "onboarding.header.title", namespace: namespace))

        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .typography(.nano)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(.ultraThinMaterial)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(
          Color.white.opacity(colorScheme == .dark ? 0.12 : 0.25),
          lineWidth: 1
        )
    )
    .shadow(
      color: AppTheme.Colors.tint(for: colorScheme).opacity(0.15),
      radius: 12, x: 0, y: 6
    )
  }
}
private struct MatchedGeometryIfAvailable: ViewModifier {
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

