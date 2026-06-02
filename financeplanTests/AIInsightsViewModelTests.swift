import Foundation
import StockPlanShared
import XCTest

@testable import financeplan

@MainActor
final class AIInsightsViewModelTests: XCTestCase {
  func testGenerateSuccessSetsLoadedStateWithServerDisclaimer() async {
    let service = AIInsightsServiceMock()
    let viewModel = InsightsViewModel(service: service)

    await viewModel.generate(.portfolio)

    XCTAssertEqual(service.generateCalls, 1)
    guard case let .loaded(card) = viewModel.state(for: .portfolio) else {
      return XCTFail("expected loaded state")
    }
    XCTAssertEqual(card.kind, .portfolio)
    XCTAssertEqual(card.disclaimer, AIInsightCardResponse.standardDisclaimer)
  }

  func testGenerateFailureSetsFailedState() async {
    let service = AIInsightsServiceMock(shouldThrow: true)
    let viewModel = InsightsViewModel(service: service)

    await viewModel.generate(.expenses)

    guard case .failed = viewModel.state(for: .expenses) else {
      return XCTFail("expected failed state")
    }
  }

  func testUntouchedKindStaysIdle() async {
    let service = AIInsightsServiceMock()
    let viewModel = InsightsViewModel(service: service)

    await viewModel.generate(.portfolio)

    XCTAssertEqual(viewModel.state(for: .summary), .idle)
  }
}

@MainActor
private final class AIInsightsServiceMock: AIInsightsServicing, @unchecked Sendable {
  var generateCalls = 0
  let shouldThrow: Bool

  init(shouldThrow: Bool = false) {
    self.shouldThrow = shouldThrow
  }

  func generate(kind: AIInsightKind) async throws -> AIInsightCardResponse {
    generateCalls += 1
    if shouldThrow {
      throw URLError(.badServerResponse)
    }
    return AIInsightCardResponse(
      kind: kind,
      title: "Title",
      body: "Body",
      highlights: []
    )
  }
}
