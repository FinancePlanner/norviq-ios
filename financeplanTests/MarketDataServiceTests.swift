import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class MarketDataServiceTests: XCTestCase {
  private final class SessionMock: MarketDataURLSessionProtocol {
    var handler: ((URLRequest) throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard let handler else {
        fatalError("SessionMock.handler must be configured before use")
      }
      return try handler(request)
    }
  }

  private final class AuthSessionManagerMock: AuthSessionManaging {
    var validAccessTokenCalls = 0
    var refreshAccessTokenCalls = 0
    var logoutCalls = 0
    var invalidateSessionCalls = 0
    var validAccessTokenResult: Result<String?, Error> = .failure(MockError.notConfigured)
    var refreshAccessTokenResult: Result<String?, Error> = .failure(MockError.notConfigured)

    func restoreSessionIfNeeded() async -> Bool { false }

    func validAccessToken() async throws -> String? {
      validAccessTokenCalls += 1
      return try validAccessTokenResult.get()
    }

    func refreshAccessToken() async throws -> String? {
      refreshAccessTokenCalls += 1
      return try refreshAccessTokenResult.get()
    }

    func logout() async {
      logoutCalls += 1
    }

    func invalidateSession() async {
      invalidateSessionCalls += 1
    }
  }

  private enum MockError: Error {
    case notConfigured
  }

  func testFetchCompanyProfile_UsesBearerTokenAndReturnsProfile() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = MarketDataHTTPService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )
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
      XCTAssertEqual(request.url?.path, "/v1/profile/ZETA")
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (try JSONEncoder().encode(expected), response)
    }

    let response = try await service.fetchCompanyProfile(symbol: "zeta")

    XCTAssertEqual(response, expected)
    XCTAssertEqual(authSessionManager.validAccessTokenCalls, 1)
    XCTAssertEqual(authSessionManager.refreshAccessTokenCalls, 0)
  }

  func testFetchQuote_WhenUnauthorized_RefreshesAndRetriesWithNewToken() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("expired-token")
    authSessionManager.refreshAccessTokenResult = .success("fresh-token")
    let service = MarketDataHTTPService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )

    var requests = 0
    session.handler = { request in
      requests += 1

      if requests == 1 {
        XCTAssertEqual(request.url?.path, "/v1/quote/ZETA")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer expired-token")

        let response = try XCTUnwrap(
          HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 401, httpVersion: nil, headerFields: nil)
        )
        return (#"{"error":"Access token expired"}"#.data(using: .utf8) ?? Data(), response)
      }

      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fresh-token")
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

    let response = try await service.fetchQuote(symbol: "ZETA")

    XCTAssertEqual(response.currentPrice, 15.73, accuracy: 0.001)
    XCTAssertEqual(requests, 2)
    XCTAssertEqual(authSessionManager.validAccessTokenCalls, 1)
    XCTAssertEqual(authSessionManager.refreshAccessTokenCalls, 1)
    XCTAssertEqual(authSessionManager.invalidateSessionCalls, 0)
  }
}
