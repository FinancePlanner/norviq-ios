import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class MarketDataHTTPClientTests: XCTestCase {
  private final class SessionMock: MarketDataURLSessionProtocol {
    var handler: ((URLRequest) throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard let handler else {
        fatalError("SessionMock.handler must be configured before use")
      }
      return try handler(request)
    }
  }

  func testFetchCompanyProfile_SendsCorrectRequestAndDecodesResponse() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))
    let expected = CompanyProfileResponse(
      country: "US",
      currency: "USD",
      estimateCurrency: "USD",
      exchange: "NEW YORK STOCK EXCHANGE, INC.",
      finnhubIndustry: "Technology",
      ipo: "2021-06-10",
      logo: "https://static2.finnhub.io/file/publicdatany/finnhubimage/stock_logo/950801514946.png",
      marketCapitalization: 4355.17,
      name: "Zeta Global Holdings Corp",
      phone: "18003464646",
      shareOutstanding: 244.12,
      ticker: "ZETA",
      weburl: "https://investors.zetaglobal.com/"
    )

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/profile/ZETA")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      XCTAssertNil(request.httpBody)

      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (try JSONEncoder().encode(expected), response)
    }

    let client = MarketDataHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: { "token-123" }
    )
    let response = try await client.fetchCompanyProfile(symbol: "zeta")

    XCTAssertEqual(response, expected)
  }

  func testFetchQuote_SendsCorrectRequestAndDecodesQuotePayload() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/quote/ZETA")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      XCTAssertNil(request.httpBody)

      let payload = """
      {
        "l": 15.53,
        "currency": "USD",
        "dp": -1.1935,
        "t": 1775073600,
        "symbol": "ZETA",
        "d": -0.19,
        "o": 16.2,
        "c": 15.73,
        "h": 16.3,
        "pc": 15.92
      }
      """.data(using: .utf8) ?? Data()
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (payload, response)
    }

    let client = MarketDataHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: { "token-123" }
    )
    let response = try await client.fetchQuote(symbol: "ZETA")

    XCTAssertEqual(response.symbol, "ZETA")
    XCTAssertEqual(response.currency, "USD")
    XCTAssertEqual(response.currentPrice, 15.73, accuracy: 0.001)
    XCTAssertEqual(try XCTUnwrap(response.change), -0.19, accuracy: 0.001)
    XCTAssertEqual(try XCTUnwrap(response.percentChange), -1.1935, accuracy: 0.0001)
    XCTAssertEqual(try XCTUnwrap(response.open), 16.2, accuracy: 0.001)
    XCTAssertEqual(try XCTUnwrap(response.high), 16.3, accuracy: 0.001)
    XCTAssertEqual(try XCTUnwrap(response.low), 15.53, accuracy: 0.001)
    XCTAssertEqual(try XCTUnwrap(response.previousClose), 15.92, accuracy: 0.001)
    XCTAssertEqual(response.timestamp, 1_775_073_600, accuracy: 0.1)
  }
}
