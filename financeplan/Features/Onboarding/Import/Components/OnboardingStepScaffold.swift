//
//  OnboardingStepScaffold.swift
//  financeplan
//
import StockPlanShared
import SwiftUI

struct OnboardingStepScaffoldConfig {
  let title: String
  let icon: String
  var namespace: Namespace.ID?
  var primaryActionTitle: String?
  var primaryActionAccessibilityIdentifier: String?
  var isPrimaryActionEnabled: Bool = true
  var isPrimaryActionLoading: Bool = false
  var showsPrimaryActionArrow: Bool = false
  var contentHorizontalPadding: CGFloat = 20
  var contentMaxWidth: CGFloat?
}

struct OnboardingStepBanner {
  let message: String
  let style: ToastBanner.Style
}

struct OnboardingStepScaffold<TopAccessory: View, Content: View, Footer: View>: View {
  @Environment(\.colorScheme) private var colorScheme

  let config: OnboardingStepScaffoldConfig
  let onBack: () -> Void
  let onPrimaryAction: (() -> Void)?
  let banner: OnboardingStepBanner?
  let scrollDismissesKeyboard: ScrollDismissesKeyboardMode
  @ViewBuilder let topAccessory: () -> TopAccessory
  @ViewBuilder let content: () -> Content
  @ViewBuilder let footer: () -> Footer

  var body: some View {
    VStack(spacing: 0) {
      OnboardingNavBar(
        title: config.title,
        icon: config.icon,
        namespace: config.namespace,
        onBack: onBack
      )

      ScrollView(.vertical) {
        VStack(spacing: 0) {
          topAccessory()
          content()
        }
        .padding(.horizontal, config.contentHorizontalPadding)
        .modifier(MaxContentWidthModifier(maxWidth: config.contentMaxWidth))
      }
      .scrollDismissesKeyboard(scrollDismissesKeyboard)
      .scrollBounceBehavior(.basedOnSize)

      if let onPrimaryAction, let primaryActionTitle = config.primaryActionTitle {
        defaultPrimaryActionFooter(
          title: primaryActionTitle,
          isEnabled: config.isPrimaryActionEnabled,
          isLoading: config.isPrimaryActionLoading,
          showsArrow: config.showsPrimaryActionArrow,
          action: onPrimaryAction
        )
      } else {
        footer()
      }
    }
    .background(MeshGradientBackground().ignoresSafeArea())
    .overlay(alignment: .top) {
      if let banner {
        ToastBanner(message: banner.message, style: banner.style)
          .padding(.horizontal, 16)
          .padding(.top, 60)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
  }

  @ViewBuilder
  private func defaultPrimaryActionFooter(
    title: String,
    isEnabled: Bool,
    isLoading: Bool,
    showsArrow: Bool,
    action: @escaping () -> Void
  ) -> some View {
    VStack(spacing: 0) {
      Divider().opacity(0.3)

      HStack(spacing: 12) {
        Spacer()

        Button(action: action) {
          HStack(spacing: 8) {
            if isLoading {
              ProgressView()
                .tint(.white)
            }

            Text(title)
              .font(.headline)
              .fontWeight(.bold)

            if showsArrow && !isLoading {
              Image(systemName: "arrow.right")
                .font(.subheadline.weight(.bold))
            }
          }
          .foregroundStyle(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(
            Capsule()
              .fill(AppTheme.Colors.tint(for: colorScheme))
          )
          .shadow(
            color: AppTheme.Colors.tint(for: colorScheme).opacity(0.25),
            radius: 8, x: 0, y: 4
          )
        }
        .accessibilityIdentifier(
          config.primaryActionAccessibilityIdentifier ?? "onboardingPrimaryActionButton")
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)
      .appGlassEffect(.rect(cornerRadius: 0))
      .ignoresSafeArea(edges: .bottom)
    }
  }
}

