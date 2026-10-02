import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class PilotDetailModelTests: XCTestCase {
  func testLoadShowsWeightsDisclosuresAndLagNote() async {
    let service = MockPilotsService()
    service.detailResult = .success(.fixture(skippedPuts: 2))
    let model = PilotDetailModel(slug: "nancy-pelosi", service: service)

    await model.load()

    XCTAssertEqual(model.detail?.weights.map(\.symbol), ["NVDA", "AAPL"])
    XCTAssertEqual(model.detail?.skippedPuts, 2)
    XCTAssertEqual(model.detail?.lagNote, "Congressional trades are disclosed up to 45 days after they happen.")
    XCTAssertNil(model.errorMessage)
    XCTAssertFalse(model.isLoading)
  }

  func testMissingPilotOrFeatureOffShowsAPlainSentence() async {
    let service = MockPilotsService()
    service.detailResult = .failure(PilotsHTTPClient.Error.rejected(status: 404, message: "Not Found"))
    let model = PilotDetailModel(slug: "gone", service: service)

    await model.load()

    XCTAssertNil(model.detail)
    XCTAssertEqual(model.errorMessage, "This pilot isn't available right now.")
  }

  func testOtherFailuresShowTheirDescription() async {
    let service = MockPilotsService()
    service.detailResult = .failure(PilotsHTTPClient.Error.invalidStatus(500))
    let model = PilotDetailModel(slug: "nancy-pelosi", service: service)

    await model.load()

    XCTAssertEqual(model.errorMessage, "Request failed (500).")
  }
}
