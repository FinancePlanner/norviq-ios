import XCTest
@testable import financeplan

@MainActor
final class ShareURLBuilderTests: XCTestCase {
  private let testBase = URL(string: "https://share.example.com")!

  func testStockShareURL_normalizesSymbolToUppercase() async {
    await Task.yield()
    let url = ShareURLBuilder.stock(symbol: "aapl", baseURL: testBase)
    XCTAssertEqual(url.absoluteString, "https://share.example.com/share/stock/AAPL")
  }

  func testStockShareURL_preservesDotAndDash() async {
    await Task.yield()
    let url = ShareURLBuilder.stock(symbol: "brk.b", baseURL: testBase)
    XCTAssertEqual(url.absoluteString, "https://share.example.com/share/stock/BRK.B")
  }

  func testStockShareURL_truncatesAtFirstUnsafeCharacter() async {
    await Task.yield()
    let url = ShareURLBuilder.stock(symbol: "aapl<script>", baseURL: testBase)
    XCTAssertEqual(url.absoluteString, "https://share.example.com/share/stock/AAPL")
  }

  func testStockShareURL_emptyForFullyInvalidSymbol() async {
    await Task.yield()
    let url = ShareURLBuilder.stock(symbol: "<>", baseURL: testBase)
    XCTAssertEqual(url.absoluteString, "https://share.example.com/share/stock/")
  }

  func testAppShareURL_pointsToShareApp() async {
    await Task.yield()
    let url = ShareURLBuilder.app(baseURL: testBase)
    XCTAssertEqual(url.absoluteString, "https://share.example.com/share/app")
  }

  func testStockShareURL_defaultBaseUsesNorviqaConstant() async {
    await Task.yield()
    let url = ShareURLBuilder.stock(symbol: "TSLA")
    XCTAssertEqual(url.host, Constants.Norviq.shareBaseUrl.host)
    XCTAssertTrue(url.absoluteString.hasSuffix("/share/stock/TSLA"))
  }
}
