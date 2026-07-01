//
//  financeplanTests.swift
//  financeplanTests
//
//  Created by Fernando Correia on 12.02.26.
//

import XCTest
@testable import financeplan
import StockPlanShared
import Foundation

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

  func testSelectingMonthlyWithoutPackagesUpdatesSelectedProductID() {
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore
    )

    sut.select(productID: "pro_monthly")

    XCTAssertEqual(sut.selectedProductID, "pro_monthly")
    XCTAssertNil(sut.selectedPackage)
  }

  func testSelectingWeeklyWithoutPackagesUpdatesSelectedProductID() {
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore
    )

    sut.select(productID: "pro_weekly")

    XCTAssertEqual(sut.selectedProductID, "pro_weekly")
    XCTAssertNil(sut.selectedPackage)
  }

  func testPurchasingUnavailableSelectedPlanReturnsFalseAndSetsPlanSpecificError() async {
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore
    )
    sut.select(productID: "pro_monthly")

    let didPurchase = await sut.purchaseSelectedPackage()

    XCTAssertFalse(didPurchase)
    XCTAssertEqual(sut.errorMessage, "Monthly plan is currently unavailable. Please try again later.")
  }

  func testPurchaseCTATitleShowsUnavailableWithoutLoadedPackage() {
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore
    )

    sut.select(productID: "pro_monthly")
    XCTAssertFalse(sut.canPurchaseSelectedPackage)
    XCTAssertEqual(sut.purchaseCTATitle, "Subscriptions Unavailable")
    XCTAssertEqual(sut.subscriptionDisclosureText, "Subscriptions are currently unavailable. Please try again later.")

    sut.select(productID: "pro_weekly")
    XCTAssertFalse(sut.canPurchaseSelectedPackage)
    XCTAssertEqual(sut.purchaseCTATitle, "Subscriptions Unavailable")
  }

  func testSelectedPlanHasFreeTrialIsFalseWithoutPackages() {
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore
    )

    sut.select(productID: "pro_annual")
    XCTAssertFalse(sut.selectedPlanHasFreeTrial)
  }

  func testClearCacheResetsSelectionToAnnual() {
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore
    )
    sut.select(productID: "pro_weekly")

    sut.clearCache()

    XCTAssertEqual(sut.selectedProductID, "pro_annual")
    XCTAssertNil(sut.selectedPackage)
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

  func testManageSubscriptionUsesBackendManagementURLForAuthenticatedUser() async throws {
    let session = BillingSessionMock()
    let recorder = SubscriptionURLRecorder()
    authSessionManager.validAccessTokenResult = .success("token-123")

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/billing/management-url")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")

      let data = """
      {
        "managementUrl": "https://billing.revenuecat.com/session/abc?token=123",
        "provider": "rc_billing",
        "source": "revenuecat_customer_portal"
      }
      """.data(using: .utf8) ?? Data()
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
      )
      return (data, response)
    }

    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore,
      billingClientFactory: { baseURL, token in
        BillingHTTPClient(
          baseURL: baseURL,
          session: session,
          authTokenProvider: { token }
        )
      },
      subscriptionURLOpener: { recorder.open($0) }
    )

    await sut.manageSubscription()

    XCTAssertEqual(recorder.openedURLs.map(\.absoluteString), [
      "https://billing.revenuecat.com/session/abc?token=123",
    ])
    XCTAssertNil(sut.errorMessage)
  }

  func testManageSubscriptionFallsBackToAppleWhenNoBackendUser() async {
    let session = BillingSessionMock()
    let recorder = SubscriptionURLRecorder()
    await sessionStore.setCurrentUserID("")

    session.handler = { request in
      XCTFail("Expected no backend call, got \(request.url?.absoluteString ?? "<nil>")")
      return (Data(), URLResponse())
    }

    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore,
      billingClientFactory: { baseURL, token in
        BillingHTTPClient(
          baseURL: baseURL,
          session: session,
          authTokenProvider: { token }
        )
      },
      subscriptionURLOpener: { recorder.open($0) }
    )

    await sut.manageSubscription()

    XCTAssertEqual(recorder.openedURLs.map(\.absoluteString), [
      "https://apps.apple.com/account/subscriptions",
    ])
  }

  func testRestorePurchasesConfiguresAnonymousWhenNoBackendUser() async {
    await sessionStore.setCurrentUserID("")

    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore,
      revenueCatAPIKeyProvider: { nil }
    )

    await sut.restorePurchases()

    XCTAssertEqual(sut.errorMessage, "RevenueCat API key is not configured.")
  }

  func testRestoreResultShowsNoActivePurchaseMessageWhenBackendStaysFree() {
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore
    )

    sut.recordRestoreResult(
      foundActiveRevenueCatEntitlement: false,
      syncedContext: makeBillingContext(entitlementLevel: "free", isPremium: false)
    )

    XCTAssertEqual(sut.restoreStatusMessage, "No active purchases found for this account.")
    XCTAssertFalse(sut.restoreStatusIsSuccess)
    XCTAssertFalse(sut.isPro)
  }

  func testRestoreResultShowsSuccessWhenBackendReturnsPremium() {
    let sut = BillingManager(
      environmentManager: environmentManager,
      authSessionManager: authSessionManager,
      sessionStore: sessionStore
    )

    sut.recordRestoreResult(
      foundActiveRevenueCatEntitlement: false,
      syncedContext: makeBillingContext(entitlementLevel: "pro_monthly", isPremium: true)
    )

    XCTAssertEqual(sut.restoreStatusMessage, "Purchases restored. Pro is active.")
    XCTAssertTrue(sut.restoreStatusIsSuccess)
    XCTAssertTrue(sut.isPro)
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

// Minimal mocks for testing
private final class BillingSessionMock: HTTPClientSession, @unchecked Sendable {
  var handler: ((URLRequest) throws -> (Data, URLResponse))?

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    guard let handler else {
      fatalError("BillingSessionMock.handler must be configured before use")
    }
    return try handler(request)
  }
}

@MainActor
private final class SubscriptionURLRecorder: @unchecked Sendable {
  private(set) var openedURLs: [URL] = []

  func open(_ url: URL) {
    openedURLs.append(url)
  }
}

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
