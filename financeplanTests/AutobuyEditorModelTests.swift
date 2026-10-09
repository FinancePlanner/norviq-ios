import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class AutobuyEditorModelTests: XCTestCase {
  private let english = Locale(identifier: "en_US")

  private func newModel(_ service: MockTerminalPositionsService = MockTerminalPositionsService()) -> AutobuyEditorModel {
    let model = AutobuyEditorModel(currency: "USD", service: service, locale: english)
    model.inputs.label = "Weekly AMZN"
    return model
  }

  func testWeeklyPreviewUsesTheSharedMonthlyEquivalent() async {
    let model = newModel()
    model.inputs.cadence = .weekly
    model.inputs.amount = TerminalNumberInput(text: "50")

    XCTAssertEqual(model.monthlyEquivalent ?? 0, 50 * 52 / 12, accuracy: 0.000001)
    XCTAssertTrue(model.canSave)
  }

  func testBimonthlyIsEveryTwoMonths() async {
    let model = newModel()
    model.inputs.cadence = .bimonthly
    model.inputs.amount = TerminalNumberInput(text: "275")

    XCTAssertEqual(model.monthlyEquivalent ?? 0, 275 * 6 / 12, accuracy: 0.000001)
  }

  func testPercentCadenceNeedsAPercentAndUsesTheMonthlyBase() async {
    let service = MockTerminalPositionsService()
    let model = newModel(service)
    model.inputs.cadence = .percentOfContribution
    model.inputs.amount = TerminalNumberInput(text: "5000")

    XCTAssertFalse(model.canSave)
    XCTAssertNil(model.percentProblem, "an empty percent is not an error yet, just not saveable")

    model.inputs.percent = TerminalNumberInput(text: "4")
    XCTAssertEqual(model.monthlyEquivalent ?? 0, 200, accuracy: 0.000001)
    XCTAssertTrue(model.canSave)

    _ = await model.save()
    XCTAssertEqual(service.createAutobuyRequests, [AutobuyCreateRequest(
      ticker: nil, label: "Weekly AMZN", amount: 5_000, cadence: .percentOfContribution, percent: 0.04, active: true
    )])
  }

  func testPercentAboveOneHundredIsRefused() async {
    let model = newModel()
    model.inputs.cadence = .percentOfContribution
    model.inputs.amount = TerminalNumberInput(text: "5000")
    model.inputs.percent = TerminalNumberInput(text: "150")

    XCTAssertEqual(model.percentProblem, "Enter a percent between 0 and 100.")
    XCTAssertFalse(model.canSave)
  }

  func testNoMonthlyBaseMeansNoMonthlyEquivalent() async {
    let model = newModel()
    model.inputs.cadence = .percentOfContribution
    model.inputs.amount = TerminalNumberInput(text: "0")
    model.inputs.percent = TerminalNumberInput(text: "4")

    XCTAssertNil(model.monthlyEquivalent)
  }

  func testLabelIsRequiredAndNegativeAmountsAreRefused() async {
    let model = AutobuyEditorModel(currency: "USD", service: MockTerminalPositionsService(), locale: english)
    model.inputs.amount = TerminalNumberInput(text: "50")
    XCTAssertFalse(model.canSave)

    model.inputs.label = "DCA"
    model.inputs.amount = TerminalNumberInput(text: "-50")
    XCTAssertEqual(model.amountProblem, "Can't be negative.")
    XCTAssertFalse(model.canSave)
  }

  func testCreateUppercasesTheTickerAndLeavesAnEmptyOneOut() async {
    let service = MockTerminalPositionsService()
    let model = newModel(service)
    model.inputs.ticker = " amzn "
    model.inputs.amount = TerminalNumberInput(text: "50")
    model.inputs.cadence = .weekly

    _ = await model.save()

    XCTAssertEqual(service.createAutobuyRequests.first?.ticker, "AMZN")
    XCTAssertNil(service.createAutobuyRequests.first?.percent)
  }

  func testSwitchingAwayFromPercentClearsIt() async {
    let service = MockTerminalPositionsService()
    let model = AutobuyEditorModel(autobuy: .fixture(), currency: "USD", service: service, locale: english)
    model.inputs.cadence = .monthly

    _ = await model.save()

    XCTAssertEqual(service.updateAutobuyIds, ["a1"])
    XCTAssertEqual(service.updateAutobuyRequests, [AutobuyUpdateRequest(
      ticker: nil, label: nil, amount: nil, cadence: .monthly, percent: nil, active: nil, clear: ["percent"]
    )])
  }

  func testEmptyingTheTickerClearsIt() async {
    let service = MockTerminalPositionsService()
    let model = AutobuyEditorModel(
      autobuy: .fixture(ticker: "VOO", amount: 50, cadence: .weekly, percent: nil),
      currency: "USD", service: service, locale: english
    )
    model.inputs.ticker = ""

    _ = await model.save()

    XCTAssertEqual(service.updateAutobuyRequests, [AutobuyUpdateRequest(
      ticker: nil, label: nil, amount: nil, cadence: nil, percent: nil, active: nil, clear: ["ticker"]
    )])
  }

  func testUnchangedAutobuySavesWithoutARequest() async {
    let service = MockTerminalPositionsService()
    let autobuy = AutobuyResponse.fixture()
    let model = AutobuyEditorModel(autobuy: autobuy, currency: "USD", service: service, locale: english)

    let saved = await model.save()

    XCTAssertEqual(saved, autobuy)
    XCTAssertTrue(service.updateAutobuyRequests.isEmpty)
  }

  func testDeletingAnAutobuyReloadsTheTotal() async {
    let service = MockTerminalPositionsService()
    service.autobuysResult = .success(.fixture([.fixture(id: "a1"), .fixture(id: "a2", amount: 50, cadence: .weekly, percent: nil)]))
    let model = TerminalPositionsViewModel(
      service: service,
      defaults: UserDefaults(suiteName: "AutobuyEditorModelTests-\(UUID().uuidString)")!
    )
    await model.load()
    service.autobuysResult = .success(.fixture([.fixture(id: "a2", amount: 50, cadence: .weekly, percent: nil)]))

    await model.deleteAutobuy(model.autobuys[0])

    XCTAssertEqual(service.deletedAutobuyIds, ["a1"])
    XCTAssertEqual(model.autobuys.map(\.id), ["a2"])
    XCTAssertEqual(model.monthlyAutobuyTotal, 50 * 52 / 12, accuracy: 0.000001)
  }

  func testCreateNotFoundSaysUnavailableNotDeleted() async {
    let service = MockTerminalPositionsService()
    service.createAutobuyResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 404, message: "Not Found"))
    let model = newModel(service)
    model.inputs.amount = TerminalNumberInput(text: "100")

    let saved = await model.save()

    XCTAssertNil(saved)
    XCTAssertEqual(model.errorMessage, "Autobuys are unavailable right now.")
  }

  func testEditNotFoundStillSaysDeletedOnAnotherDevice() async {
    let service = MockTerminalPositionsService()
    service.updateAutobuyResult = .failure(TerminalPositionsHTTPClient.Error.rejected(status: 404, message: "Not Found"))
    let model = AutobuyEditorModel(autobuy: .fixture(), currency: "USD", service: service, locale: english)
    model.inputs.label = "Renamed"

    _ = await model.save()

    XCTAssertEqual(model.errorMessage, "This autobuy was deleted on another device.")
  }

  func testPercentOfZeroIsRefused() async {
    let model = newModel()
    model.inputs.cadence = .percentOfContribution
    model.inputs.amount = TerminalNumberInput(text: "5000")
    model.inputs.percent = TerminalNumberInput(text: "0")

    XCTAssertEqual(model.percentProblem, "Enter a percent between 0 and 100.")
    XCTAssertFalse(model.canSave)

    model.inputs.percent = TerminalNumberInput(text: "100")
    XCTAssertNil(model.percentProblem)
    XCTAssertTrue(model.canSave)
  }

  func testLabelOverEightyCharactersIsRefused() async {
    let model = newModel()
    model.inputs.amount = TerminalNumberInput(text: "100")
    model.inputs.label = String(repeating: "a", count: 80)
    XCTAssertNil(model.labelProblem)
    XCTAssertTrue(model.canSave)

    model.inputs.label = String(repeating: "a", count: 81)
    XCTAssertEqual(model.labelProblem, "Use 80 characters or fewer.")
    XCTAssertFalse(model.canSave)
  }
}
