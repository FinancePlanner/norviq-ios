import XCTest
@testable import financeplan

/// Mirrors the web `brokers.test.ts`: the iOS catalogue must not drift from it.
@MainActor
final class BrokerImportCatalogTests: XCTestCase {
  func testCatalogueMatchesWebIdsNamesAndOrder() {
    XCTAssertEqual(
      BrokerImportCatalog.brokers.map(\.id),
      ["ibkr", "degiro", "trading212", "revolut", "other"]
    )
    XCTAssertEqual(
      BrokerImportCatalog.brokers.map(\.name),
      ["IBKR", "DEGIRO", "Trading 212", "Revolut", "Other broker (CSV)"]
    )
  }

  func testNamedBrokersNeverOfferCSV() {
    for broker in BrokerImportCatalog.brokers where broker.id != "other" {
      XCTAssertEqual(broker.methods, [.screenshot, .askQ], broker.id)
      XCTAssertFalse(broker.methods.contains(.csv), broker.id)
    }
  }

  func testOtherOffersCSVFirst() {
    let other = BrokerImportCatalog.brokers.first { $0.id == "other" }
    XCTAssertEqual(other?.methods, [.csv, .screenshot, .askQ])
  }

  func testDisplayNameKeepsNamedBrokersVerbatim() {
    for broker in BrokerImportCatalog.brokers where broker.id != "other" {
      XCTAssertEqual(broker.displayName, broker.name)
    }
    // Under the en test locale the localized form equals the catalogue name.
    XCTAssertEqual(BrokerImportCatalog.brokers.first { $0.id == "other" }?.displayName, "Other broker (CSV)")
  }

  func testMethodLabels() {
    XCTAssertEqual(ImportMethod.screenshot.label, "Screenshots")
    XCTAssertEqual(ImportMethod.askQ.label, "Ask Q")
    XCTAssertEqual(ImportMethod.csv.label, "CSV file")
  }

  func testScreenshotGuideForNamedBrokerUsesItsName() throws {
    let ibkr = try XCTUnwrap(BrokerImportCatalog.brokers.first { $0.id == "ibkr" })
    XCTAssertEqual(
      BrokerImportCatalog.screenshotGuide(for: ibkr),
      "Open your positions list in the IBKR app or website and take screenshots that show every holding. You can import up to 3 at a time."
    )
  }

  func testScreenshotGuideForOtherUsesYourBrokers() throws {
    let other = try XCTUnwrap(BrokerImportCatalog.brokers.first { $0.id == "other" })
    XCTAssertEqual(
      BrokerImportCatalog.screenshotGuide(for: other),
      "Open your positions list in your broker's app or website and take screenshots that show every holding. You can import up to 3 at a time."
    )
  }

  func testAskQGuideAndCSVRowNote() {
    XCTAssertEqual(
      BrokerImportCatalog.askQGuide,
      "Attach your screenshots to Q and ask it to update your holdings. You review every row before anything is saved."
    )
    XCTAssertEqual(BrokerImportCatalog.csvReplaceNote(symbol: "AAPL"), "Replaces your existing AAPL")
  }
}

@MainActor
final class BrokerImportViewModelTests: XCTestCase {
  private func list(_ id: String, isDefault: Bool = false) -> PortfolioListDTOResponse {
    PortfolioListDTOResponse(id: id, name: "List \(id)", isDefault: isDefault, createdAt: nil, updatedAt: nil)
  }

  func testPreselectsThePortfolioTheUserCameFrom() async {
    let model = BrokerImportViewModel(
      initialPortfolioListId: "b",
      allowsAskQ: true,
      loadPortfolios: { [self] in [list("a", isDefault: true), list("b")] }
    )
    await model.load()
    XCTAssertEqual(model.selectedPortfolioListId, "b")
  }

  func testFallsBackToDefaultPortfolioWhenNoneOrUnknown() async {
    for initial in [nil, "", "gone"] as [String?] {
      let model = BrokerImportViewModel(
        initialPortfolioListId: initial,
        allowsAskQ: true,
        loadPortfolios: { [self] in [list("a"), list("b", isDefault: true)] }
      )
      await model.load()
      XCTAssertEqual(model.selectedPortfolioListId, "b", "initial: \(String(describing: initial))")
    }
  }

  func testFallsBackToFirstWhenNoDefaultFlag() async {
    let model = BrokerImportViewModel(
      initialPortfolioListId: nil, allowsAskQ: true,
      loadPortfolios: { [self] in [list("a"), list("b")] }
    )
    await model.load()
    XCTAssertEqual(model.selectedPortfolioListId, "a")
  }

  func testLoadFailureKeepsInitialIdSoImportStillWorks() async {
    struct Boom: Error {}
    let model = BrokerImportViewModel(
      initialPortfolioListId: "b", allowsAskQ: true, loadPortfolios: { throw Boom() }
    )
    await model.load()
    XCTAssertEqual(model.selectedPortfolioListId, "b")
    XCTAssertTrue(model.portfolios.isEmpty)
  }

  func testBrokerSelectionDrivesMethodsAndGuide() {
    let model = BrokerImportViewModel(initialPortfolioListId: nil, allowsAskQ: true, loadPortfolios: { [] })
    XCTAssertEqual(model.selectedBroker.id, "ibkr")
    XCTAssertEqual(model.methods, [.screenshot, .askQ])
    model.selectedBrokerId = "other"
    XCTAssertEqual(model.methods, [.csv, .screenshot, .askQ])
    XCTAssertTrue(model.screenshotGuide.contains("your broker's"))
  }

  func testAskQHiddenWhereThereIsNoQ() {
    let model = BrokerImportViewModel(initialPortfolioListId: nil, allowsAskQ: false, loadPortfolios: { [] })
    XCTAssertEqual(model.methods, [.screenshot])
    model.selectedBrokerId = "other"
    XCTAssertEqual(model.methods, [.csv, .screenshot])
  }

  func testUnknownBrokerIdFallsBackToFirst() {
    let model = BrokerImportViewModel(initialPortfolioListId: nil, allowsAskQ: true, loadPortfolios: { [] })
    model.selectedBrokerId = "nope"
    XCTAssertEqual(model.selectedBroker.id, "ibkr")
  }
}
