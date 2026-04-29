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

  override func setUp() {
    super.setUp()
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

// Minimal mocks for testing
private final class MockAuthSessionManager: AuthSessionManaging {
  func logout() async {}
  func reset() {}
  func restoreSessionIfNeeded() async -> Bool { return false }
  func invalidateSession() async {}
  func onSessionConfigured() {}
  func validAccessToken() async throws -> String? { return nil }
  func refreshAccessToken() async throws -> String? { return nil }
}

private final class MockAuthSessionStore: AuthSessionStoring {
  var authToken: String = ""
  var refreshToken: String = ""
  var authTokenExpiresAt: Date? = nil
  var refreshTokenExpiresAt: Date? = nil
  var loginIsSignup: Bool = false
  var currentUserID = "mock-user-id"
  var currentUsername = "mock-user"
  var isSetupComplete = false
  var hasPassedSecurity = false
  var hasAppLockEnabled = false
  var currentSecurityCodeHash: String? = nil

  func store(authResponse: StockPlanShared.AuthResponse) {}
  func saveTokens(access: String, refresh: String) throws {}
  func loadTokens() throws -> (access: String, refresh: String)? { return nil }
  func clearTokens() throws {}
  func saveUserProfile(id: String, username: String) {}
  func clearSession() {}
  func hasCompletedInitialStockImport(for userID: String) -> Bool { return false }
  func markInitialStockImportCompleted(for userID: String) {}
}
