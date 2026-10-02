import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

private final class ManagedPortfolioURLProtocol: URLProtocol {
  nonisolated(unsafe) static var response: (Int, String) = (200, "{}")

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url,
          let response = HTTPURLResponse(url: url, statusCode: Self.response.0, httpVersion: nil, headerFields: ["Content-Type": "application/json"])
    else { fatalError("Could not build response") }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(Self.response.1.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

/// Hand edits to a portfolio a pilot follow manages are refused with 409. The
/// holdings screens show `errorDescription`, so the server's sentence must
/// survive the stock client unchanged.
@MainActor
final class PilotManagedPortfolioErrorTests: XCTestCase {
  static let reason = "This portfolio is managed by a pilot follow. Stop following to edit it."

  func testStockClientKeepsTheManagedPortfolioReason() async {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ManagedPortfolioURLProtocol.self]
    ManagedPortfolioURLProtocol.response = (409, #"{"error":true,"code":"conflict","reason":"\#(Self.reason)"}"#)
    let client = StockHTTPClient(baseURL: URL(string: "https://api.example.com")!, session: URLSession(configuration: config))

    do {
      try await client.callWithoutResponse(DeleteStockEndpoint(stockId: "s1"))
      XCTFail("Expected a 409")
    } catch {
      XCTAssertEqual((error as? LocalizedError)?.errorDescription, Self.reason)
    }
  }
}
