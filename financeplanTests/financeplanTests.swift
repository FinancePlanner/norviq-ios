//
//  financeplanTests.swift
//  financeplanTests
//
//  Created by Fernando Correia on 12.02.26.
//

import XCTest
@testable import financeplan
import StockPlanShared

final class FinanceplanTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

@MainActor
final class BillingManagerTests: XCTestCase {
  private var environmentManager: AppEnvironmentManager!
  private var authSessionManager: MockAuthSessionManager!
  private var sessionStore: MockAuthSessionStore!

  override func setUp() async throws {
    environmentManager = AppEnvironmentManager()
    authSessionManager = MockAuthSessionManager()
    sessionStore = MockAuthSessionStore()
  }

  func testIsProReturnsTrueWhenPremium() {
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore
    )

    sut.context = makeBillingContext(entitlementLevel: "basic", isPremium: true)

    XCTAssertTrue(sut.isPro)
  }

  func testIsProReturnsTrueWhenEntitlementLevelIsPro() {
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore
    )

    sut.context = makeBillingContext(entitlementLevel: "pro", isPremium: false)

    XCTAssertTrue(sut.isPro)
  }

  func testIsProReturnsTrueForTemporaryTrialEntitlement() {
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore
    )

    sut.context = makeBillingContext(
      entitlementLevel: "temporary",
      isPremium: true,
      trialDaysRemaining: 7,
      isTrialActive: true
    )

    XCTAssertTrue(sut.isPro)
    XCTAssertEqual(sut.trialDaysRemaining, 7)
  }

  func testIsProReturnsFalseWhenNotPremiumAndNotProLevel() {
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore
    )

    sut.context = makeBillingContext(entitlementLevel: "free", isPremium: false)

    // Clear user defaults cache to ensure it evaluates from context
    UserDefaults.standard.removeObject(forKey: "billing.is_pro")

    XCTAssertFalse(sut.isPro)
  }

  func testFeatureAvailabilityUsesServerFeatureDescriptor() {
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore
    )

    sut.context = makeBillingContext(
      entitlementLevel: "free",
      isPremium: false,
      features: [
        BillingFeatureDTO(
          key: "advanced_research",
          title: "Advanced research",
          available: false,
          requiredPlan: "pro",
          reason: "Upgrade required",
          limit: nil,
          used: nil,
          remaining: nil
        ),
      ]
    )

    XCTAssertFalse(sut.isFeatureAvailable("advanced_research"))
  }

  func testRedeemCouponAppliesReturnedProContext() async {
    authSessionManager.validAccessTokenResult = .success("token-123")
    let proContext = makeBillingContext(entitlementLevel: "pro", isPremium: true)
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore,
      billingClientFactory: { _, _ in
        BillingHTTPClient(
          baseURL: URL(string: "https://example.test")!,
          session: BillingSessionMock(response: .success(.couponRedemption(context: proContext))),
          authTokenProvider: { "token-123" }
        )
      }
    )

    await sut.redeemCoupon(code: " forever ")

    XCTAssertEqual(sut.context?.entitlementLevel, "pro")
    XCTAssertTrue(sut.isPro)
    XCTAssertEqual(sut.couponRedemptionMessage, "Coupon redeemed. Pro is active.")
    XCTAssertNil(sut.errorMessage)
  }

  func testRedeemCouponErrorLeavesCurrentEntitlementUnchanged() async {
    authSessionManager.validAccessTokenResult = .success("token-123")
    let existingContext = makeBillingContext(entitlementLevel: "free", isPremium: false)
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore,
      billingClientFactory: { _, _ in
        BillingHTTPClient(
          baseURL: URL(string: "https://example.test")!,
          session: BillingSessionMock(response: .failure(statusCode: 400, message: "Invalid coupon code.")),
          authTokenProvider: { "token-123" }
        )
      }
    )
    sut.context = existingContext

    await sut.redeemCoupon(code: "bad")

    XCTAssertEqual(sut.context, existingContext)
    XCTAssertEqual(sut.errorMessage, "Invalid coupon code.")
    XCTAssertNil(sut.couponRedemptionMessage)
  }

  func testIsProFallsBackToUserDefaultsWhenContextIsNil() {
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore
    )

    sut.context = nil
    UserDefaults.standard.set(true, forKey: "billing.is_pro")

    XCTAssertTrue(sut.isPro)

    UserDefaults.standard.set(false, forKey: "billing.is_pro")

    XCTAssertFalse(sut.isPro)
  }

  private func makeBillingContext(
    entitlementLevel: String,
    isPremium: Bool,
    features: [BillingFeatureDTO] = [],
    trialDaysRemaining: Int? = nil,
    isTrialActive: Bool = false
  ) -> BillingContextResponse {
    BillingContextResponse(
      plan: entitlementLevel,
      entitlementLevel: entitlementLevel,
      isPremium: isPremium,
      subscription: nil,
      features: features,
      usage: [],
      trialDaysRemaining: trialDaysRemaining,
      isTrialActive: isTrialActive,
      generatedAt: Date()
    )
  }
}

@MainActor
final class BillingHTTPClientTests: XCTestCase {
  func testRedeemCouponEncodesCodeAndAuthHeader() async throws {
    let session = BillingSessionMock(response: .success(.couponRedemption(context: makeContext())))
    let client = BillingHTTPClient(
      baseURL: URL(string: "https://api.example.test")!,
      session: session,
      authTokenProvider: { "access-token" }
    )

    _ = try await client.redeemCoupon(code: "Life123")

    let request = try XCTUnwrap(session.requests.first)
    XCTAssertEqual(request.url?.path, "/v1/billing/coupons/redeem")
    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")

    let body = try XCTUnwrap(request.httpBody)
    let payload = try JSONSerialization.jsonObject(with: body) as? [String: String]
    XCTAssertEqual(payload?["code"], "Life123")
  }

  private func makeContext() -> BillingContextResponse {
    BillingContextResponse(
      plan: "pro",
      entitlementLevel: "pro",
      isPremium: true,
      subscription: nil,
      features: [],
      usage: [],
      generatedAt: Date(timeIntervalSinceReferenceDate: 0)
    )
  }
}

// Minimal mocks for testing
private final class MockAuthSessionManager: AuthSessionManaging, @unchecked Sendable {
  var validAccessTokenResult: Result<String?, Error> = .success(nil)
  var refreshAccessTokenResult: Result<String?, Error> = .success(nil)

  func logout() async {}
  func reset() {}
  func restoreSessionIfNeeded() async -> Bool { return false }
  func invalidateSession() async {}
  func onSessionConfigured() {}
  func validAccessToken() async throws -> String? { try validAccessTokenResult.get() }
  func refreshAccessToken() async throws -> String? { try refreshAccessTokenResult.get() }
}

private final class MockAuthSessionStore: AuthSessionStoring, @unchecked Sendable {
  private var _authToken = ""
  var authToken: String { get async { _authToken } }
  private var _refreshToken = ""
  var refreshToken: String { get async { _refreshToken } }
  private var _authTokenExpiresAt: Date? = nil
  var authTokenExpiresAt: Date? { get async { _authTokenExpiresAt } }
  private var _refreshTokenExpiresAt: Date? = nil
  var refreshTokenExpiresAt: Date? { get async { _refreshTokenExpiresAt } }
  private var _loginIsSignup = false
  var loginIsSignup: Bool { get async { _loginIsSignup } }
  private var _currentUserID = "mock-user-id"
  var currentUserID: String { get async { _currentUserID } }
  private var _currentUsername = "mock-user"
  var currentUsername: String { get async { _currentUsername } }
  var isSetupComplete = false
  var hasPassedSecurity = false
  var hasAppLockEnabled = false
  var currentSecurityCodeHash: String? = nil

  func setAuthToken(_ value: String) async { _authToken = value }
  func setRefreshToken(_ value: String) async { _refreshToken = value }
  func setAuthTokenExpiresAt(_ value: Date?) async { _authTokenExpiresAt = value }
  func setRefreshTokenExpiresAt(_ value: Date?) async { _refreshTokenExpiresAt = value }
  func setLoginIsSignup(_ value: Bool) async { _loginIsSignup = value }
  func setCurrentUserID(_ value: String) async { _currentUserID = value }
  func setCurrentUsername(_ value: String) async { _currentUsername = value }

  func store(authResponse: StockPlanShared.AuthResponse) async {}
  func saveTokens(access: String, refresh: String) throws {}
  func loadTokens() throws -> (access: String, refresh: String)? { return nil }
  func clearTokens() throws {}
  func saveUserProfile(id: String, username: String) {}
  func clearSession() async {}
  func hasCompletedInitialStockImport(for userID: String) async -> Bool { return false }
  func markInitialStockImportCompleted(for userID: String) async {}
  func hasCompletedOnboardingQuestionnaire(for userID: String) async -> Bool { return false }
  func markOnboardingQuestionnaireCompleted(for userID: String) async {}
  func requiresOnboardingQuestionnaire(for userID: String) async -> Bool { return false }
  func markOnboardingQuestionnaireRequired(for userID: String) async {}
  func markPendingOnboardingAfterSignup(email: String) async {}
  func hasPendingOnboardingAfterSignup(email: String) async -> Bool { return false }
  func clearPendingOnboardingAfterSignup(email: String) async {}
}

private final class BillingSessionMock: PushNotificationsURLSessionProtocol, @unchecked Sendable {
  enum Response {
    case success(Payload)
    case failure(statusCode: Int, message: String)
  }

  enum Payload {
    case couponRedemption(context: BillingContextResponse)
  }

  private(set) var requests: [URLRequest] = []
  private let response: Response

  init(response: Response) {
    self.response = response
  }

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    requests.append(request)
    let statusCode: Int
    let data: Data
    switch response {
    case let .success(payload):
      statusCode = 200
      data = try payloadData(payload)
    case let .failure(code, message):
      statusCode = code
      data = try JSONSerialization.data(withJSONObject: ["error": message])
    }

    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: ["Content-Type": "application/json"]
    )!
    return (data, response)
  }

  private func payloadData(_ payload: Payload) throws -> Data {
    switch payload {
    case let .couponRedemption(context):
      let encodedContext = try JSONEncoder.stockPlanShared.encode(context)
      let contextObject = try JSONSerialization.jsonObject(with: encodedContext) as? [String: Any]
      return try JSONSerialization.data(withJSONObject: [
        "coupon": [
          "code": "FOREVER",
          "grantType": "lifetime_pro",
          "trialDays": 0,
          "discount": [:],
        ],
        "trialDaysRemaining": NSNull(),
        "isTrialActive": false,
        "billingContext": contextObject ?? [:],
      ])
    }
  }
}
