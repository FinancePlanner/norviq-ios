import Foundation
import StockPlanShared
import XCTest

@testable import financeplan

@MainActor
final class CryptoBillingGateTests: XCTestCase {
  private final class SessionMock: MarketDataURLSessionProtocol, @unchecked Sendable {
    var handler: ((URLRequest) throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      guard let handler else {
        fatalError("SessionMock.handler must be configured before use")
      }
      return try handler(request)
    }
  }

  // MARK: - HTTP-level gating

  func testFetchCryptoList_returns403_surfacesUpgradeRequiredAsInvalidStatus() async {
    let session = SessionMock()
    let baseURL = URL(string: "https://api.example.com")!
    let body = """
    {
      "success": false,
      "code": "upgrade_required",
      "feature": "crypto",
      "plan": "free",
      "requiredPlan": "pro"
    }
    """.data(using: .utf8) ?? Data()

    session.handler = { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 403,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      return (body, response)
    }

    let client = CryptoHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: { "token-free" }
    )

    do {
      _ = try await client.fetchCryptoList()
      XCTFail("Expected upgrade_required to throw")
    } catch let error as CryptoHTTPClient.Error {
      XCTAssertEqual(error.statusCode, 403)
      XCTAssertFalse(error.isUnauthorized)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testFetchCryptoList_returns200_decodesPayload() async throws {
    let session = SessionMock()
    let baseURL = URL(string: "https://api.example.com")!

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.path, "/v1/crypto/list")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-pro")

      let payload = """
      [
        {"symbol": "BTC", "name": "Bitcoin", "exchange": "coinbase", "type": "crypto"}
      ]
      """.data(using: .utf8) ?? Data()
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      return (payload, response)
    }

    let client = CryptoHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: { "token-pro" }
    )
    let assets = try await client.fetchCryptoList()

    XCTAssertEqual(assets.count, 1)
    XCTAssertEqual(assets.first?.symbol, "BTC")
  }

  func testFetchCryptoList_returns401_surfacesUnauthorized() async {
    let session = SessionMock()
    let baseURL = URL(string: "https://api.example.com")!

    session.handler = { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 401,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      return (Data(), response)
    }

    let client = CryptoHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: { "token-expired" }
    )

    do {
      _ = try await client.fetchCryptoList()
      XCTFail("Expected unauthorized")
    } catch let error as CryptoHTTPClient.Error {
      XCTAssertTrue(error.isUnauthorized)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testAddToCryptoPortfolio_returns403_blocksFreeUser() async {
    let session = SessionMock()
    let baseURL = URL(string: "https://api.example.com")!

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/crypto/portfolio")
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 403,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      return (Data(), response)
    }

    let client = CryptoHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: { "token-free" }
    )

    do {
      _ = try await client.addToPortfolio(
        payload: CryptoPortfolioItemRequest(
          symbol: "BTC",
          name: "Bitcoin",
          quantity: 1,
          averageBuyPrice: 50_000
        )
      )
      XCTFail("Expected 403")
    } catch let error as CryptoHTTPClient.Error {
      XCTAssertEqual(error.statusCode, 403)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  // MARK: - BillingContextResponse parsing

  func testBillingContextResponse_decodesCryptoFeatureUnavailable() throws {
    let json = """
    {
      "plan": "free",
      "entitlementLevel": "free",
      "isPremium": false,
      "subscription": null,
      "features": [
        {
          "key": "crypto",
          "title": "Cryptocurrency",
          "available": false,
          "requiredPlan": "pro",
          "reason": null,
          "limit": null,
          "used": null,
          "remaining": null
        }
      ],
      "usage": [],
      "trialDaysRemaining": null,
      "isTrialActive": false,
      "generatedAt": "2026-01-01T00:00:00Z"
    }
    """.data(using: .utf8) ?? Data()

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let context = try decoder.decode(BillingContextResponse.self, from: json)

    let crypto = try XCTUnwrap(context.features.first { $0.key == "crypto" })
    XCTAssertFalse(crypto.available)
    XCTAssertEqual(crypto.requiredPlan, "pro")
    XCTAssertFalse(context.isPremium)
  }

  func testBillingContextResponse_decodesCryptoFeatureAvailableForTrial() throws {
    let json = """
    {
      "plan": "temporary",
      "entitlementLevel": "temporary",
      "isPremium": true,
      "subscription": null,
      "features": [
        {
          "key": "crypto",
          "title": "Cryptocurrency",
          "available": true,
          "requiredPlan": null,
          "reason": null,
          "limit": null,
          "used": null,
          "remaining": null
        }
      ],
      "usage": [],
      "trialDaysRemaining": 7,
      "isTrialActive": true,
      "generatedAt": "2026-01-01T00:00:00Z"
    }
    """.data(using: .utf8) ?? Data()

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let context = try decoder.decode(BillingContextResponse.self, from: json)

    let crypto = try XCTUnwrap(context.features.first { $0.key == "crypto" })
    XCTAssertTrue(crypto.available)
    XCTAssertTrue(context.isPremium)
    XCTAssertTrue(context.isTrialActive)
  }
}
