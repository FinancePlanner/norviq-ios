import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class TerminalPositionEditorModelTests: XCTestCase {
  private let english = Locale(identifier: "en_US")
  private let portuguese = Locale(identifier: "pt_PT")

  private func filledModel(
    _ service: MockTerminalPositionsService = MockTerminalPositionsService(),
    locale: Locale? = nil
  ) -> TerminalPositionEditorModel {
    let model = TerminalPositionEditorModel(ticker: "amzn ", currency: "USD", service: service, locale: locale ?? english)
    model.inputs.terminalShareCount = TerminalNumberInput(text: "11", unit: .billion)
    model.inputs.terminalMarketCap = TerminalNumberInput(text: "10", unit: .trillion)
    model.inputs.valueWanted = TerminalNumberInput(text: "1", unit: .million)
    model.inputs.sharesOwned = TerminalNumberInput(text: "750")
    return model
  }

  func testNewPositionPrefillsTheTickerAndHasNoPreview() async {
    let model = TerminalPositionEditorModel(ticker: "amzn", currency: "USD", service: MockTerminalPositionsService(), locale: english)

    XCTAssertEqual(model.inputs.ticker, "AMZN")
    XCTAssertNil(model.preview)
    XCTAssertFalse(model.canSave)
    XCTAssertFalse(model.isEditing)
  }

  func testLivePreviewMatchesTheAMZNWorkedExample() async {
    let model = filledModel()

    let result = model.previewResult
    XCTAssertEqual(result?.terminalSharePrice ?? 0, 909.0909, accuracy: 0.0001)
    XCTAssertEqual(result?.sharesNeeded ?? 0, 1_100, accuracy: 0.000001)
    XCTAssertEqual(result?.progress ?? 0, 0.681818, accuracy: 0.000001)
    XCTAssertNil(result?.capitalAtTodayPrice)
    XCTAssertTrue(model.canSave)
  }

  func testPortugueseCommaInputIsReadAsADecimal() async {
    let model = filledModel(locale: portuguese)
    model.inputs.terminalMarketCap = TerminalNumberInput(text: "1,5", unit: .trillion)
    model.inputs.valueWanted = TerminalNumberInput(text: "2,5", unit: .million)

    XCTAssertEqual(model.makeCreateRequest()?.terminalMarketCap, 1_500_000_000_000)
    XCTAssertEqual(model.makeCreateRequest()?.valueWanted, 2_500_000)
  }

  func testZeroShareCountShowsTheGuardrailAndBlocksSave() async {
    let model = filledModel()
    model.inputs.terminalShareCount = TerminalNumberInput(text: "0")

    XCTAssertEqual(model.problem(for: .terminalShareCount), "Share count must be above zero.")
    XCTAssertEqual(model.preview, .failure(.shareCountNotPositive))
    XCTAssertFalse(model.canSave)
  }

  func testZeroMarketCapShowsTheGuardrail() async {
    let model = filledModel()
    model.inputs.terminalMarketCap = TerminalNumberInput(text: "0", unit: .trillion)

    XCTAssertEqual(model.problem(for: .terminalMarketCap), "Market cap must be above zero.")
    XCTAssertEqual(model.preview, .failure(.marketCapNotPositive))
  }

  func testTypedMinusIsRefusedNotFlipped() async {
    let model = filledModel()
    model.inputs.valueWanted = TerminalNumberInput(text: "-100")

    XCTAssertEqual(model.problem(for: .valueWanted), "Can't be negative.")
    XCTAssertNil(model.preview)
    XCTAssertFalse(model.canSave)
  }

  func testInvalidTickerBlocksSave() async {
    let model = filledModel()
    model.inputs.ticker = "AMZN!"

    XCTAssertEqual(model.problem(for: .ticker), "Use 1–12 letters, digits, dots or dashes.")
    XCTAssertFalse(model.canSave)
  }

  func testCreateSendsParsedValuesAndLeavesEmptyOptionalsOut() async {
    let service = MockTerminalPositionsService()
    let model = filledModel(service)

    let saved = await model.save()

    XCTAssertEqual(saved?.id, "created")
    XCTAssertEqual(service.createRequests, [TerminalPositionCreateRequest(
      ticker: "AMZN", sharesOutstanding: nil, terminalShareCount: 11_000_000_000,
      terminalMarketCap: 10_000_000_000_000, valueWanted: 1_000_000, sharesOwned: 750,
      currentSharePrice: nil, notes: nil
    )])
  }

  func testEditingSendsOnlyChangedFieldsAndClearsEmptiedOptionals() async {
    let service = MockTerminalPositionsService()
    let original = TerminalPositionResponse.fixture(currentSharePrice: 200, sharesOutstanding: 10_600_000_000, notes: "old")
    let model = TerminalPositionEditorModel(position: original, currency: "USD", service: service, locale: english)
    model.inputs.valueWanted = TerminalNumberInput(text: "2", unit: .million)
    model.inputs.currentSharePrice = TerminalNumberInput()
    model.inputs.notes = "  "

    _ = await model.save()

    XCTAssertEqual(service.updateIds, ["p1"])
    XCTAssertEqual(service.updateRequests, [TerminalPositionUpdateRequest(
      ticker: nil, sharesOutstanding: nil, terminalShareCount: nil, terminalMarketCap: nil,
      valueWanted: 2_000_000, sharesOwned: nil, currentSharePrice: nil, notes: nil,
      clear: ["currentSharePrice", "notes"]
    )])
  }

  func testUnchangedEditSavesWithoutARequest() async {
    let service = MockTerminalPositionsService()
    let original = TerminalPositionResponse.fixture(sharesOwned: 750)
    let model = TerminalPositionEditorModel(position: original, currency: "USD", service: service, locale: english)

    let saved = await model.save()

    XCTAssertEqual(saved, original)
    XCTAssertTrue(service.updateRequests.isEmpty)
  }

  func testUnchangedEditInPortugueseSendsNothing() async {
    let service = MockTerminalPositionsService()
    let original = TerminalPositionResponse.fixture(valueWanted: 1_234_567.891, currentSharePrice: 220.123)
    let model = TerminalPositionEditorModel(position: original, currency: "EUR", service: service, locale: portuguese)

    XCTAssertTrue(model.canSave)
    _ = await model.save()

    XCTAssertTrue(service.updateRequests.isEmpty)
  }

  func testServerReasonIsShownOn422() async {
    let service = MockTerminalPositionsService()
    service.createResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 422, message: "Ticker is invalid"))
    let model = filledModel(service)

    let saved = await model.save()

    XCTAssertNil(saved)
    XCTAssertEqual(model.errorMessage, "Ticker is invalid")
  }

  func testRowErrorTextReadsTheRawScenarioError() async {
    XCTAssertEqual(
      TerminalPositionEditorModel.text(forRaw: "share_count_not_positive"),
      "Share count must be above zero."
    )
    XCTAssertEqual(
      TerminalPositionEditorModel.text(forRaw: "something_new"),
      "This scenario needs a positive share count and market cap."
    )
  }

  func testFillWithAINeedsATicker() async {
    let service = MockTerminalPositionsService()
    let model = TerminalPositionEditorModel(currency: "USD", service: service, locale: english)

    await model.fillWithAI()

    XCTAssertEqual(model.aiMessage, "Enter a ticker first.")
    XCTAssertTrue(service.shareFactsTickers.isEmpty)
  }

  func testFillWithAIShowsTheSuggestionWithoutTouchingTheForm() async {
    let service = MockTerminalPositionsService()
    let model = filledModel(service)
    let before = model.inputs

    await model.fillWithAI()

    XCTAssertEqual(service.shareFactsTickers, ["AMZN"])
    XCTAssertEqual(model.shareFacts, .fixture())
    XCTAssertEqual(model.inputs, before)
  }

  func testAcceptingShareFactsFillsOnlySharesOutstandingAndPriceAndNeverSaves() async {
    let service = MockTerminalPositionsService()
    let model = filledModel(service)
    let marketCapBefore = model.inputs.terminalMarketCap
    let valueWantedBefore = model.inputs.valueWanted
    await model.fillWithAI()

    model.acceptShareFacts()

    XCTAssertEqual(model.inputs.sharesOutstanding.value(locale: english), 10_600_000_000)
    XCTAssertEqual(model.inputs.currentSharePrice.value(locale: english), 220.5)
    XCTAssertEqual(model.inputs.terminalMarketCap, marketCapBefore)
    XCTAssertEqual(model.inputs.valueWanted, valueWantedBefore)
    XCTAssertNil(model.shareFacts)
    XCTAssertTrue(service.createRequests.isEmpty)
    XCTAssertTrue(service.updateRequests.isEmpty)
  }

  func testAcceptingAScenarioFillsShareCountAndMarketCapOnly() async {
    let service = MockTerminalPositionsService()
    let model = filledModel(service)
    let valueWantedBefore = model.inputs.valueWanted
    await model.suggestScenario()

    model.acceptScenario()

    XCTAssertEqual(service.scenarioTickers, ["AMZN"])
    XCTAssertEqual(model.inputs.terminalShareCount.value(locale: english), 12_000_000_000)
    XCTAssertEqual(model.inputs.terminalMarketCap.value(locale: english), 8_000_000_000_000)
    XCTAssertEqual(model.inputs.valueWanted, valueWantedBefore)
    XCTAssertNil(model.scenarioSuggestion)
    XCTAssertTrue(service.createRequests.isEmpty)
  }

  func testUpgradeRequiredAsksForThePaywall() async {
    let service = MockTerminalPositionsService()
    service.shareFactsResult = .failure(TerminalPositionsHTTPClient.Error.upgradeRequired(feature: "terminal_position_ai"))
    let model = filledModel(service)

    await model.fillWithAI()

    XCTAssertTrue(model.needsUpgrade)
    XCTAssertNil(model.aiMessage)
  }

  func testPlainForbiddenDoesNotAskForThePaywall() async {
    let service = MockTerminalPositionsService()
    service.scenarioResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 403, message: "Missing scope"))
    let model = filledModel(service)

    await model.suggestScenario()

    XCTAssertFalse(model.needsUpgrade)
    XCTAssertEqual(model.aiMessage, "The AI lookup failed. Try again.")
  }

  func testAIUnavailableSaysManualEntryStillWorks() async {
    let service = MockTerminalPositionsService()
    service.shareFactsResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 503, message: "AI lookup unavailable"))
    let model = filledModel(service)

    await model.fillWithAI()

    XCTAssertEqual(model.aiMessage, "AI lookup is unavailable right now. You can still enter the numbers yourself.")
  }

  func testUnusableAIAnswerIsExplained() async {
    let service = MockTerminalPositionsService()
    service.scenarioResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 422, message: "no sources"))
    let model = filledModel(service)

    await model.suggestScenario()

    XCTAssertEqual(model.aiMessage, "The AI couldn't find usable numbers for this ticker.")
  }

  func testCurrencyMismatchIsCalledOut() async {
    let service = MockTerminalPositionsService()
    service.shareFactsResult = .success(.fixture(currency: "eur"))
    let model = filledModel(service)

    await model.fillWithAI()

    XCTAssertEqual(model.shareFactsCurrencyNote, "This price is in EUR; your plan uses USD.")
  }

  func testCreateNotFoundSaysUnavailableNotDeleted() async {
    let service = MockTerminalPositionsService()
    service.createResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 404, message: "Not Found"))
    let model = filledModel(service)

    let saved = await model.save()

    XCTAssertNil(saved)
    XCTAssertEqual(model.errorMessage, "Terminal positions are unavailable right now.")
  }

  func testEditNotFoundStillSaysDeletedOnAnotherDevice() async {
    let service = MockTerminalPositionsService()
    service.updateResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 404, message: "Not Found"))
    let model = TerminalPositionEditorModel(position: .fixture(), currency: "USD", service: service, locale: english)
    model.inputs.valueWanted = TerminalNumberInput(text: "2", unit: .million)

    _ = await model.save()

    XCTAssertEqual(model.errorMessage, "This row was deleted on another device.")
  }

  func testSharesOutstandingAndPriceMustBeAboveZeroWhenPresent() async {
    let model = filledModel()
    model.inputs.sharesOutstanding = TerminalNumberInput(text: "0", unit: .billion)
    XCTAssertEqual(model.problem(for: .sharesOutstanding), "Must be above zero.")
    XCTAssertFalse(model.canSave)

    model.inputs.sharesOutstanding = TerminalNumberInput(text: "10", unit: .billion)
    XCTAssertNil(model.problem(for: .sharesOutstanding))
    XCTAssertTrue(model.canSave)

    model.inputs.currentSharePrice = TerminalNumberInput(text: "0")
    XCTAssertEqual(model.problem(for: .currentSharePrice), "Must be above zero.")
    XCTAssertFalse(model.canSave)

    model.inputs.currentSharePrice = TerminalNumberInput(text: "")
    XCTAssertNil(model.problem(for: .currentSharePrice))
    XCTAssertTrue(model.canSave)
  }

  func testNotesOverOneThousandCharactersBlockSave() async {
    let model = filledModel()
    model.inputs.notes = String(repeating: "a", count: 1_000)
    XCTAssertNil(model.notesProblem)
    XCTAssertTrue(model.canSave)

    model.inputs.notes = String(repeating: "a", count: 1_001)
    XCTAssertEqual(model.notesProblem, "Use 1,000 characters or fewer.")
    XCTAssertFalse(model.canSave)
  }

  func testFailedRefetchLeavesNoStaleShareFactsCard() async {
    let service = MockTerminalPositionsService()
    let model = filledModel(service)
    await model.fillWithAI()
    XCTAssertNotNil(model.shareFacts)

    service.shareFactsResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 503, message: nil))
    await model.fillWithAI()

    XCTAssertNil(model.shareFacts)
  }

  func testFailedRescenarioLeavesNoStaleSuggestion() async {
    let service = MockTerminalPositionsService()
    let model = filledModel(service)
    await model.suggestScenario()
    XCTAssertNotNil(model.scenarioSuggestion)

    service.scenarioResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 503, message: nil))
    await model.suggestScenario()

    XCTAssertNil(model.scenarioSuggestion)
  }

  func testAcceptingAfterTheTickerChangedDoesNothing() async {
    let model = filledModel()
    await model.fillWithAI()
    await model.suggestScenario()
    model.inputs.ticker = "NVDA"
    let before = model.inputs

    model.acceptShareFacts()
    model.acceptScenario()

    XCTAssertEqual(model.inputs, before)
    XCTAssertNil(model.shareFacts)
    XCTAssertNil(model.scenarioSuggestion)
  }
}
