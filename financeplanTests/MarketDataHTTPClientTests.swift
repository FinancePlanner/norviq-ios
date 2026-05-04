import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class MarketDataHTTPClientTests: XCTestCase {
  private final class SessionMock: MarketDataURLSessionProtocol, @unchecked Sendable {
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
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/market/profile/ZETA")
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
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/market/quote/ZETA")
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

  func testFetchAnalysisMetrics_SendsCorrectRequestAndDecodesPayload() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/market/analysis/ZETA")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      XCTAssertNil(request.httpBody)

      let payload = """
      {
        "symbol": "ZETA",
        "ttmPE": 21.4,
        "forwardPE": 18.9,
        "twoYearForwardPE": 16.4,
        "ttmEPSGrowth": 0.12,
        "currentYearExpectedEPSGrowth": 0.14,
        "nextYearEPSGrowth": 0.15,
        "ttmRevenueGrowth": 0.1,
        "currentYearExpectedRevenueGrowth": 0.11,
        "nextYearRevenueGrowth": 0.12,
        "grossMargin": 0.61,
        "netMargin": 0.2,
        "ttmPEGRatio": 1.6,
        "lastYearEPSGrowth": 0.09,
        "ttmVsNTMEPSGrowth": 0.02,
        "currentQuarterEPSGrowthVsPreviousYear": 0.08,
        "twoYearStackExpectedEPSGrowth": 0.31,
        "lastYearRevenueGrowth": 0.07,
        "ttmVsNTMRevenueGrowth": 0.01,
        "currentQuarterRevenueGrowthVsPreviousYear": 0.06,
        "twoYearStackExpectedRevenueGrowth": 0.24,
        "currentPrice": null,
        "marketCap": null,
        "sharesOutstanding": null,
        "baseYear": null,
        "yearlyProjections": null,
        "wacc": null,
        "terminalGrowthRate": null,
        "terminalMargin": null,
        "exitPELow": null,
        "exitPEHigh": null,
        "dcfBasePrice": null,
        "dcfBearPrice": null,
        "dcfBullPrice": null,
        "netDebt": null
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
    let response = try await client.fetchAnalysisMetrics(symbol: "zeta")

    XCTAssertEqual(response.symbol, "ZETA")
    XCTAssertEqual(try XCTUnwrap(response.ttmPE), 21.4, accuracy: 0.0001)
    XCTAssertEqual(try XCTUnwrap(response.netMargin), 0.2, accuracy: 0.0001)
    XCTAssertEqual(try XCTUnwrap(response.comparisonMetrics[.grossMargin]), 0.61, accuracy: 0.0001)
  }

  func testFetchBalanceSheetStatement_AppendsGETQueryParameters() async throws {
    let session = SessionMock()
    let baseURL = try XCTUnwrap(URL(string: "https://api.example.com"))

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      XCTAssertNil(request.httpBody)

      let url = try XCTUnwrap(request.url)
      XCTAssertEqual(url.scheme, "https")
      XCTAssertEqual(url.host, "api.example.com")
      XCTAssertEqual(url.path, "/v1/market/balance-sheet-statement/UBER")

      let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
      let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
      XCTAssertEqual(queryItems["limit"], "10")
      XCTAssertEqual(queryItems["period"], "quarter")

      let response = try XCTUnwrap(
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (Data("[]".utf8), response)
    }

    let client = MarketDataHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: { "token-123" }
    )
    let response = try await client.fetchBalanceSheetStatement(symbol: "uber", limit: 10, period: "quarter")

    XCTAssertTrue(response.isEmpty)
  }
}
