import XCTest

@testable import financeplan

@MainActor
final class OnboardingQuestionnaireViewModelTests: XCTestCase {
  // MARK: - Step machine

  func testInitialStepIsWelcome() {
    let viewModel = OnboardingQuestionnaireViewModel()
    XCTAssertEqual(viewModel.step, .welcome)
  }

  func testAdvanceMovesToNextStep() {
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.advance()
    XCTAssertEqual(viewModel.step, .goal)
  }

  func testAdvanceStopsAtFinalStep() {
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.transition(to: .paywall)
    viewModel.advance()
    XCTAssertEqual(viewModel.step, .paywall, "advance must clamp at final step")
  }

  func testGoBackMovesToPreviousStep() {
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.transition(to: .painPoints)
    viewModel.goBack()
    XCTAssertEqual(viewModel.step, .goal)
  }

  func testGoBackFromWelcomeIsNoop() {
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.goBack()
    XCTAssertEqual(viewModel.step, .welcome)
  }

  // MARK: - Progress bar visibility

  func testProgressBarHiddenOnWelcome() {
    let viewModel = OnboardingQuestionnaireViewModel()
    XCTAssertFalse(viewModel.progressBarVisible)
  }

  func testProgressBarHiddenOnAccountCreation() {
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.transition(to: .accountCreation)
    XCTAssertFalse(viewModel.progressBarVisible)
  }

  func testProgressBarHiddenOnPaywall() {
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.transition(to: .paywall)
    XCTAssertFalse(viewModel.progressBarVisible)
  }

  func testProgressBarVisibleOnGoal() {
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.transition(to: .goal)
    XCTAssertTrue(viewModel.progressBarVisible)
  }

  func testProgressFractionAdvances() {
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.transition(to: .goal)
    let firstFraction = viewModel.progressFraction
    viewModel.transition(to: .painPoints)
    XCTAssertGreaterThan(viewModel.progressFraction, firstFraction)
  }

  // MARK: - Answer mutators

  func testSetGoalUpdatesAnswers() {
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.setGoal(.trackEverything)
    XCTAssertEqual(viewModel.answers.goal, .trackEverything)
  }

  func testTogglePainPointAddsThenRemoves() {
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.togglePainPoint(.scattered)
    XCTAssertTrue(viewModel.answers.painPoints.contains(.scattered))
    viewModel.togglePainPoint(.scattered)
    XCTAssertFalse(viewModel.answers.painPoints.contains(.scattered))
  }

  func testRecordSwipeStoresAgreementOnly() {
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.recordSwipe(at: 0, agreed: true)
    viewModel.recordSwipe(at: 1, agreed: false)
    viewModel.recordSwipe(at: 2, agreed: true)

    XCTAssertEqual(viewModel.answers.swipeStatementsAgreed, [0, 2])
  }

  func testRecordSwipeUpdatesPriorAgreement() {
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.recordSwipe(at: 0, agreed: true)
    viewModel.recordSwipe(at: 0, agreed: false)
    XCTAssertFalse(viewModel.answers.swipeStatementsAgreed.contains(0))
  }

  func testRecordDemoPickIsIdempotent() {
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.recordDemoPick("AAPL")
    viewModel.recordDemoPick("AAPL")
    viewModel.recordDemoPick("MSFT")
    XCTAssertEqual(viewModel.answers.demoPicks, ["AAPL", "MSFT"])
  }

  func testFallbackSeedsThreeDefaults() {
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.recordDemoPick("NVDA")
    viewModel.resetDemoPicksAndSeedFallback()
    XCTAssertEqual(viewModel.answers.demoPicks, OnboardingDemoTickers.fallbackPicks)
  }

  // MARK: - Leak callout tier (the dynamic copy logic)

  func testLeakTierIsNoneWithoutSelections() {
    var answers = OnboardingQuestionnaireAnswers()
    XCTAssertEqual(answers.leakCalloutTier, .none)
    answers.spendingLeaks = []
    XCTAssertEqual(answers.leakCalloutTier, .none)
  }

  func testLeakTierLowFor1Or2Selections() {
    var answers = OnboardingQuestionnaireAnswers()
    answers.spendingLeaks = [.dining]
    XCTAssertEqual(answers.leakCalloutTier, .low)
    answers.spendingLeaks = [.dining, .subscriptions]
    XCTAssertEqual(answers.leakCalloutTier, .low)
  }

  func testLeakTierMidFor3Or4Selections() {
    var answers = OnboardingQuestionnaireAnswers()
    answers.spendingLeaks = [.dining, .subscriptions, .shopping]
    XCTAssertEqual(answers.leakCalloutTier, .mid)
    answers.spendingLeaks = [.dining, .subscriptions, .shopping, .travel]
    XCTAssertEqual(answers.leakCalloutTier, .mid)
  }

  func testLeakTierHighFor5OrMoreSelections() {
    var answers = OnboardingQuestionnaireAnswers()
    answers.spendingLeaks = Set(OnboardingSpendingLeak.allCases)
    XCTAssertEqual(answers.leakCalloutTier, .high)
  }

  func testLeakTierMonthlyAndImpactMatchTier() {
    var answers = OnboardingQuestionnaireAnswers()
    answers.spendingLeaks = [.dining, .subscriptions, .shopping]
    XCTAssertEqual(answers.leakCalloutTier.monthlyRange, "$200–$400/mo")
    XCTAssertEqual(answers.leakCalloutTier.tenYearImpact, "$30,000–$60,000")
  }

  // MARK: - Inline phrase builder (Screen 11 dynamic copy)

  func testInlinePhraseEmptyWhenNoSelections() {
    let answers = OnboardingQuestionnaireAnswers()
    XCTAssertEqual(answers.spendingLeaksInlinePhrase, "")
  }

  func testInlinePhraseSingleSelection() {
    var answers = OnboardingQuestionnaireAnswers()
    answers.spendingLeaks = [.dining]
    XCTAssertEqual(answers.spendingLeaksInlinePhrase, "dining")
  }

  func testInlinePhraseTwoSelectionsUsesAnd() {
    var answers = OnboardingQuestionnaireAnswers()
    answers.spendingLeaks = [.dining, .subscriptions]
    let phrase = answers.spendingLeaksInlinePhrase
    XCTAssertTrue(phrase.contains("dining"))
    XCTAssertTrue(phrase.contains("subscriptions"))
    XCTAssertTrue(phrase.contains(" and "))
    XCTAssertFalse(phrase.contains(", "))
  }

  func testInlinePhraseThreeSelectionsUsesCommasAndAnd() {
    var answers = OnboardingQuestionnaireAnswers()
    answers.spendingLeaks = [.dining, .subscriptions, .travel]
    let phrase = answers.spendingLeaksInlinePhrase
    XCTAssertTrue(phrase.contains(", "), "three+ items must use comma separator")
    XCTAssertTrue(phrase.contains(" and "), "last item must be joined with 'and'")
  }

  // MARK: - Demo ticker ordering

  func testDemoTickerOrderingPrioritisesETFsWhenIndexFundsPicked() {
    let ordered = OnboardingDemoTickers.ordered(forHoldings: [.indexFunds])
    let firstSymbol = ordered.first?.symbol ?? ""
    XCTAssertTrue(["VTI", "VOO"].contains(firstSymbol), "ETFs must surface first when index funds preferred — got \(firstSymbol)")
  }

  func testDemoTickerOrderingFallsBackToCanonicalOrderWhenNoHint() {
    let ordered = OnboardingDemoTickers.ordered(forHoldings: [])
    XCTAssertEqual(ordered.map(\.symbol), OnboardingDemoTickers.all.map(\.symbol))
  }

  func testFallbackPicksContainsThreeTickers() {
    XCTAssertEqual(OnboardingDemoTickers.fallbackPicks.count, 3)
  }
}
