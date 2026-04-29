import XCTest
@testable import financeplan

@MainActor
final class CSVImportViewModelTests: XCTestCase {
  private var viewModel: CSVImportViewModel!

  override func setUp() {
    super.setUp()
    viewModel = CSVImportViewModel()
  }

  func testParseCSV_WithValidRows_ReturnsCorrectPositions() {
    let csv = """
    symbol,quantity,price
    AAPL,10,150.5
    MSFT,5,250.75
    """

    let results = viewModel.parseCSV(csv)

    XCTAssertEqual(results.count, 2)
    XCTAssertEqual(results[0].symbol, "AAPL")
    XCTAssertEqual(results[0].quantity, 10.0)
    XCTAssertEqual(results[0].price, 150.5)

    XCTAssertEqual(results[1].symbol, "MSFT")
    XCTAssertEqual(results[1].quantity, 5.0)
    XCTAssertEqual(results[1].price, 250.75)
  }

  func testParseCSV_WithExtraSpaces_TrimsCorrectly() {
    let csv = """
    symbol, quantity , price
     AAPL , 10 , 150.5 
    """

    let results = viewModel.parseCSV(csv)

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].symbol, "AAPL")
    XCTAssertEqual(results[0].quantity, 10.0)
    XCTAssertEqual(results[0].price, 150.5)
  }

  func testParseCSV_WithInvalidDataRows_SkipsInvalidRows() {
    let csv = """
    symbol,quantity,price
    AAPL,10,150.5
    INVALID
    MSFT,,250
    ,5,100
    """

    let results = viewModel.parseCSV(csv)

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].symbol, "AAPL")
  }

  func testParseCSV_WithZeroQuantity_SkipsRow() {
    let csv = """
    symbol,quantity,price
    AAPL,0,150.5
    """

    let results = viewModel.parseCSV(csv)

    XCTAssertTrue(results.isEmpty)
  }

  func testParseCSV_LowercaseSymbols_ConvertsToUppercase() {
    let csv = """
    symbol,quantity,price
    aapl,10,150.5
    """

    let results = viewModel.parseCSV(csv)

    XCTAssertEqual(results.first?.symbol, "AAPL")
  }

  func testLoadCSV_WithValidFile_LoadsRows() async throws {
    let fileURL = makeTempCSVFile(contents: "symbol,quantity,price\nAAPL,10,150.5")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    viewModel.loadCSV(from: fileURL)

    XCTAssertEqual(viewModel.previewRows.count, 1)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoadCSV_WithEmptyFile_ReturnsEmptyRows() async throws {
    let fileURL = makeTempCSVFile(contents: "")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    viewModel.loadCSV(from: fileURL)

    XCTAssertTrue(viewModel.previewRows.isEmpty)
    XCTAssertNil(viewModel.errorMessage)
  }

  private func makeTempCSVFile(contents: String) -> URL {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test-import-\(UUID().uuidString).csv")
    try? contents.write(to: fileURL, atomically: true, encoding: .utf8)
    return fileURL
  }
}
