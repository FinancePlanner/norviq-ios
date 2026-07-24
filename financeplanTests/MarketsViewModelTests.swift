import CoreGraphics
import Foundation
import XCTest

@testable import financeplan

@MainActor
final class MarketsViewModelTests: XCTestCase {
  private func makeOverview(indices: [MarketIndexQuote] = []) -> MarketOverviewResponse {
    MarketOverviewResponse(
      indices: indices,
      gainers: [MarketMover(symbol: "UPUP", name: "Up Corp", price: 10, changePct: 22)],
      losers: [MarketMover(symbol: "DOWN", name: "Down Corp", price: 4, changePct: -18)],
      heatmap: [
        MarketHeatmapTile(symbol: "AAPL", name: "Apple", sector: "Technology", marketCap: 3.4e12, changePct: -0.8),
      ],
      asOf: "2026-07-25T12:00:00Z"
    )
  }

  func testLoadPopulatesOverview() async {
    let mock = MarketsOverviewServiceMock()
    mock.result = .success(makeOverview(indices: [
      MarketIndexQuote(symbol: "SPY", label: "S&P 500", price: 560, changePct: 0.4, isProxy: true),
    ]))
    let viewModel = MarketsViewModel(marketDataService: mock)

    await viewModel.load()

    XCTAssertEqual(viewModel.overview?.indices.first?.label, "S&P 500")
    XCTAssertEqual(viewModel.overview?.indices.first?.isProxy, true)
    XCTAssertEqual(viewModel.overview?.gainers.map(\.symbol), ["UPUP"])
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoadFailureSetsErrorOnlyWhenEmpty() async {
    let mock = MarketsOverviewServiceMock()
    mock.result = .failure(MarketsMockError.down)
    let viewModel = MarketsViewModel(marketDataService: mock)

    await viewModel.load()
    XCTAssertNotNil(viewModel.errorMessage)

    mock.result = .success(makeOverview())
    await viewModel.load()
    XCTAssertNotNil(viewModel.overview)

    mock.result = .failure(MarketsMockError.down)
    await viewModel.load()
    XCTAssertNotNil(viewModel.overview, "stale overview should survive a refresh failure")
    XCTAssertNil(viewModel.errorMessage)
  }

  func testSquarifiedFramesAreProportionalAndTileTheRect() {
    let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
    let weights: [Double] = [6, 6, 4, 3, 2, 2, 1]
    let frames = SquarifiedTreemap.frames(weights: weights, in: rect)

    XCTAssertEqual(frames.count, weights.count)

    let totalWeight = weights.reduce(0, +)
    let rectArea = Double(rect.width * rect.height)
    for (index, frame) in frames.enumerated() {
      let expected = weights[index] / totalWeight * rectArea
      XCTAssertEqual(Double(frame.width * frame.height), expected, accuracy: rectArea * 0.001)
      XCTAssertTrue(rect.insetBy(dx: -0.01, dy: -0.01).contains(frame), "frame \(index) escapes the rect")
    }

    let framesArea = frames.reduce(0.0) { $0 + Double($1.width * $1.height) }
    XCTAssertEqual(framesArea, rectArea, accuracy: rectArea * 0.001)

    for i in frames.indices {
      for j in frames.indices where j > i {
        let overlap = frames[i].insetBy(dx: 0.01, dy: 0.01).intersection(frames[j])
        XCTAssertTrue(overlap.isNull || overlap.width * overlap.height < 0.5, "frames \(i) and \(j) overlap")
      }
    }
  }

  func testSquarifiedFramesHandleDegenerateInput() {
    XCTAssertEqual(SquarifiedTreemap.frames(weights: [], in: CGRect(x: 0, y: 0, width: 10, height: 10)), [])
    let zeroRect = SquarifiedTreemap.frames(weights: [1, 2], in: .zero)
    XCTAssertEqual(zeroRect, [.zero, .zero])
  }
}

private enum MarketsMockError: Error {
  case down
}

private final class MarketsOverviewServiceMock: MarketDataServicing, @unchecked Sendable {
  var result: Result<MarketOverviewResponse, Error> = .failure(MarketsMockError.down)

  func fetchMarketOverview() async throws -> MarketOverviewResponse {
    try result.get()
  }
}
