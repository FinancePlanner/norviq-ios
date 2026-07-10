import Foundation
import Observation
import OSLog
import PostHog

@Observable @MainActor
final class OnboardingQuestionnaireViewModel {
  enum Step: Int, CaseIterable {
    case welcome = 0
    case goal
    case painPoints
    case socialProof
    case swipeStatements
    case solution
    case comparison
    case holdingsPreference
    case spendingPreference
    case processing
    case demoBuild
    case valueReveal
    case accountCreation
    case paywall
  }

  enum NavigationDirection {
    case forward
    case backward
  }

  private(set) var step: Step = .welcome
  /// Which way the last step change moved, so the flow can mirror its
  /// slide transition when navigating back (spatial consistency).
  private(set) var navigationDirection: NavigationDirection = .forward
  var answers = OnboardingQuestionnaireAnswers()

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "OnboardingQuestionnaire"
  )

  /// Steps that show the progress bar at the top. Welcome / account creation / paywall hide it.
  static let progressBarSteps: [Step] = [
    .goal, .painPoints, .socialProof, .swipeStatements, .solution, .comparison,
    .holdingsPreference, .spendingPreference, .processing, .demoBuild, .valueReveal
  ]

  var progressBarVisible: Bool {
    Self.progressBarSteps.contains(step)
  }

  /// 0–1 fraction for the progress bar.
  var progressFraction: Double {
    guard let index = Self.progressBarSteps.firstIndex(of: step) else { return 0 }
    return Double(index + 1) / Double(Self.progressBarSteps.count)
  }

  func advance() {
    guard let next = Step(rawValue: step.rawValue + 1) else { return }
    transition(to: next)
  }

  func goBack() {
    guard let previous = Step(rawValue: step.rawValue - 1), previous.rawValue >= 0 else { return }
    transition(to: previous)
  }

  func transition(to next: Step) {
    let previous = step
    navigationDirection = next.rawValue >= previous.rawValue ? .forward : .backward
    step = next
    Self.logger.info("step.transition from=\(previous.analyticsName, privacy: .public) to=\(next.analyticsName, privacy: .public)")
    captureScreenViewed(next)
  }

  // MARK: - Answer mutators

  func setGoal(_ goal: OnboardingGoal) {
    answers.goal = goal
  }

  func togglePainPoint(_ pain: OnboardingPainPoint) {
    if answers.painPoints.contains(pain) {
      answers.painPoints.remove(pain)
    } else {
      answers.painPoints.insert(pain)
    }
  }

  func recordSwipe(at index: Int, agreed: Bool) {
    if agreed {
      answers.swipeStatementsAgreed.insert(index)
    } else {
      answers.swipeStatementsAgreed.remove(index)
    }
  }

  func toggleHolding(_ holding: OnboardingHoldingType) {
    if answers.holdings.contains(holding) {
      answers.holdings.remove(holding)
    } else {
      answers.holdings.insert(holding)
    }
  }

  func toggleSpendingLeak(_ leak: OnboardingSpendingLeak) {
    if answers.spendingLeaks.contains(leak) {
      answers.spendingLeaks.remove(leak)
    } else {
      answers.spendingLeaks.insert(leak)
    }
  }

  func recordDemoPick(_ symbol: String) {
    guard !answers.demoPicks.contains(symbol) else { return }
    answers.demoPicks.append(symbol)
  }

  func resetDemoPicksAndSeedFallback() {
    answers.demoPicks = OnboardingDemoTickers.fallbackPicks
  }

  // MARK: - Analytics

  private func captureScreenViewed(_ step: Step) {
    PostHogSDK.shared.capture(
      "onboarding.viewed",
      properties: ["step": step.analyticsName]
    )
  }

  func captureAnswered(_ step: Step, properties: [String: Any] = [:]) {
    var combined: [String: Any] = ["step": step.analyticsName]
    combined.merge(properties) { _, new in new }
    PostHogSDK.shared.capture("onboarding.answered", properties: combined)
  }

  func captureCompleted(authenticated: Bool, purchased: Bool) {
    PostHogSDK.shared.capture(
      "onboarding.completed",
      properties: [
        "authenticated": authenticated,
        "purchased": purchased,
        "goal": answers.goal?.rawValue ?? "skipped",
        "pain_count": answers.painPoints.count,
        "swipe_yes_count": answers.swipeStatementsAgreed.count,
        "holdings_count": answers.holdings.count,
        "leak_count": answers.spendingLeaks.count,
        "demo_picks": answers.demoPicks
      ]
    )
  }
}

extension OnboardingQuestionnaireViewModel.Step {
  var analyticsName: String {
    switch self {
    case .welcome: "welcome"
    case .goal: "goal"
    case .painPoints: "pain_points"
    case .socialProof: "social_proof"
    case .swipeStatements: "swipe_statements"
    case .solution: "solution"
    case .comparison: "comparison"
    case .holdingsPreference: "holdings_preference"
    case .spendingPreference: "spending_preference"
    case .processing: "processing"
    case .demoBuild: "demo_build"
    case .valueReveal: "value_reveal"
    case .accountCreation: "account_creation"
    case .paywall: "paywall"
    }
  }
}
