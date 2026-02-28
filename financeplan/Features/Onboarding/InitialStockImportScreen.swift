import SwiftUI

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
      return "Upload your broker/exported CSV file."
    case .manual:
      return "Add your positions one by one."
    case .api:
      return "Sync holdings from a broker/integration API."
    }
  }
}

struct PressEffectStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      .opacity(configuration.isPressed ? 0.9 : 1.0)
      .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
  }
}

struct InitialStockImportScreen: View {
  let onImportCompleted: (StockImportMethod) -> Void
  @Environment(\.colorScheme) private var colorScheme
  let headerNamespace: Namespace.ID?

  @State private var selectedMethod: StockImportMethod?
  @State private var tappedMethod: StockImportMethod? = nil
  @State private var isSubmitting = false
  @State private var message: String?
  @State private var animatedIndices: Set<Int> = []

  var body: some View {
    VStack(spacing: 20) {
      Spacer(minLength: 0)

      LinearGradient(
        colors: AppTheme.heroGradient(for: colorScheme),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .frame(height: 80)
      .mask(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
      )
      .overlay(
        OnboardingHeader(
          icon: "tray.and.arrow.down.fill",
          title: "Import Your Stocks",
          subtitle: "This step is required the first time you sign in. Choose one import method to continue.",
          namespace: headerNamespace
        )
        .padding(.horizontal, 4)
      )

      methodSelectionList

      if let message {
        Text(message)
          .typography(.nano)
          .foregroundStyle(AppTheme.Colors.success)
      }

      Button {
        Task { await completeImport() }
      } label: {
        HStack(spacing: 8) {
          if isSubmitting {
            ProgressView()
              .tint(.white)
          }
          Text(buttonTitle)
            .font(.headline)
            .fontWeight(.bold)
        }
      }
      .buttonStyle(GlowingButtonStyle())
      .disabled(selectedMethod == nil || isSubmitting)
      .accessibilityIdentifier("stockImportContinueButton")
      .opacity(animatedIndices.count == StockImportMethod.allCases.count ? 1 : 0)
      .animation(.easeIn(duration: 0.3), value: animatedIndices.count)

      Spacer(minLength: 0)
    }
    .accessibilityIdentifier("initialStockImportScreen")
    .padding(16)
    .frame(maxWidth: 520, maxHeight: .infinity)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(MeshGradientBackground().ignoresSafeArea())
  }

  private var buttonTitle: String {
    guard let selectedMethod else {
      return "Select a Method"
    }
    return "Continue with \(selectedMethod.title)"
  }

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
      selectedMethod = method
      message = nil
      withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
        tappedMethod = method
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
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
    .offset(y: animatedIndices.contains(index) ? 0 : 20)
    .scaleEffect(tappedMethod == method ? 1.03 : 1.0)
    .opacity(tappedMethod == method ? 1.0 : 0.98)
    .animation(.easeInOut(duration: 0.12), value: selectedMethod)
    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: tappedMethod)
  }

  private func animateMethodOptions() {
    for (index, _) in StockImportMethod.allCases.enumerated() {
      DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15 + 0.2) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
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

    // Placeholder completion. Replace with real import flows.
    try? await Task.sleep(nanoseconds: 300_000_000)
    message = "\(selectedMethod.title) selected."
    onImportCompleted(selectedMethod)
  }
}

private struct ImportMethodCard: View {
  let method: StockImportMethod
  let isSelected: Bool
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        .foregroundStyle(
          isSelected ? AppTheme.Colors.tint(for: colorScheme) : .secondary)

      VStack(alignment: .leading, spacing: 4) {
        Text(method.title)
          .typography(.label, weight: .semibold)
          .foregroundStyle(.primary)

        Text(method.subtitle)
          .typography(.nano)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.ultraThinMaterial)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(
          isSelected
            ? AppTheme.Colors.tint(for: colorScheme)
            : Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3),
          lineWidth: isSelected ? 2 : 1
        )
    )
    .shadow(
      color: isSelected
        ? AppTheme.Colors.tint(for: colorScheme).opacity(0.3) : Color.clear,
      radius: 10, x: 0, y: 5
    )
  }
}
