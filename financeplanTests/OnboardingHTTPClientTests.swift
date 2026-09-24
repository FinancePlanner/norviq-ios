import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class OnboardingHTTPClientTests: XCTestCase {
  private final class SessionMock: HTTPClientSession, @unchecked Sendable {
    var handler: ((URLRequest) throws -> (Data, URLResponse))?
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard let handler else { fatalError("SessionMock.handler must be configured before use") }
      return try handler(request)
    }
  }

  private let body = Data(#"{"funnelStep":"import","funnelCompletedAt":null,"addHoldingCompleted":false,"setBudgetCompleted":false,"setGoalCompleted":false,"guidedStartDismissedAt":null}"#.utf8)

  func testPatchSendsOnlyTheSetFieldsWithBearer() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))
    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "PATCH")
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/onboarding")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      let sent = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
      XCTAssertEqual(sent?.keys.sorted(), ["funnelStep"])
      XCTAssertEqual(sent?["funnelStep"] as? String, "import")
      return (self.body, HTTPURLResponse(url: baseURL, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    let client = OnboardingHTTPClient(baseURL: baseURL, session: session, authTokenProvider: { "token-123" })
    let state = try await client.patch(OnboardingPatchRequest(funnelStep: OnboardingFunnelStep.import.rawValue))
    XCTAssertEqual(state.funnelStep, "import")
  }
}
