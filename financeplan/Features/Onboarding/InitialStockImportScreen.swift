import SwiftUI

struct PressEffectStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      .opacity(configuration.isPressed ? 0.9 : 1.0)
      .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
  }
}

enum StockImportMethod: String, CaseIterable, Identifiable {
  case csv
  case manual
  case api

  var id: String { rawValue }

  var title: String {
    switch self {
    case .csv:
      return "Import CSV"
    case .manual:
      return "Enter Manually"
    case .api:
      return "Connect API"
    }
  }

  var subtitle: String {
    switch self {
    case .csv:
      return "Upload a broker export or CSV file with your positions."
    case .manual:
      return "Type in your holdings one position at a time."
    case .api:
      return "Sync holdings automatically from a broker integration."
    }
  }

  var icon: String {
    switch self {
    case .csv:
      return "doc.text.fill"
    case .manual:
      return "square.and.pencil"
    case .api:
      return "link.circle.fill"
    }
  }

  var iconColor: (ColorScheme) -> Color {
    switch self {
    case .csv:
      return { scheme in AppTheme.Colors.secondaryTint(for: scheme) }
    case .manual:
      return { scheme in AppTheme.Colors.tint(for: scheme) }
    case .api:
      return { _ in .indigo }
    }
  }
}

struct InitialStockImportScreen: View {
  let onImportCompleted: (StockImportMethod) -> Void
  let onSignOut: () -> Void
  let onBack: () -> Void
  @Environment(\.colorScheme) private var colorScheme
  let headerNamespace: Namespace.ID?

  @State private var selectedMethod: StockImportMethod?
  @State private var tappedMethod: StockImportMethod?
  @State private var isSubmitting = false
  @State private var isSigningOut = false
  @State private var message: String?
  @State private var animatedIndices: Set<Int> = []
  @State private var headerVisible = false

  var body: some View {
    OnboardingStepScaffold(
      config: OnboardingStepScaffoldConfig(
        title: "Stock Import",
        icon: "chart.line.uptrend.xyaxis",
        namespace: headerNamespace,
        primaryActionTitle: buttonTitle,
        primaryActionAccessibilityIdentifier: "stockImportContinueButton",
        isPrimaryActionEnabled: selectedMethod != nil && !isSubmitting,
        isPrimaryActionLoading: isSubmitting,
        showsPrimaryActionArrow: selectedMethod != nil && !isSubmitting,
        contentHorizontalPadding: 24,
        contentMaxWidth: 520
      ),
      onBack: onBack,
      onPrimaryAction: {
        Task { await completeImport() }
      },
      banner: nil,
      scrollDismissesKeyboard: .never
    ) {
      topActions
        .padding(.top, 12)
        .padding(.bottom, 20)
    } content: {
      VStack(spacing: 0) {
        Spacer(minLength: 12)

        // MARK: - Hero header
        heroHeader
          .padding(.bottom, 32)

        // MARK: - Method cards
        methodSelectionList
          .padding(.bottom, 24)

        // MARK: - Info message
        if let message {
          Text(message)
            .typography(.small)
            .foregroundStyle(AppTheme.Colors.success)
            .padding(.bottom, 12)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }

        Spacer(minLength: 20)
      }
    } footer: {
      EmptyView()
    }
    .accessibilityIdentifier("initialStockImportScreen")
  }

  private var topActions: some View {
    HStack {
      Spacer()

      Button {
        guard !isSigningOut else { return }
        isSigningOut = true
        onSignOut()
      } label: {
        HStack(spacing: 8) {
          if isSigningOut {
            ProgressView()
              .controlSize(.small)
              .tint(AppTheme.Colors.tint(for: colorScheme))
          } else {
            Image(systemName: "rectangle.portrait.and.arrow.right")
              .font(.subheadline.weight(.semibold))
          }

          Text(isSigningOut ? "Signing Out" : "Sign Out")
            .typography(.small, weight: .semibold)
        }
        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .appGlassEffect(.capsule)
      }
      .buttonStyle(PressEffectStyle())
      .accessibilityIdentifier("stockImportSignOutButton")
      .disabled(isSigningOut)
    }
  }

  // MARK: - Hero Header

  private var heroHeader: some View {
    VStack(spacing: 16) {
      // Animated icon
      ZStack {
        // Outer pulsing ring
        Circle()
          .stroke(
            AppTheme.Colors.tint(for: colorScheme).opacity(0.15),
            lineWidth: 2
          )
          .frame(width: 96, height: 96)
          .scaleEffect(headerVisible ? 1.0 : 0.7)

        // Inner glow circle
        Circle()
          .fill(
            RadialGradient(
              colors: [
                AppTheme.Colors.tint(for: colorScheme).opacity(0.18),
                AppTheme.Colors.tint(for: colorScheme).opacity(0.04),
                .clear
              ],
              center: .center,
              startRadius: 5,
              endRadius: 48
            )
          )
          .frame(width: 96, height: 96)

        // Icon background
        Circle()
          .fill(AppTheme.Colors.tintSoft(for: colorScheme))
          .frame(width: 68, height: 68)
          .modifier(
            MatchedGeometryIfAvailable(
              id: "onboarding.header.icon.bg", namespace: headerNamespace))

        Image(systemName: "chart.line.uptrend.xyaxis")
          .font(.largeTitle.bold())
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          .modifier(
            MatchedGeometryIfAvailable(
              id: "onboarding.header.icon", namespace: headerNamespace))
      }
      .scaleEffect(headerVisible ? 1.0 : 0.5)
      .opacity(headerVisible ? 1 : 0)

      VStack(spacing: 8) {
        Text("Import Your Portfolio")
          .typography(.heading, weight: .bold)
          .multilineTextAlignment(.center)
          .modifier(
            MatchedGeometryIfAvailable(
              id: "onboarding.header.title", namespace: headerNamespace))
          .opacity(headerVisible ? 1 : 0)
          .offset(y: headerVisible ? 0 : 12)

        Text(
          "Choose how you'd like to bring in your existing holdings. You can always add more later."
        )
        .typography(.small)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .lineSpacing(3)
        .padding(.horizontal, 8)
        .opacity(headerVisible ? 1 : 0)
        .offset(y: headerVisible ? 0 : 12)
      }
    }
    .onAppear {
      withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) {
        headerVisible = true
      }
    }
  }

  // MARK: - Method Selection

  private var methodSelectionList: some View {
    VStack(spacing: 12) {
      ForEach(Array(StockImportMethod.allCases.enumerated()), id: \.element.id) { index, method in
        methodSelectionButton(for: method, index: index)
      }
    }
    .onAppear(perform: animateMethodOptions)
  }

  private func methodSelectionButton(for method: StockImportMethod, index: Int) -> some View {
    Button {
      withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
        selectedMethod = method
        message = nil
        tappedMethod = method
      }
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
          tappedMethod = nil
        }
      }
    } label: {
      ImportMethodCard(method: method, isSelected: selectedMethod == method)
    }
    .buttonStyle(PressEffectStyle())
    .contentShape(Rectangle())
    .accessibilityIdentifier("stockImportMethod.\(method.rawValue)")
    .opacity(animatedIndices.contains(index) ? 1 : 0)
    .offset(y: animatedIndices.contains(index) ? 0 : 24)
    .scaleEffect(tappedMethod == method ? 1.02 : 1.0)
    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: tappedMethod)
  }

  private var buttonTitle: String {
    guard let selectedMethod else {
      return "Select a Method"
    }
    return "Continue with \(selectedMethod.title)"
  }

  // MARK: - Helpers

  private func animateMethodOptions() {
    for (index, _) in StockImportMethod.allCases.enumerated() {
      Task { @MainActor in
        try? await Task.sleep(for: .seconds(Double(index) * 0.12 + 0.35))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
          _ = animatedIndices.insert(index)
        }
      }
    }
  }

  @MainActor
  private func completeImport() async {
    guard let selectedMethod else {
      return
    }

    isSubmitting = true
    defer { isSubmitting = false }

    message = nil
    onImportCompleted(selectedMethod)
  }
}

// MARK: - Import Method Card

private struct ImportMethodCard: View {
  let method: StockImportMethod
  let isSelected: Bool
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 14) {
      // Icon
      ZStack {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(method.iconColor(colorScheme).opacity(isSelected ? 0.18 : 0.10))
          .frame(width: 44, height: 44)

        Image(systemName: method.icon)
          .font(.headline)
          .foregroundStyle(method.iconColor(colorScheme))
      }

      VStack(alignment: .leading, spacing: 3) {
        Text(method.title)
          .typography(.label, weight: .semibold)
          .foregroundStyle(.primary)

        Text(method.subtitle)
          .typography(.nano)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Spacer(minLength: 0)

      // Selection indicator
      ZStack {
        Circle()
          .stroke(
            isSelected
              ? AppTheme.Colors.tint(for: colorScheme)
              : AppTheme.Colors.separator(for: colorScheme).opacity(0.5),
            lineWidth: isSelected ? 0 : 1.5
          )
          .frame(width: 24, height: 24)

        if isSelected {
          Circle()
            .fill(AppTheme.Colors.tint(for: colorScheme))
            .frame(width: 24, height: 24)
            .overlay(
              Image(systemName: "checkmark")
                .typography(.nano, weight: .bold)
                .foregroundStyle(.white)
            )
            .transition(.scale.combined(with: .opacity))
        }
      }
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .appGlassEffect(
      .rect(cornerRadius: 18),
      tint: isSelected
        ? AppTheme.Colors.tintSoft(for: colorScheme).opacity(colorScheme == .dark ? 0.55 : 0.45)
        : nil
    )
    .animation(.easeInOut(duration: 0.2), value: isSelected)
  }
}
