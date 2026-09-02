import XCTest

@testable import financeplan

/// The positions list asks for the next page from a last-row `onAppear`
/// sentinel. These tests pin the contract that a page of rows appearing
/// triggers exactly one load, not one per row.
final class PortfolioPaginationSentinelTests: XCTestCase {
  func testOnlyLastRowIsSentinel() {
    let ids = (0..<50).map { "row-\($0)" }
    let loadMoreCount = ids.reduce(into: 0) { count, id in
      if PortfolioPaginationSentinel.shouldLoadMore(appearing: id, lastID: ids.last) {
        count += 1
      }
    }
    XCTAssertEqual(loadMoreCount, 1)
  }

  func testAppendingAPageMovesTheSentinel() {
    var ids = (0..<50).map { "row-\($0)" }
    XCTAssertTrue(PortfolioPaginationSentinel.shouldLoadMore(appearing: "row-49", lastID: ids.last))

    ids.append(contentsOf: (50..<100).map { "row-\($0)" })
    XCTAssertFalse(PortfolioPaginationSentinel.shouldLoadMore(appearing: "row-49", lastID: ids.last))
    XCTAssertTrue(PortfolioPaginationSentinel.shouldLoadMore(appearing: "row-99", lastID: ids.last))
  }

  func testEmptyListNeverLoadsMore() {
    let empty: [String] = []
    XCTAssertFalse(PortfolioPaginationSentinel.shouldLoadMore(appearing: "anything", lastID: empty.last))
  }
}
