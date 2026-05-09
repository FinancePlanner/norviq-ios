import XCTest

@testable import financeplan

@MainActor
final class ShareURLBuilderTests: XCTestCase {
  private let testBase = URL(string: "https://share.example.com")!

  func testStockShareURL_normalizesSymbolToUppercase() {
    let url = ShareURLBuilder.stock(symbol: "aapl", baseURL: testBase)
    XCTAssertEqual(url.absoluteString, "https://share.example.com/share/stock/AAPL")
  }

  func testStockShareURL_preservesDotAndDash() {
    let url = ShareURLBuilder.stock(symbol: "brk.b", baseURL: testBase)
    XCTAssertEqual(url.absoluteString, "https://share.example.com/share/stock/BRK.B")
  }

  func testStockShareURL_truncatesAtFirstUnsafeCharacter() {
    let url = ShareURLBuilder.stock(symbol: "aapl<script>", baseURL: testBase)
    XCTAssertEqual(url.absoluteString, "https://share.example.com/share/stock/AAPL")
  }

  func testStockShareURL_emptyForFullyInvalidSymbol() {
    let url = ShareURLBuilder.stock(symbol: "<>", baseURL: testBase)
    XCTAssertEqual(url.absoluteString, "https://share.example.com/share/stock/")
  }

  func testAppShareURL_pointsToShareApp() {
    let url = ShareURLBuilder.app(baseURL: testBase)
    XCTAssertEqual(url.absoluteString, "https://share.example.com/share/app")
  }

  func testStockShareURL_defaultBaseUsesNorviqaConstant() {
    let url = ShareURLBuilder.stock(symbol: "TSLA")
    XCTAssertEqual(url.host, Constants.Norviq.shareBaseUrl.host)
    XCTAssertTrue(url.absoluteString.hasSuffix("/share/stock/TSLA"))
  }
}
