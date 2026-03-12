import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class StockServiceTests: XCTestCase {
  private final class SessionMock: StockURLSessionProtocol {
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

  private func makeValuationRequest(
    symbol: String = "AAPL",
    rationale: String? = "Margin expansion with stable demand.",
    targetDate: String? = "2026-12-31"
  ) -> StockValuationRequest {
    StockValuationRequest(
      symbol: symbol,
      bearCase: PriceRange(low: 100, high: 120),
      baseCase: PriceRange(low: 130, high: 150),
      bullCase: PriceRange(low: 160, high: 190),
      rationale: rationale,
      targetDate: targetDate
    )
  }

  func testBulkCreate_UsesBearerTokenAndReturnsResponse() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )
    let expected = BulkCreateStocksResponse(
      created: 1,
      failed: 0,
      results: [
        BulkCreateStocksItem(
          index: 0,
          stock: StockResponse(
            id: "stock-1",
            symbol: "AAPL",
            shares: 10,
            buyPrice: 123.45,
            buyDate: "2026-03-08",
            notes: ""
          ),
          error: nil
        ),
      ]
    )

    session.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/stocks/bulk")
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

      let response = try XCTUnwrap(
        HTTPURLResponse(
          url: try XCTUnwrap(request.url),
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )
      )
      return (try JSONEncoder().encode(expected), response)
    }

    let response = try await service.bulkCreate(
      stocks: [
        StockRequest(
          symbol: "AAPL",
          shares: 10,
          buyPrice: 123.45,
          buyDate: "2026-03-08",
          notes: ""
        ),
      ]
    )

    XCTAssertEqual(response, expected)
    XCTAssertEqual(authSessionManager.validAccessTokenCalls, 1)
    XCTAssertEqual(authSessionManager.refreshAccessTokenCalls, 0)
  }

  func testBulkCreate_WhenUnauthorized_RefreshesAndRetriesWithNewToken() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("expired-token")
    authSessionManager.refreshAccessTokenResult = .success("fresh-token")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )

    var requests = 0
    session.handler = { request in
      requests += 1

      if requests == 1 {
        XCTAssertEqual(request.url?.path, "/v1/stocks/bulk")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer expired-token")

        let response = try XCTUnwrap(
          HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
          )
        )
        return (#"{"error":"Access token expired"}"#.data(using: .utf8) ?? Data(), response)
      }

      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fresh-token")

      let payload = BulkCreateStocksResponse(created: 1, failed: 0, results: [])
      let response = try XCTUnwrap(
        HTTPURLResponse(
          url: try XCTUnwrap(request.url),
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )
      )
      return (try JSONEncoder().encode(payload), response)
    }

    let response = try await service.bulkCreate(
      stocks: [
        StockRequest(
          symbol: "AAPL",
          shares: 10,
          buyPrice: 123.45,
          buyDate: "2026-03-08",
          notes: nil
        ),
      ]
    )

    XCTAssertEqual(response.created, 1)
    XCTAssertEqual(requests, 2)
    XCTAssertEqual(authSessionManager.validAccessTokenCalls, 1)
    XCTAssertEqual(authSessionManager.refreshAccessTokenCalls, 1)
    XCTAssertEqual(authSessionManager.invalidateSessionCalls, 0)
  }

  func testBulkCreate_WhenRetryIsAlsoUnauthorized_InvalidatesSession() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("expired-token")
    authSessionManager.refreshAccessTokenResult = .success("fresh-token")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )

    session.handler = { request in
      let response = try XCTUnwrap(
        HTTPURLResponse(
          url: try XCTUnwrap(request.url),
          statusCode: 401,
          httpVersion: nil,
          headerFields: nil
        )
      )
      let message = request.value(forHTTPHeaderField: "Authorization") == "Bearer fresh-token"
        ? #"{"error":"Refreshed token rejected"}"#
        : #"{"error":"Access token expired"}"#
      return (message.data(using: .utf8) ?? Data(), response)
    }

    do {
      _ = try await service.bulkCreate(
        stocks: [
          StockRequest(
            symbol: "AAPL",
            shares: 10,
            buyPrice: 123.45,
            buyDate: "2026-03-08",
            notes: nil
          ),
        ]
      )
      XCTFail("Expected unauthorized error")
    } catch let error as StockHTTPClient.Error {
      XCTAssertEqual(error, .unauthorized("Refreshed token rejected"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    XCTAssertEqual(authSessionManager.refreshAccessTokenCalls, 1)
    XCTAssertEqual(authSessionManager.invalidateSessionCalls, 1)
  }

  func testFetchPortfolio_UsesVersionedStocksPath() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )
    let expected = [
      StockResponse(
        id: "stock-1",
        symbol: "AAPL",
        shares: 10,
        buyPrice: 123.45,
        buyDate: "2026-03-08",
        notes: nil
      ),
    ]

    session.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/stocks")
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

      let response = try XCTUnwrap(
        HTTPURLResponse(
          url: try XCTUnwrap(request.url),
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )
      )
      return (try JSONEncoder().encode(expected), response)
    }

    let response = try await service.fetchPortfolio()

    XCTAssertEqual(response, expected)
  }

  func testGetStockValuationEndpoint_UsesSymbolPath() throws {
    let endpoint = GetStockValuationEndpoint(symbol: "AAPL")

    XCTAssertEqual(endpoint.path, "/v1/stocks/symbol/AAPL/valuation")
    XCTAssertTrue(try endpoint.asParameters().isEmpty)
  }

  func testCreateStockValuationEndpoint_EncodesRequestBody() throws {
    let request = makeValuationRequest()
    let endpoint = CreateStockValuationEndpoint(symbol: request.symbol, payload: request)
    let parameters = try endpoint.asParameters()

    XCTAssertEqual(endpoint.path, "/v1/stocks/symbol/AAPL/valuation")
    XCTAssertEqual(parameters["symbol"] as? String, "AAPL")

    let bearCase = try XCTUnwrap(parameters["bearCase"] as? [String: Any])
    let baseCase = try XCTUnwrap(parameters["baseCase"] as? [String: Any])
    let bullCase = try XCTUnwrap(parameters["bullCase"] as? [String: Any])

    XCTAssertEqual((bearCase["low"] as? NSNumber)?.doubleValue, 100)
    XCTAssertEqual((bearCase["high"] as? NSNumber)?.doubleValue, 120)
    XCTAssertEqual((baseCase["low"] as? NSNumber)?.doubleValue, 130)
    XCTAssertEqual((baseCase["high"] as? NSNumber)?.doubleValue, 150)
    XCTAssertEqual((bullCase["low"] as? NSNumber)?.doubleValue, 160)
    XCTAssertEqual((bullCase["high"] as? NSNumber)?.doubleValue, 190)
    XCTAssertEqual(parameters["rationale"] as? String, "Margin expansion with stable demand.")
    XCTAssertEqual(parameters["targetDate"] as? String, "2026-12-31")
  }

  func testUpdateStockValuationEndpoint_UsesExplicitSymbolAndEncodesRequestBody() throws {
    let request = makeValuationRequest(symbol: "MSFT")
    let endpoint = UpdateStockValuationEndpoint(symbol: "AAPL", payload: request)
    let parameters = try endpoint.asParameters()

    XCTAssertEqual(endpoint.path, "/v1/stocks/symbol/AAPL/valuation")
    XCTAssertEqual(parameters["symbol"] as? String, "MSFT")
  }

  func testCreateStockValuationEndpoint_OmitsNilOptionalFields() throws {
    let request = makeValuationRequest(rationale: nil, targetDate: nil)
    let endpoint = CreateStockValuationEndpoint(symbol: request.symbol, payload: request)
    let parameters = try endpoint.asParameters()

    XCTAssertNil(parameters["rationale"])
    XCTAssertNil(parameters["targetDate"])

    let bearCase = try XCTUnwrap(parameters["bearCase"] as? [String: Any])
    XCTAssertEqual((bearCase["low"] as? NSNumber)?.doubleValue, 100)
    XCTAssertEqual((bearCase["high"] as? NSNumber)?.doubleValue, 120)
  }

  func testGetValuation_UsesBearerTokenAndReturnsResponse() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )
    let expected = makeValuationRequest()

    session.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/stocks/symbol/AAPL/valuation")
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

      let response = try XCTUnwrap(
        HTTPURLResponse(
          url: try XCTUnwrap(request.url),
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )
      )
      return (try JSONEncoder().encode(expected), response)
    }

    let response = try await service.getValuation(symbol: "AAPL")

    XCTAssertEqual(response, expected)
  }

  func testCreateValuation_UsesBearerTokenEncodesBodyAndFetchesSavedValuation() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )
    let expected = makeValuationRequest()
    var requests = 0

    session.handler = { request in
      requests += 1
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

      if requests == 1 {
        XCTAssertEqual(request.url?.path, "/v1/stocks/symbol/AAPL/valuation")
        XCTAssertEqual(request.httpMethod, "POST")

        let body = try XCTUnwrap(request.httpBody)
        let decoded = try JSONDecoder().decode(StockValuationRequest.self, from: body)
        XCTAssertEqual(decoded, expected)

        let response = try XCTUnwrap(
          HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
          )
        )
        return (#"\"Valuation created\""#.data(using: .utf8) ?? Data(), response)
      }

      XCTAssertEqual(request.url?.path, "/v1/stocks/symbol/AAPL/valuation")
      XCTAssertEqual(request.httpMethod, "GET")

      let response = try XCTUnwrap(
        HTTPURLResponse(
          url: try XCTUnwrap(request.url),
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )
      )
      return (try JSONEncoder().encode(expected), response)
    }

    let response = try await service.createValuation(request: expected)

    XCTAssertEqual(response, expected)
    XCTAssertEqual(requests, 2)
  }

  func testUpdateValuation_UsesBearerTokenEncodesBodyAndFetchesSavedValuation() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )
    let expected = makeValuationRequest(symbol: "AAPL")
    var requests = 0

    session.handler = { request in
      requests += 1
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

      if requests == 1 {
        XCTAssertEqual(request.url?.path, "/v1/stocks/symbol/AAPL/valuation")
        XCTAssertEqual(request.httpMethod, "PUT")

        let body = try XCTUnwrap(request.httpBody)
        let decoded = try JSONDecoder().decode(StockValuationRequest.self, from: body)
        XCTAssertEqual(decoded, expected)

        let response = try XCTUnwrap(
          HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
          )
        )
        return (#"\"Valuation updated\""#.data(using: .utf8) ?? Data(), response)
      }

      XCTAssertEqual(request.url?.path, "/v1/stocks/symbol/AAPL/valuation")
      XCTAssertEqual(request.httpMethod, "GET")

      let response = try XCTUnwrap(
        HTTPURLResponse(
          url: try XCTUnwrap(request.url),
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )
      )
      return (try JSONEncoder().encode(expected), response)
    }

    let response = try await service.updateValuation(symbol: "AAPL", request: expected)

    XCTAssertEqual(response, expected)
    XCTAssertEqual(requests, 2)
  }
}
