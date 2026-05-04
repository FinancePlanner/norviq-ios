import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class StockServiceTests: XCTestCase {
  private final class SessionMock: StockURLSessionProtocol, @unchecked Sendable, @unchecked Sendable {
    var handler: ((URLRequest) throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard let handler else {
        fatalError("SessionMock.handler must be configured before use")
      }

      return try handler(request)
    }
  }

  private final class AuthSessionManagerMock: AuthSessionManaging, @unchecked Sendable {
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

  private let bearLow = 100.0
  private let bearHigh = 120.0
  private let baseLow = 130.0
  private let baseHigh = 150.0
  private let bullLow = 160.0
  private let bullHigh = 190.0

  func testBulkCreate_UsesBearerTokenAndReturnsResponse() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )
    let expected = BulkStockResponse(
      created: 1,
      failed: 0,
      results: [
        BulkStockResultItem(
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
        )
      ]
    )

    session.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/stocks/bulk")
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

      let body = try XCTUnwrap(request.httpBody)
      let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
      let stocks = try XCTUnwrap(json["stocks"] as? [[String: Any]])
      let firstStock = try XCTUnwrap(stocks.first)

      XCTAssertEqual((firstStock["shares"] as? NSNumber)?.doubleValue, 10)
      XCTAssertEqual((firstStock["buyPrice"] as? NSNumber)?.doubleValue, 123.45)
      XCTAssertEqual(firstStock["buyDate"] as? String, "2026-03-08")
      XCTAssertEqual(firstStock["symbol"] as? String, "AAPL")
      XCTAssertNil(firstStock["buy_price"])
      XCTAssertNil(firstStock["buy_date"])

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
        )
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

      let payload = BulkStockResponse(created: 1, failed: 0, results: [])
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
        )
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
          )
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
      )
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

    XCTAssertEqual(response.items, expected)
  }

  func testFetchPortfolioSummary_UsesSummaryEndpointAndDecodesPayload() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )
    let expected = PortfolioSummaryResponse(
      baseCurrency: "USD",
      totalValue: 25_000,
      totalCost: 20_000,
      unrealizedPnl: 4_000,
      realizedPnl: 1_000,
      allocation: [
        AllocationItem(symbol: "AAPL", value: 20_000, currency: "USD"),
        AllocationItem(symbol: "CASH", value: 5_000, currency: "USD")
      ]
    )

    session.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/portfolio/summary")
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

    let response = try await service.fetchPortfolioSummary()
    XCTAssertEqual(response, expected)
  }

  func testSellStock_UsesSellEndpointAndSendsPayload() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )
    let sellRequest = SellStockRequest(
      sharesToSell: 3,
      sellPrice: 220,
      sellDate: "2026-04-10"
    )
    let expected = StockResponse(
      id: "stock-1",
      symbol: "AAPL",
      shares: 7,
      buyPrice: 150,
      buyDate: "2026-03-08",
      notes: nil
    )

    session.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/stocks/id/stock-1/sell")
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

      let body = try XCTUnwrap(request.httpBody)
      let decoded = try JSONDecoder.stockPlanShared.decode(SellStockRequest.self, from: body)
      XCTAssertEqual(decoded, sellRequest)

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

    let response = try await service.sellStock(id: "stock-1", request: sellRequest)
    XCTAssertEqual(response, expected)
  }

  func testFetchTargets_UsesTargetsEndpointWithSymbolFilter() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )
    let expected = [
      TargetResponse(
        id: "target-1",
        symbol: "AAPL",
        scenario: "base",
        targetPrice: 220,
        targetDate: nil,
        rationale: "Portfolio alert for AAPL"
      )
    ]

    session.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/targets")
      XCTAssertEqual(request.url?.query, "symbol=AAPL")
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

    let response = try await service.fetchTargets(symbol: " aapl ")
    XCTAssertEqual(response, expected)
  }

  func testCreateTarget_UsesTargetsEndpointAndSendsPayload() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )
    let request = TargetRequest(
      symbol: "AAPL",
      scenario: "base",
      targetPrice: 220,
      targetDate: nil,
      rationale: "Portfolio alert for AAPL"
    )
    let expected = TargetResponse(
      id: "target-1",
      symbol: "AAPL",
      scenario: "base",
      targetPrice: 220,
      targetDate: nil,
      rationale: "Portfolio alert for AAPL"
    )

    session.handler = { urlRequest in
      XCTAssertEqual(urlRequest.url?.path, "/v1/targets")
      XCTAssertEqual(urlRequest.httpMethod, "POST")
      XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

      let body = try XCTUnwrap(urlRequest.httpBody)
      let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
      XCTAssertEqual(json["symbol"] as? String, "AAPL")
      XCTAssertEqual(json["scenario"] as? String, "base")
      XCTAssertEqual((json["targetPrice"] as? NSNumber)?.doubleValue, 220)
      XCTAssertEqual(json["rationale"] as? String, "Portfolio alert for AAPL")
      XCTAssertNil(json["targetDate"])

      let response = try XCTUnwrap(
        HTTPURLResponse(
          url: try XCTUnwrap(urlRequest.url),
          statusCode: 201,
          httpVersion: nil,
          headerFields: nil
        )
      )
      return (try JSONEncoder().encode(expected), response)
    }

    let response = try await service.createTarget(request)
    XCTAssertEqual(response, expected)
  }

  func testDeleteTarget_UsesTargetIdEndpoint() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )

    session.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/targets/target-1")
      XCTAssertEqual(request.httpMethod, "DELETE")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

      let response = try XCTUnwrap(
        HTTPURLResponse(
          url: try XCTUnwrap(request.url),
          statusCode: 204,
          httpVersion: nil,
          headerFields: nil
        )
      )
      return (Data(), response)
    }

    try await service.deleteTarget(id: "target-1")
  }

  func testFetchStockInsights_UsesInsightsEndpointAndDecodesPayload() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )
    let expected = StockInsightsResponse(
      generatedAt: "2026-04-09T09:00:00Z",
      symbol: "AAPL",
      profile: StockInsightProfileDTO(
        symbol: "AAPL",
        companyName: "Apple Inc",
        currentPrice: 187.42,
        marketCap: 2_950_000_000_000,
        sharesOutstanding: 15_700_000_000,
        metrics: ["ttmPE": 29.1, "forwardPE": 27.4],
        dcfBasePrice: 200,
        dcfBearPrice: 160,
        dcfBullPrice: 240
      ),
      peers: [
        StockInsightPeerDTO(
          symbol: "MSFT",
          companyName: "Microsoft Corporation",
          currentPrice: 415.3,
          marketCap: 3_100_000_000_000,
          sharesOutstanding: 7_400_000_000
        )
      ],
      projectionScenarios: [
        StockInsightProjectionScenarioDTO(
          kind: "base",
          years: [
            StockInsightProjectionYearDTO(
              year: 2027,
              revenue: 420_000_000_000,
              revenueGrowth: 0.06,
              netIncome: 110_000_000_000,
              netIncomeGrowth: 0.07,
              netMargin: 0.26,
              eps: 7.0,
              peLowEstimate: 18,
              peHighEstimate: 24,
              sharePriceLow: 126,
              sharePriceHigh: 168,
              cagrLow: -0.1,
              cagrHigh: -0.05
            )
          ]
        )
      ]
    )

    session.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/stocks/symbol/AAPL/insights")
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

    let response = try await service.fetchStockInsights(symbol: "AAPL")
    XCTAssertEqual(response, expected)
  }

  func testGetStockValuationEndpoint_UsesSymbolPath() throws {
    let endpoint = GetStockValuationEndpoint(symbol: "AAPL")

    XCTAssertEqual(endpoint.path, "/v1/stocks/symbol/AAPL/valuation")
    XCTAssertTrue(try endpoint.asParameters().isEmpty)
  }

  func testCreateStockValuationEndpoint_EncodesRequestBody() throws {
    let endpoint = try CreateStockValuationEndpoint(
      symbol: "AAPL",
      bearLow: bearLow,
      bearHigh: bearHigh,
      baseLow: baseLow,
      baseHigh: baseHigh,
      bullLow: bullLow,
      bullHigh: bullHigh,
      rationale: "Margin expansion with stable demand.",
      targetDate: "2026-12-31"
    )

    XCTAssertEqual(endpoint.path, "/v1/stocks/symbol/AAPL/valuation")
    XCTAssertTrue(try endpoint.asParameters().isEmpty)

    let bodyEndpoint = try XCTUnwrap(endpoint as? any StockRequestBodyEndpoint)
    let body = try XCTUnwrap(bodyEndpoint.bodyData())
    let decoded = try JSONDecoder().decode(StockValuationRequest.self, from: body)

    XCTAssertEqual(decoded, makeValuationRequest())
  }

  func testCreateStockValuationEndpoint_PreservesExactDraftNumbersInJSON() throws {
    let endpoint = try CreateStockValuationEndpoint(
      symbol: "ORO",
      bearLow: 1,
      bearHigh: 2,
      baseLow: 3,
      baseHigh: 4,
      bullLow: 5,
      bullHigh: 6,
      rationale: nil,
      targetDate: nil
    )
    let bodyEndpoint = try XCTUnwrap(endpoint as? any StockRequestBodyEndpoint)
    let body = try XCTUnwrap(bodyEndpoint.bodyData())
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

    XCTAssertEqual(json["symbol"] as? String, "ORO")

    let bearCase = try XCTUnwrap(json["bearCase"] as? [String: Any])
    let baseCase = try XCTUnwrap(json["baseCase"] as? [String: Any])
    let bullCase = try XCTUnwrap(json["bullCase"] as? [String: Any])

    XCTAssertEqual((bearCase["low"] as? NSNumber)?.doubleValue, 1)
    XCTAssertEqual((bearCase["high"] as? NSNumber)?.doubleValue, 2)
    XCTAssertEqual((baseCase["low"] as? NSNumber)?.doubleValue, 3)
    XCTAssertEqual((baseCase["high"] as? NSNumber)?.doubleValue, 4)
    XCTAssertEqual((bullCase["low"] as? NSNumber)?.doubleValue, 5)
    XCTAssertEqual((bullCase["high"] as? NSNumber)?.doubleValue, 6)
  }

  func testUpdateStockValuationEndpoint_UsesExplicitSymbolAndEncodesRequestBody() throws {
    let endpoint = try UpdateStockValuationEndpoint(
      symbol: "AAPL",
      bearLow: bearLow,
      bearHigh: bearHigh,
      baseLow: baseLow,
      baseHigh: baseHigh,
      bullLow: bullLow,
      bullHigh: bullHigh,
      rationale: "Margin expansion with stable demand.",
      targetDate: "2026-12-31"
    )

    XCTAssertEqual(endpoint.path, "/v1/stocks/symbol/AAPL/valuation")
    XCTAssertTrue(try endpoint.asParameters().isEmpty)

    let bodyEndpoint = try XCTUnwrap(endpoint as? any StockRequestBodyEndpoint)
    let body = try XCTUnwrap(bodyEndpoint.bodyData())
    let decoded = try JSONDecoder().decode(StockValuationRequest.self, from: body)

    XCTAssertEqual(decoded, makeValuationRequest())
  }

  func testCreateStockValuationEndpoint_OmitsNilOptionalFields() throws {
    let endpoint = try CreateStockValuationEndpoint(
      symbol: "AAPL",
      bearLow: bearLow,
      bearHigh: bearHigh,
      baseLow: baseLow,
      baseHigh: baseHigh,
      bullLow: bullLow,
      bullHigh: bullHigh,
      rationale: nil,
      targetDate: nil
    )
    let bodyEndpoint = try XCTUnwrap(endpoint as? any StockRequestBodyEndpoint)
    let body = try XCTUnwrap(bodyEndpoint.bodyData())
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

    XCTAssertNil(json["rationale"])
    XCTAssertNil(json["targetDate"])

    let bearCase = try XCTUnwrap(json["bearCase"] as? [String: Any])
    XCTAssertEqual((bearCase["low"] as? NSNumber)?.doubleValue, 100)
    XCTAssertEqual((bearCase["high"] as? NSNumber)?.doubleValue, 120)
  }

  func testCreateStockValuationEndpoint_UsesDirectBodyEncoding() throws {
    let endpoint = try CreateStockValuationEndpoint(
      symbol: "AAPL",
      bearLow: bearLow,
      bearHigh: bearHigh,
      baseLow: baseLow,
      baseHigh: baseHigh,
      bullLow: bullLow,
      bullHigh: bullHigh,
      rationale: "Margin expansion with stable demand.",
      targetDate: "2026-12-31"
    )

    XCTAssertTrue(endpoint is any StockRequestBodyEndpoint)

    let bodyEndpoint = try XCTUnwrap(endpoint as? any StockRequestBodyEndpoint)
    let body = try XCTUnwrap(bodyEndpoint.bodyData())
    let decoded = try JSONDecoder().decode(StockValuationRequest.self, from: body)

    XCTAssertEqual(decoded, makeValuationRequest())
  }

  func testUpdateStockValuationEndpoint_UsesDirectBodyEncoding() throws {
    let endpoint = try UpdateStockValuationEndpoint(
      symbol: "AAPL",
      bearLow: bearLow,
      bearHigh: bearHigh,
      baseLow: baseLow,
      baseHigh: baseHigh,
      bullLow: bullLow,
      bullHigh: bullHigh,
      rationale: "Margin expansion with stable demand.",
      targetDate: "2026-12-31"
    )

    XCTAssertTrue(endpoint is any StockRequestBodyEndpoint)

    let bodyEndpoint = try XCTUnwrap(endpoint as? any StockRequestBodyEndpoint)
    let body = try XCTUnwrap(bodyEndpoint.bodyData())
    let decoded = try JSONDecoder().decode(StockValuationRequest.self, from: body)

    XCTAssertEqual(decoded, makeValuationRequest())
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

  func testGetValuation_DecodesLiteralResponseJSONForRationaleAndTargetDate() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )

    session.handler = { request in
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

      let payload = #"""
      {
        "symbol": "AAPL",
        "bear_case": { "low": 100, "high": 120 },
        "base_case": { "low": 130, "high": 150 },
        "bull_case": { "low": 160, "high": 190 },
        "rationale": "Margin expansion with stable demand.",
        "target_date": "2026-12-31"
      }
      """#.data(using: .utf8) ?? Data()

      return (payload, response)
    }

    let response = try await service.getValuation(symbol: "AAPL")

    XCTAssertEqual(response.rationale, "Margin expansion with stable demand.")
    XCTAssertEqual(response.targetDate, "2026-12-31")
  }

  func testCreateValuation_UsesBearerTokenAndDecodesResponseBody() async throws {
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
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

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
      return (try JSONEncoder().encode(expected), response)
    }

    let response = try await service.createValuation(
      symbol: "AAPL",
      bearLow: bearLow,
      bearHigh: bearHigh,
      baseLow: baseLow,
      baseHigh: baseHigh,
      bullLow: bullLow,
      bullHigh: bullHigh,
      rationale: "Margin expansion with stable demand.",
      targetDate: "2026-12-31"
    )

    XCTAssertEqual(response, expected)
  }

  func testCreateValuation_UsesDraftNumbersExactlyInRequestBody() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )
    let expected = StockValuationRequest(
      symbol: "ORO",
      bearCase: PriceRange(low: 1, high: 2),
      baseCase: PriceRange(low: 3, high: 4),
      bullCase: PriceRange(low: 5, high: 6),
      rationale: nil,
      targetDate: nil
    )

    session.handler = { request in
      let body = try XCTUnwrap(request.httpBody)
      let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

      XCTAssertEqual(json["symbol"] as? String, "ORO")

      let bearCase = try XCTUnwrap(json["bearCase"] as? [String: Any])
      let baseCase = try XCTUnwrap(json["baseCase"] as? [String: Any])
      let bullCase = try XCTUnwrap(json["bullCase"] as? [String: Any])

      XCTAssertEqual((bearCase["low"] as? NSNumber)?.doubleValue, 1)
      XCTAssertEqual((bearCase["high"] as? NSNumber)?.doubleValue, 2)
      XCTAssertEqual((baseCase["low"] as? NSNumber)?.doubleValue, 3)
      XCTAssertEqual((baseCase["high"] as? NSNumber)?.doubleValue, 4)
      XCTAssertEqual((bullCase["low"] as? NSNumber)?.doubleValue, 5)
      XCTAssertEqual((bullCase["high"] as? NSNumber)?.doubleValue, 6)

      let response = try XCTUnwrap(
        HTTPURLResponse(
          url: try XCTUnwrap(request.url),
          statusCode: 201,
          httpVersion: nil,
          headerFields: nil
        )
      )
      return (try JSONEncoder().encode(expected), response)
    }

    let response = try await service.createValuation(
      symbol: "ORO",
      bearLow: 1,
      bearHigh: 2,
      baseLow: 3,
      baseHigh: 4,
      bullLow: 5,
      bullHigh: 6,
      rationale: nil,
      targetDate: nil
    )

    XCTAssertEqual(response, expected)
  }

  func testUpdateValuation_UsesBearerTokenAndDecodesResponseBody() async throws {
    let session = SessionMock()
    let authSessionManager = AuthSessionManagerMock()
    authSessionManager.validAccessTokenResult = .success("token-123")
    let service = StockService(
      environmentManager: AppEnvironmentManager(),
      session: session,
      authSessionManager: authSessionManager
    )
    let expected = makeValuationRequest(symbol: "AAPL")

    session.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/stocks/symbol/AAPL/valuation")
      XCTAssertEqual(request.httpMethod, "PUT")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

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
      return (try JSONEncoder().encode(expected), response)
    }

    let response = try await service.updateValuation(
      symbol: "AAPL",
      bearLow: bearLow,
      bearHigh: bearHigh,
      baseLow: baseLow,
      baseHigh: baseHigh,
      bullLow: bullLow,
      bullHigh: bullHigh,
      rationale: "Margin expansion with stable demand.",
      targetDate: "2026-12-31"
    )

    XCTAssertEqual(response, expected)
  }
}
