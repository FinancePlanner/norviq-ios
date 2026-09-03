import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

/// The filing pack sheet's state machine: the preview JSON becomes `.loaded`,
/// each HTTP status the backend uses for "not yet" maps to its own state, and
/// generate queues a report without touching the preview.
@MainActor
final class TaxFilingPackViewModelTests: XCTestCase {
  func testLoad_DecodesPreviewJSONIntoLoadedState() async throws {
    let service = FilingPackServiceMock()
    service.previewResult = .success(try Self.decodePreview())
    let model = TaxFilingPackViewModel(service: service, taxYear: 2025)

    await model.load()

    guard case let .loaded(preview) = model.state else {
      return XCTFail("expected .loaded, got \(model.state)")
    }
    XCTAssertEqual(preview.disposalCount, 1)
    XCTAssertEqual(preview.dividendCount, 1)
    XCTAssertEqual(preview.unsupportedCount, 0)
    XCTAssertEqual(preview.jurisdiction, .portugal)
    XCTAssertEqual(preview.rulePackVersion, "PT-2026.2")
    XCTAssertEqual(preview.summary["totalGain"], Decimal(string: "453.64"))
    XCTAssertEqual(preview.sections.first?.id, "anexo-j-9.2A")
    XCTAssertEqual(preview.sections.first?.rows.first, ["G01", "840", "2025", "09", "1362.73", "2025", "02", "909.09", "0.91"])
    XCTAssertEqual(service.previewTaxYears, [2025])
  }

  func testLoad_MapsHTTPStatusesToStates() async {
    let cases: [(status: Int, expected: TaxFilingPackViewModel.State)] = [
      (402, .paywalled),
      (403, .paywalled),
      (409, .profileIncomplete),
      (422, .unsupported("The filing pack is not available for your jurisdiction yet.")),
      (500, .failed("The server returned 500.")),
    ]
    for testCase in cases {
      let service = FilingPackServiceMock()
      service.previewResult = .failure(TaxServiceError.http(statusCode: testCase.status, message: nil))
      let model = TaxFilingPackViewModel(service: service, taxYear: 2025)

      await model.load()

      XCTAssertEqual(model.state, testCase.expected, "status \(testCase.status)")
    }
  }

  func testLoad_NonHTTPErrorBecomesFailed() async {
    let service = FilingPackServiceMock()
    service.previewResult = .failure(URLError(.notConnectedToInternet))
    let model = TaxFilingPackViewModel(service: service, taxYear: 2025)

    await model.load()

    guard case .failed = model.state else {
      return XCTFail("expected .failed, got \(model.state)")
    }
  }

  func testGenerate_QueuesAnnualFilingPackForTheSelectedYear() async throws {
    let service = FilingPackServiceMock()
    service.previewResult = .success(try Self.decodePreview())
    service.createReportResult = .success(
      TaxReportResponse(id: "r1", taxYear: 2025, kind: .annualFilingPack, format: .pdf, status: "pending", createdAt: "2026-09-03T08:00:00.000Z")
    )
    let model = TaxFilingPackViewModel(service: service, taxYear: 2025)
    await model.load()

    await model.generate(format: .pdf)

    XCTAssertEqual(service.createReportRequests, [TaxReportRequest(taxYear: 2025, kind: .annualFilingPack, format: .pdf)])
    XCTAssertEqual(model.queuedReport?.id, "r1")
    XCTAssertFalse(model.isGenerating)
    XCTAssertNil(model.generateError)
    guard case .loaded = model.state else {
      return XCTFail("generate must not disturb the loaded preview")
    }
  }

  func testGenerate_FailureSurfacesErrorAndKeepsPreview() async throws {
    let service = FilingPackServiceMock()
    service.previewResult = .success(try Self.decodePreview())
    service.createReportResult = .failure(TaxServiceError.http(statusCode: 429, message: "limit"))
    let model = TaxFilingPackViewModel(service: service, taxYear: 2025)
    await model.load()

    await model.generate(format: .csv)

    XCTAssertNil(model.queuedReport)
    XCTAssertNotNil(model.generateError)
    XCTAssertFalse(model.isGenerating)
    guard case .loaded = model.state else {
      return XCTFail("a failed generate must keep the preview on screen")
    }
  }

  func testLoad_ClearsQueuedReportWhenYearChanges() async throws {
    let service = FilingPackServiceMock()
    service.previewResult = .success(try Self.decodePreview())
    service.createReportResult = .success(
      TaxReportResponse(id: "r1", taxYear: 2025, kind: .annualFilingPack, format: .csv, status: "pending", createdAt: "2026-09-03T08:00:00.000Z")
    )
    let model = TaxFilingPackViewModel(service: service, taxYear: 2025)
    await model.load()
    await model.generate(format: .csv)
    XCTAssertNotNil(model.queuedReport)

    model.taxYear = 2024
    await model.load()

    XCTAssertNil(model.queuedReport)
    XCTAssertEqual(service.previewTaxYears, [2025, 2024])
  }

  func testReloadAfterPurchase_RetriesUntilThePreviewOpens() async throws {
    let service = FilingPackServiceMock()
    service.previewQueue = [
      .failure(TaxServiceError.http(statusCode: 403, message: nil)),
      .failure(TaxServiceError.http(statusCode: 403, message: nil)),
      .success(try Self.decodePreview()),
    ]
    let model = TaxFilingPackViewModel(service: service, taxYear: 2025)

    await model.reloadAfterPurchase(attempts: 5, delay: .zero)

    guard case .loaded = model.state else {
      return XCTFail("expected .loaded after the webhook landed, got \(model.state)")
    }
    XCTAssertEqual(service.previewTaxYears.count, 3)
  }

  func testReloadAfterPurchase_StopsAfterTheLastAttempt() async {
    let service = FilingPackServiceMock()
    service.previewResult = .failure(TaxServiceError.http(statusCode: 402, message: nil))
    let model = TaxFilingPackViewModel(service: service, taxYear: 2025)

    await model.reloadAfterPurchase(attempts: 3, delay: .zero)

    XCTAssertEqual(model.state, .paywalled)
    XCTAssertEqual(service.previewTaxYears.count, 3)
  }

  func testDefaultTaxYear_FlipsFromLastYearToThisYearInJuly() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
    let day = { (y: Int, m: Int, d: Int) in calendar.date(from: DateComponents(year: y, month: m, day: d))! }

    XCTAssertEqual(TaxFilingPackViewModel.defaultTaxYear(on: day(2026, 3, 15), calendar: calendar), 2025, "filing window: last year's return")
    XCTAssertEqual(TaxFilingPackViewModel.defaultTaxYear(on: day(2026, 6, 30), calendar: calendar), 2025)
    XCTAssertEqual(TaxFilingPackViewModel.defaultTaxYear(on: day(2026, 7, 1), calendar: calendar), 2026, "season closed: the year in progress")
    XCTAssertEqual(TaxFilingPackViewModel.defaultTaxYear(on: day(2026, 9, 3), calendar: calendar), 2026)

    XCTAssertTrue(TaxFilingPackViewModel.isYearOpen(2026, on: day(2026, 9, 3), calendar: calendar))
    XCTAssertFalse(TaxFilingPackViewModel.isYearOpen(2025, on: day(2026, 9, 3), calendar: calendar))
  }

  // MARK: - Fixture

  /// Shape of `GET /v1/tax/filing/preview` as the backend's
  /// FilingPackService.previewResponse emits it (Decimal summary values as
  /// JSON numbers, rows pre-formatted as strings).
  private static let previewJSON = """
  {
    "jurisdiction": "PT",
    "taxYear": 2025,
    "reportingCurrency": "EUR",
    "formName": "IRS Modelo 3 — Anexo J",
    "rulePackVersion": "PT-2026.2",
    "sections": [
      {
        "id": "anexo-j-9.2A",
        "title": "Quadro 9.2A — Alienação onerosa de partes sociais e outros valores mobiliários",
        "columns": ["Código", "País", "Real. ano", "Real. mês", "Valor realização", "Aq. ano", "Aq. mês", "Valor aquisição", "Despesas"],
        "rows": [["G01", "840", "2025", "09", "1362.73", "2025", "02", "909.09", "0.91"]],
        "totals": {"gain": 453.64},
        "notes": ["Método de apuramento: FIFO (art. 43.º CIRS)."]
      },
      {
        "id": "anexo-j-8A",
        "title": "Quadro 8A — Rendimentos de capitais (categoria E)",
        "columns": ["Código", "País", "Rendimento bruto", "Imposto pago no estrangeiro", "Retido em Portugal"],
        "rows": [["E11", "840", "90.91", "13.64", "0.00"]],
        "totals": {"gross": 90.91, "withholding": 13.64},
        "notes": []
      },
      {
        "id": "unsupported",
        "title": "Verificar manualmente",
        "columns": ["Referência", "Motivo", "Ganho"],
        "rows": [],
        "totals": {},
        "notes": []
      }
    ],
    "summary": {"totalGain": 453.64, "totalDividendsGross": 90.91, "totalWithholding": 13.64},
    "disclaimer": "Prepared from your imported trades and dividends. Norviq is not a tax adviser; verify against your broker statements before filing.",
    "disposalCount": 1,
    "dividendCount": 1,
    "unsupportedCount": 0
  }
  """

  private static func decodePreview() throws -> FilingPackPreviewResponse {
    try JSONDecoder().decode(FilingPackPreviewResponse.self, from: Data(previewJSON.utf8))
  }
}

private enum FilingPackServiceMockError: Error {
  case unexpected
}

/// Only the two calls the filing pack sheet makes are configurable; every
/// other TaxServiceProtocol member fails loudly so a stray call shows up.
private final class FilingPackServiceMock: TaxServiceProtocol, @unchecked Sendable {
  var previewResult: Result<FilingPackPreviewResponse, Error> = .failure(FilingPackServiceMockError.unexpected)
  /// Consumed first, one per call, before falling back to `previewResult`.
  var previewQueue: [Result<FilingPackPreviewResponse, Error>] = []
  var createReportResult: Result<TaxReportResponse, Error> = .failure(FilingPackServiceMockError.unexpected)
  var previewTaxYears: [Int] = []
  var createReportRequests: [TaxReportRequest] = []

  func filingPreview(taxYear: Int) async throws -> FilingPackPreviewResponse {
    previewTaxYears.append(taxYear)
    if !previewQueue.isEmpty {
      return try previewQueue.removeFirst().get()
    }
    return try previewResult.get()
  }

  func createReport(_ request: TaxReportRequest) async throws -> TaxReportResponse {
    createReportRequests.append(request)
    return try createReportResult.get()
  }

  func dashboard(jurisdiction _: TaxJurisdiction, taxYear _: Int) async throws -> TaxDashboardResponse {
    throw FilingPackServiceMockError.unexpected
  }

  func profileContext(jurisdiction _: TaxJurisdiction, taxYear _: Int) async throws -> TaxProfileContextResponse {
    throw FilingPackServiceMockError.unexpected
  }

  func saveProfile(_: TaxProfileRequest) async throws -> TaxProfileResponse {
    throw FilingPackServiceMockError.unexpected
  }

  func saveMarketAdmission(instrumentId _: String, status _: TaxMarketAdmissionStatus) async throws -> TaxInstrumentMarketOption {
    throw FilingPackServiceMockError.unexpected
  }

  func saveFundClassification(instrumentId _: String, classification _: TaxFundClassification) async throws -> TaxInstrumentMarketOption {
    throw FilingPackServiceMockError.unexpected
  }

  func saveFundAnnualInput(_: TaxFundAnnualInputRequest) async throws -> TaxFundAdvanceLumpSumResponse {
    throw FilingPackServiceMockError.unexpected
  }

  func fundAnnualInput(accountId _: String, instrumentId _: String, calculationYear _: Int) async throws -> TaxFundAdvanceLumpSumResponse {
    throw FilingPackServiceMockError.unexpected
  }

  func createScenario(_: TaxScenarioRequest, jurisdiction _: TaxJurisdiction, taxYear _: Int) async throws -> TaxScenarioResponse {
    throw FilingPackServiceMockError.unexpected
  }

  func createActionPlan(_: TaxActionPlanRequest) async throws -> TaxActionPlanResponse {
    throw FilingPackServiceMockError.unexpected
  }

  func actionPlans() async throws -> [TaxActionPlanResponse] {
    throw FilingPackServiceMockError.unexpected
  }

  func transitionActionPlan(id _: String, request _: TaxActionPlanTransitionRequest) async throws -> TaxActionPlanResponse {
    throw FilingPackServiceMockError.unexpected
  }

  func createLocationScenario(_: TaxLocationScenarioRequest, jurisdiction _: TaxJurisdiction, taxYear _: Int) async throws -> TaxLocationScenarioResponse {
    throw FilingPackServiceMockError.unexpected
  }

  func createPlacementPlan(_: TaxPlacementPlanRequest) async throws -> TaxActionPlanResponse {
    throw FilingPackServiceMockError.unexpected
  }

  func dismissOpportunity(id _: String, jurisdiction _: TaxJurisdiction, taxYear _: Int) async throws {
    throw FilingPackServiceMockError.unexpected
  }

  func restoreOpportunity(id _: String, jurisdiction _: TaxJurisdiction, taxYear _: Int) async throws {
    throw FilingPackServiceMockError.unexpected
  }

  func notificationPreferences() async throws -> TaxNotificationPreferences {
    throw FilingPackServiceMockError.unexpected
  }

  func saveNotificationPreferences(_: TaxNotificationPreferences) async throws -> TaxNotificationPreferences {
    throw FilingPackServiceMockError.unexpected
  }

  func reports() async throws -> [TaxReportResponse] {
    throw FilingPackServiceMockError.unexpected
  }

  func downloadReport(_: TaxReportResponse) async throws -> URL {
    throw FilingPackServiceMockError.unexpected
  }

  func lossCarryforwards(jurisdiction _: TaxJurisdiction, taxYear _: Int) async throws -> TaxLossCarryforwardLedgerResponse {
    throw FilingPackServiceMockError.unexpected
  }
}
