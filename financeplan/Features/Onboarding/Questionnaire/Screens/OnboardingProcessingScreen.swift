import SwiftUI

/// 2-second auto-advancing loader. Sub-line cycles every 700ms.
struct OnboardingProcessingScreen: View {
  let onComplete: () -> Void

  private static let subLines: [String] = [
    "Reading your goals…",
    "Modelling your projection…",
    "Finding where to start…"
  ]

  @State private var phase = 0
  @State private var pulse = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      ZStack {
        Circle()
          .fill(
            RadialGradient(
              colors: [
                AppTheme.Colors.tint(for: colorScheme).opacity(0.25),
                AppTheme.Colors.tint(for: colorScheme).opacity(0.05),
                .clear
              ],
              center: .center,
              startRadius: 8,
              endRadius: 80
            )
          )
          .frame(width: 160, height: 160)
          .scaleEffect(pulse ? 1.05 : 0.95)
          .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

        Circle()
          .fill(AppTheme.Colors.tintSoft(for: colorScheme))
          .frame(width: 88, height: 88)

        Image(systemName: "sparkles")
          .font(.largeTitle.bold())
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
      }

      VStack(spacing: 10) {
        Text("Building your starter view…")
          .typography(.title, weight: .bold)
          .multilineTextAlignment(.center)

        Text(Self.subLines[phase])
          .typography(.label)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .id(phase)
          .transition(.opacity.combined(with: .move(edge: .bottom)))
      }
      .padding(.horizontal, 24)

      Spacer()
    }
    .onAppear {
      pulse = true
      runCycle()
    }
  }

  private func runCycle() {
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(700))
      withAnimation(.easeInOut(duration: 0.3)) {
        phase = 1
      }
      try? await Task.sleep(for: .milliseconds(700))
      withAnimation(.easeInOut(duration: 0.3)) {
        phase = 2
      }
      try? await Task.sleep(for: .milliseconds(600))
      onComplete()
    }
  }
}
