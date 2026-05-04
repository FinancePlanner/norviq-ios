import SwiftUI

/// Top-level container for the questionnaire-style onboarding flow.
/// Replaces `PreLoginPaywallScreen` + `PrivacyWelcomeScreen` in `ContentView` for first-launch.
///
/// Outcomes:
/// - `onLogInRequested`: user tapped "Log in" on the welcome screen — caller should route
///   to the existing `LoginScreen`. Caller should also mark the questionnaire complete so
///   returning users don't see it again.
/// - `onCompleted`: user reached the end of the flow (signed up via Screen 12 + chose a
///   paywall outcome on Screen 13). At this point the user IS authenticated; the caller
///   should apply authenticated state.
struct OnboardingQuestionnaireFlow: View {
  @StateObject private var viewModel = OnboardingQuestionnaireViewModel()

  let onLogInRequested: () -> Void
  let onCompleted: () -> Void

  var body: some View {
    ZStack {
      MeshGradientBackground().ignoresSafeArea()

      VStack(spacing: 0) {
        if viewModel.progressBarVisible {
          ProgressBar(
            value: viewModel.progressFraction,
            total: 1.0,
            color: AppTheme.Colors.tint(for: .dark),
            height: 4,
            showPattern: false
          )
          .padding(.horizontal, 20)
          .padding(.top, 8)
          .transition(.opacity)
        }

        Group {
          switch viewModel.step {
          case .welcome:
            placeholderScreen("Welcome")
          case .goal:
            placeholderScreen("Goal question")
          case .painPoints:
            placeholderScreen("Pain points")
          case .socialProof:
            placeholderScreen("Social proof")
          case .swipeStatements:
            placeholderScreen("Swipe statements")
          case .solution:
            placeholderScreen("Personalised solution")
          case .comparison:
            placeholderScreen("Comparison table")
          case .holdingsPreference:
            placeholderScreen("Holdings preference")
          case .spendingPreference:
            placeholderScreen("Spending preference")
          case .processing:
            placeholderScreen("Processing")
          case .demoBuild:
            placeholderScreen("Demo: swipe to build watchlist")
          case .valueReveal:
            placeholderScreen("Value reveal")
          case .accountCreation:
            placeholderScreen("Account creation")
          case .paywall:
            placeholderScreen("Paywall")
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.step)
  }

  // MARK: - Placeholders (swapped out screen-by-screen in subsequent chunks)

  @ViewBuilder
  private func placeholderScreen(_ title: String) -> some View {
    VStack(spacing: 24) {
      Spacer()

      Text("Step \(viewModel.step.rawValue + 1) / \(OnboardingQuestionnaireViewModel.Step.allCases.count)")
        .typography(.caption)
        .foregroundStyle(.secondary)

      Text(title)
        .typography(.title, weight: .bold)
        .multilineTextAlignment(.center)

      Spacer()

      VStack(spacing: 12) {
        Button {
          if viewModel.step == .paywall {
            viewModel.captureCompleted(authenticated: true, purchased: false)
            onCompleted()
          } else {
            viewModel.advance()
          }
        } label: {
          Text(viewModel.step == .paywall ? "Finish" : "Continue")
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(GlowingButtonStyle())

        if viewModel.step == .welcome {
          Button("Already have an account? Log in", action: onLogInRequested)
            .typography(.small, weight: .semibold)
            .foregroundStyle(.secondary)
        }

        if viewModel.step.rawValue > 0 && viewModel.step != .paywall {
          Button("Back") { viewModel.goBack() }
            .typography(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 40)
    }
  }
}

#Preview {
  OnboardingQuestionnaireFlow(onLogInRequested: {}, onCompleted: {})
}
