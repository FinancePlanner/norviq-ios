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
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

        Circle()
          .fill(AppTheme.Colors.tintSoft(for: colorScheme))
          .frame(width: 88, height: 88)

        Image(systemName: "sparkles")
          .font(.largeTitle.bold())
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))

        ProgressView()
          .controlSize(.small)
          .offset(y: 58)
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
          .transition(AppTransition.move(edge: .bottom, reduceMotion: reduceMotion))
      }
      .padding(.horizontal, 24)

      Spacer()
    }
    .onAppear {
      runCycle()
    }
  }

  private func runCycle() {
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(700))
      withAnimation(reduceMotion ? AppMotion.reduced : AppMotion.state) {
        phase = 1
      }
      try? await Task.sleep(for: .milliseconds(700))
      withAnimation(reduceMotion ? AppMotion.reduced : AppMotion.state) {
        phase = 2
      }
      try? await Task.sleep(for: .milliseconds(600))
      onComplete()
    }
  }
}
