import StockPlanShared
import XCTest
@testable import financeplan

final class PortfolioShareLinksSplitTests: XCTestCase {
  private func link(_ scope: String) -> PortfolioShareLinkResponse {
    PortfolioShareLinkResponse(slug: "p\(scope)", url: "https://norviq.org/p/p\(scope)", scope: scope, createdAt: "2026-09-24T10:00:00Z")
  }

  func testSplitsCurrentScopeFromOthers() {
    let split = PortfolioShareLinks.split([link("all"), link("abc")], scope: "abc")
    XCTAssertEqual(split.current?.scope, "abc")
    XCTAssertEqual(split.others.map(\.scope), ["all"])
  }

  func testNoCurrentLink() {
    let split = PortfolioShareLinks.split([link("all")], scope: "abc")
    XCTAssertNil(split.current)
    XCTAssertEqual(split.others.map(\.scope), ["all"])
  }
}
