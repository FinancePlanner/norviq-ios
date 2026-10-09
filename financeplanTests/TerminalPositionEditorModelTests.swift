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
}
