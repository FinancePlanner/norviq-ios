import SwiftUI

/// Top-level container for the questionnaire-style onboarding flow.
/// Replaces `PreLoginPaywallScreen` + `PrivacyWelcomeScreen` in `ContentView` for first-launch.
///
/// Outcomes:
/// - `onLogInRequested`: user tapped "Log in" on the welcome screen — caller should route
///   to the existing `LoginScreen` for this session. This is not questionnaire completion.
/// - `onCompleted`: user reached the end of the flow (signed up via Screen 12 + chose a
///   paywall outcome on Screen 13). At this point the user IS authenticated; the caller
///   should apply authenticated state.
struct OnboardingQuestionnaireFlow: View {
  @State private var viewModel = OnboardingQuestionnaireViewModel()

  let onLogInRequested: () -> Void
  let onCompleted: () -> Void

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      MeshGradientBackground(animatesOnAppear: true).ignoresSafeArea()

      VStack(spacing: 0) {
        topChrome
        screenContent
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          // Keep the onboarding column readable on iPad instead of stretching
          // edge-to-edge (Guideline 4). Chrome/progress bar above stays full-width.
          .maxContentWidth(regularSizeClass: ContentWidth.marketing)
          .transition(AppTransition.directional(
            insertion: viewModel.navigationDirection == .forward ? .trailing : .leading,
            removal: viewModel.navigationDirection == .forward ? .leading : .trailing,
            reduceMotion: reduceMotion
          ))
      }
    }
    .appAnimation(AppMotion.structural, value: viewModel.step)
  }

  // MARK: - Chrome

  @ViewBuilder
  private var topChrome: some View {
    let showsBack = viewModel.step != .welcome && viewModel.step != .paywall && viewModel.step != .processing
    HStack(spacing: 12) {
      if showsBack {
        Button { viewModel.goBack() } label: {
          Image(systemName: "chevron.left")
            .font(.body.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
            .frame(width: 44, height: 44)
            .contentShape(.rect)
        }
        .accessibilityLabel("Back")
      } else {
        Color.clear.frame(width: 44, height: 44)
      }

      if viewModel.progressBarVisible {
        ProgressBar(
          value: viewModel.progressFraction,
          total: 1.0,
          color: AppTheme.Colors.tint(for: colorScheme),
          height: 4,
          showPattern: false
        )
        .frame(maxWidth: .infinity)
      } else {
        Spacer()
      }

      Color.clear.frame(width: 44, height: 44)
    }
    .padding(.horizontal, 12)
    .padding(.top, 8)
    .padding(.bottom, 4)
  }

  // MARK: - Screens

  @ViewBuilder
  private var screenContent: some View {
    switch viewModel.step {
    case .welcome:
      OnboardingWelcomeScreen(
        onGetStarted: { viewModel.advance() },
        onLogIn: onLogInRequested
      )

    case .goal:
      OnboardingGoalScreen(
        selectedGoal: Binding(
          get: { viewModel.answers.goal },
          set: { newValue in if let newValue { viewModel.setGoal(newValue) } }
        ),
        onContinue: {
          if let goal = viewModel.answers.goal {
            viewModel.captureAnswered(.goal, properties: ["goal": goal.rawValue])
          }
          viewModel.advance()
        }
      )

    case .painPoints:
      OnboardingPainPointsScreen(
        selectedPainPoints: Binding(
          get: { viewModel.answers.painPoints },
          set: { viewModel.answers.painPoints = $0 }
        ),
        onContinue: {
          viewModel.captureAnswered(.painPoints, properties: [
            "count": viewModel.answers.painPoints.count,
            "values": viewModel.answers.painPoints.map(\.rawValue)
          ])
          viewModel.advance()
        }
      )

    case .socialProof:
      OnboardingSocialProofScreen(onContinue: { viewModel.advance() })

    case .swipeStatements:
      OnboardingSwipeStatementsScreen(
        onSwipe: { index, agreed in
          viewModel.recordSwipe(at: index, agreed: agreed)
        },
        onComplete: {
          viewModel.captureAnswered(.swipeStatements, properties: [
            "agreed_count": viewModel.answers.swipeStatementsAgreed.count
          ])
          viewModel.advance()
        }
      )

    case .solution:
      OnboardingSolutionScreen(onContinue: { viewModel.advance() })

    case .comparison:
      OnboardingComparisonScreen(onContinue: { viewModel.advance() })

    case .holdingsPreference:
      OnboardingHoldingsPrefScreen(
        selectedHoldings: Binding(
          get: { viewModel.answers.holdings },
          set: { viewModel.answers.holdings = $0 }
        ),
        onContinue: {
          viewModel.captureAnswered(.holdingsPreference, properties: [
            "count": viewModel.answers.holdings.count,
            "values": viewModel.answers.holdings.map(\.rawValue)
          ])
          viewModel.advance()
        }
      )

    case .spendingPreference:
      OnboardingSpendingPrefScreen(
        selectedLeaks: Binding(
          get: { viewModel.answers.spendingLeaks },
          set: { viewModel.answers.spendingLeaks = $0 }
        ),
        onContinue: {
          viewModel.captureAnswered(.spendingPreference, properties: [
            "count": viewModel.answers.spendingLeaks.count,
            "values": viewModel.answers.spendingLeaks.map(\.rawValue)
          ])
          viewModel.advance()
        }
      )

    case .processing:
      OnboardingProcessingScreen(onComplete: { viewModel.advance() })

    case .demoBuild:
      OnboardingDemoBuildScreen(
        holdingsHint: viewModel.answers.holdings,
        onPick: { viewModel.recordDemoPick($0) },
        onComplete: { picks, usedFallback in
          if usedFallback {
            viewModel.resetDemoPicksAndSeedFallback()
          } else {
            viewModel.answers.demoPicks = picks
          }
          viewModel.captureAnswered(.demoBuild, properties: [
            "picks": viewModel.answers.demoPicks,
            "used_fallback": usedFallback
          ])
          viewModel.advance()
        }
      )

    case .valueReveal:
      OnboardingValueRevealScreen(
        demoPicks: viewModel.answers.demoPicks,
        leakTier: viewModel.answers.leakCalloutTier,
        leakInlinePhrase: viewModel.answers.spendingLeaksInlinePhrase,
        onSavePlan: {
          viewModel.captureAnswered(.valueReveal, properties: [:])
          viewModel.advance()
        }
      )

    case .accountCreation:
      OnboardingAccountCreationScreen(
        demoPicks: viewModel.answers.demoPicks,
        onAuthenticated: {
          viewModel.captureAnswered(.accountCreation, properties: ["method": "auth_success"])
          viewModel.advance()
        },
        onLogInRequested: onLogInRequested
      )

    case .paywall:
      OnboardingQuestionnairePaywallScreen(
        onCompleted: { purchased in
          viewModel.captureCompleted(authenticated: true, purchased: purchased)
          onCompleted()
        }
      )
    }
  }

}

#Preview {
  OnboardingQuestionnaireFlow(onLogInRequested: {}, onCompleted: {})
}
