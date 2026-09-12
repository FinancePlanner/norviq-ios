import XCTest
@testable import financeplan

@MainActor
final class OnboardingQuestionnaireViewModelTests: XCTestCase {

  // MARK: - Step machine

  func testInitialStepIsWelcome() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    XCTAssertEqual(viewModel.step, .welcome)
  }

  func testAdvanceMovesToNextStep() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.advance()
    XCTAssertEqual(viewModel.step, .goal)
  }

  func testAdvanceStopsAtFinalStep() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.transition(to: .paywall)
    viewModel.advance()
    XCTAssertEqual(viewModel.step, .paywall, "advance must clamp at final step")
  }

  func testGoBackMovesToPreviousStep() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.transition(to: .painPoints)
    viewModel.goBack()
    XCTAssertEqual(viewModel.step, .goal)
  }

  func testGoBackFromWelcomeIsNoop() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.goBack()
    XCTAssertEqual(viewModel.step, .welcome)
  }

  // MARK: - Progress bar visibility

  func testProgressBarHiddenOnWelcome() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    XCTAssertFalse(viewModel.progressBarVisible)
  }

  func testProgressBarHiddenOnAccountCreation() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.transition(to: .accountCreation)
    XCTAssertFalse(viewModel.progressBarVisible)
  }

  func testProgressBarHiddenOnPaywall() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.transition(to: .paywall)
    XCTAssertFalse(viewModel.progressBarVisible)
  }

  func testProgressBarVisibleOnGoal() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.transition(to: .goal)
    XCTAssertTrue(viewModel.progressBarVisible)
  }

  func testProgressFractionAdvances() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.transition(to: .goal)
    let firstFraction = viewModel.progressFraction
    viewModel.transition(to: .painPoints)
    XCTAssertGreaterThan(viewModel.progressFraction, firstFraction)
  }

  // MARK: - Answer mutators

  func testSetGoalUpdatesAnswers() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.setGoal(.trackEverything)
    XCTAssertEqual(viewModel.answers.goal, .trackEverything)
  }

  func testTogglePainPointAddsThenRemoves() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.togglePainPoint(.scattered)
    XCTAssertTrue(viewModel.answers.painPoints.contains(.scattered))
    viewModel.togglePainPoint(.scattered)
    XCTAssertFalse(viewModel.answers.painPoints.contains(.scattered))
  }

  func testRecordSwipeStoresAgreementOnly() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.recordSwipe(at: 0, agreed: true)
    viewModel.recordSwipe(at: 1, agreed: false)
    viewModel.recordSwipe(at: 2, agreed: true)

    XCTAssertEqual(viewModel.answers.swipeStatementsAgreed, [0, 2])
  }

  func testRecordSwipeUpdatesPriorAgreement() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.recordSwipe(at: 0, agreed: true)
    viewModel.recordSwipe(at: 0, agreed: false)
    XCTAssertFalse(viewModel.answers.swipeStatementsAgreed.contains(0))
  }

  func testRecordDemoPickIsIdempotent() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.recordDemoPick("AAPL")
    viewModel.recordDemoPick("AAPL")
    viewModel.recordDemoPick("MSFT")
    XCTAssertEqual(viewModel.answers.demoPicks, ["AAPL", "MSFT"])
  }

  func testFallbackSeedsThreeDefaults() async {
    await Task.yield()
    let viewModel = OnboardingQuestionnaireViewModel()
    viewModel.recordDemoPick("NVDA")
    viewModel.resetDemoPicksAndSeedFallback()
    XCTAssertEqual(viewModel.answers.demoPicks, OnboardingDemoTickers.fallbackPicks)
  }

  // MARK: - Leak callout tier (the dynamic copy logic)

  func testLeakTierIsNoneWithoutSelections() async {
    await Task.yield()
    var answers = OnboardingQuestionnaireAnswers()
    XCTAssertEqual(answers.leakCalloutTier, .none)
    answers.spendingLeaks = []
    XCTAssertEqual(answers.leakCalloutTier, .none)
  }

  func testLeakTierLowFor1Or2Selections() async {
    await Task.yield()
    var answers = OnboardingQuestionnaireAnswers()
    answers.spendingLeaks = [.dining]
    XCTAssertEqual(answers.leakCalloutTier, .low)
    answers.spendingLeaks = [.dining, .subscriptions]
    XCTAssertEqual(answers.leakCalloutTier, .low)
  }

  func testLeakTierMidFor3Or4Selections() async {
    await Task.yield()
    var answers = OnboardingQuestionnaireAnswers()
    answers.spendingLeaks = [.dining, .subscriptions, .shopping]
    XCTAssertEqual(answers.leakCalloutTier, .mid)
    answers.spendingLeaks = [.dining, .subscriptions, .shopping, .travel]
    XCTAssertEqual(answers.leakCalloutTier, .mid)
  }

  func testLeakTierHighFor5OrMoreSelections() async {
    await Task.yield()
    var answers = OnboardingQuestionnaireAnswers()
    answers.spendingLeaks = Set(OnboardingSpendingLeak.allCases)
    XCTAssertEqual(answers.leakCalloutTier, .high)
  }

  func testLeakTierMonthlyAndImpactMatchTier() async {
    await Task.yield()
    var answers = OnboardingQuestionnaireAnswers()
    answers.spendingLeaks = [.dining, .subscriptions, .shopping]
    XCTAssertEqual(answers.leakCalloutTier.monthlyRange, "$200–$400/mo")
    XCTAssertEqual(answers.leakCalloutTier.tenYearImpact, "$30,000–$60,000")
  }

  // MARK: - Inline phrase builder (Screen 11 dynamic copy)

  func testInlinePhraseEmptyWhenNoSelections() async {
    await Task.yield()
    let answers = OnboardingQuestionnaireAnswers()
    XCTAssertEqual(answers.spendingLeaksInlinePhrase, "")
  }

  func testInlinePhraseSingleSelection() async {
    await Task.yield()
    var answers = OnboardingQuestionnaireAnswers()
    answers.spendingLeaks = [.dining]
    XCTAssertEqual(answers.spendingLeaksInlinePhrase, "dining")
  }

  func testInlinePhraseTwoSelectionsUsesAnd() async {
    await Task.yield()
    var answers = OnboardingQuestionnaireAnswers()
    answers.spendingLeaks = [.dining, .subscriptions]
    let phrase = answers.spendingLeaksInlinePhrase
    XCTAssertTrue(phrase.contains("dining"))
    XCTAssertTrue(phrase.contains("subscriptions"))
    XCTAssertTrue(phrase.contains(" and "))
    XCTAssertFalse(phrase.contains(", "))
  }

  func testInlinePhraseThreeSelectionsUsesCommasAndAnd() async {
    await Task.yield()
    var answers = OnboardingQuestionnaireAnswers()
    answers.spendingLeaks = [.dining, .subscriptions, .travel]
    let phrase = answers.spendingLeaksInlinePhrase
    XCTAssertTrue(phrase.contains(", "), "three+ items must use comma separator")
    XCTAssertTrue(phrase.contains(" and "), "last item must be joined with 'and'")
  }

  // MARK: - Demo ticker ordering

  func testDemoTickerOrderingPrioritisesETFsWhenIndexFundsPicked() async {
    await Task.yield()
    let ordered = OnboardingDemoTickers.ordered(forHoldings: [.indexFunds])
    let firstSymbol = ordered.first?.symbol ?? ""
    XCTAssertTrue(
      ["VTI", "VOO"].contains(firstSymbol),
      "ETFs must surface first when index funds preferred — got \(firstSymbol)"
    )
  }

  func testDemoTickerOrderingFallsBackToCanonicalOrderWhenNoHint() async {
    await Task.yield()
    let ordered = OnboardingDemoTickers.ordered(forHoldings: [])
    XCTAssertEqual(ordered.map(\.symbol), OnboardingDemoTickers.all.map(\.symbol))
  }

  func testFallbackPicksContainsThreeTickers() async {
    await Task.yield()
    XCTAssertEqual(OnboardingDemoTickers.fallbackPicks.count, 3)
  }
}
