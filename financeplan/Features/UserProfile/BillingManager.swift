import Factory
import Foundation
import Observation
import PostHog
import RevenueCat
import StockPlanShared
import UIKit

@MainActor
@Observable
final class BillingManager {
  private enum Keys {
    static let entitlementLevel = "billing.entitlement_level"
    static let isPro = "billing.is_pro"
    static let generatedAt = "billing.generated_at"
  }

  private enum Constants {
    static let entitlementID = "pro"
    static let annualProductID = "pro_annual"
    static let monthlyProductID = "pro_monthly"
    static let weeklyProductID = "pro_weekly"
  }

  var context: BillingContextResponse?
  var packages: [Package] = []
  var selectedPackage: Package?
  var isLoading = false
  var isPurchasing = false
  var isRestoring = false
  var errorMessage: String?

  private let environmentManager: AppEnvironmentManager
  private let authSessionManager: AuthSessionManaging
  private let sessionStore: AuthSessionStoring
  private var configuredUserID: String?
  private var didConfigureRevenueCat = false

  init(
    environmentManager: AppEnvironmentManager,
    authSessionManager: AuthSessionManaging,
    sessionStore: AuthSessionStoring
  ) {
    self.environmentManager = environmentManager
    self.authSessionManager = authSessionManager
    self.sessionStore = sessionStore
    loadCachedEntitlement()
  }

  var isPro: Bool {
    if ProcessInfo.processInfo.arguments.contains("-ui_test_pro_user") {
      return true
    }
    return context.map { $0.isPremium || $0.entitlementLevel == "pro" || $0.entitlementLevel.hasPrefix("pro_") }
      ?? UserDefaults.standard.bool(forKey: Keys.isPro)
  }

  var trialDaysRemaining: Int? {
    context?.trialDaysRemaining
  }

  /// Returns whether a named feature is available for the current user.
  ///
  /// Checks the `features` list from the server-provided `BillingContextResponse` first,
  /// which allows individual features to be toggled server-side without an app update.
  /// Falls back to `isPro` when no server-side descriptor is found for the given key.
  ///
  /// - Parameter key: The raw feature key (e.g. `"household_partner"`, `"year_overview"`).
  /// - Returns: `true` if the feature is available, `false` otherwise.
  func isFeatureAvailable(_ key: String) -> Bool {
    context?.features.first(where: { $0.key == key })?.available ?? isPro
  }

  var annualPackage: Package? {
    packages.first { $0.storeProduct.productIdentifier == Constants.annualProductID }
  }

  var monthlyPackage: Package? {
    packages.first { $0.storeProduct.productIdentifier == Constants.monthlyProductID }
  }

  var weeklyPackage: Package? {
    packages.first { $0.storeProduct.productIdentifier == Constants.weeklyProductID }
  }

  var selectedProductID: String {
    selectedPackage?.storeProduct.productIdentifier ?? Constants.annualProductID
  }

  func configureAnonymousIfNeeded() {
    guard !didConfigureRevenueCat else { return }
    guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
          !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !apiKey.contains("$(") else {
      errorMessage = "RevenueCat API key is not configured."
      return
    }
    Purchases.configure(withAPIKey: apiKey)
    didConfigureRevenueCat = true
  }

  func configureForCurrentUser() {
    let userID = sessionStore.currentUserID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !userID.isEmpty else { return }
    configureRevenueCat(userID: userID)
  }

  func configureRevenueCat(userID: String) {
    guard configuredUserID != userID else { return }
    configuredUserID = userID

    guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
          !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !apiKey.contains("$(") else {
      errorMessage = "RevenueCat API key is not configured."
      return
    }

    if didConfigureRevenueCat {
      Purchases.shared.logIn(userID) { _, _, error in
        if let error {
          Task { @MainActor in
            self.errorMessage = error.localizedDescription
          }
        }
      }
    } else {
      Purchases.configure(withAPIKey: apiKey, appUserID: userID)
      didConfigureRevenueCat = true
    }
  }

  func refreshBillingContext() async {
    await performLoading {
      let context = try await billingClient(forceRefresh: false).fetchContext()
      apply(context)
    }
  }

  func loadOfferings() async {
    let userID = sessionStore.currentUserID.trimmingCharacters(in: .whitespacesAndNewlines)
    if userID.isEmpty {
      configureAnonymousIfNeeded()
    } else {
      configureForCurrentUser()
    }
    
    guard didConfigureRevenueCat else { return }

    do {
      let offerings = try await Purchases.shared.offerings()
      let availablePackages = offerings.current?.availablePackages ?? []
      packages = availablePackages
      selectedPackage = availablePackages.first { $0.storeProduct.productIdentifier == Constants.annualProductID }
        ?? availablePackages.first
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func select(productID: String) {
    selectedPackage = packages.first { $0.storeProduct.productIdentifier == productID }
  }

  func purchaseSelectedPackage() async -> Bool {
    guard let selectedPackage else {
      errorMessage = "No Pro plan is available. Please try again later."
      return false
    }

    let userID = sessionStore.currentUserID.trimmingCharacters(in: .whitespacesAndNewlines)
    if userID.isEmpty {
      configureAnonymousIfNeeded()
    } else {
      configureForCurrentUser()
    }

    guard didConfigureRevenueCat else { return false }

    isPurchasing = true
    errorMessage = nil
    defer { isPurchasing = false }

    do {
      let result = try await Purchases.shared.purchase(package: selectedPackage)
      guard !result.userCancelled else { return false }
      // PostHog: Track successful subscription purchase
      PostHogSDK.shared.capture("subscription_purchased", properties: [
        "product_id": selectedPackage.storeProduct.productIdentifier,
      ])
      
      if !userID.isEmpty {
        try await restoreBackendEntitlement()
      }
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  func restorePurchases() async {
    configureForCurrentUser()
    guard didConfigureRevenueCat else { return }

    isRestoring = true
    errorMessage = nil
    defer { isRestoring = false }

    do {
      _ = try await Purchases.shared.restorePurchases()
      try await restoreBackendEntitlement()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func manageSubscription() {
    guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
    UIApplication.shared.open(url)
  }

  func clearCache() {
    context = nil
    packages = []
    selectedPackage = nil
    configuredUserID = nil
    UserDefaults.standard.removeObject(forKey: Keys.entitlementLevel)
    UserDefaults.standard.removeObject(forKey: Keys.isPro)
    UserDefaults.standard.removeObject(forKey: Keys.generatedAt)
  }

  private func restoreBackendEntitlement() async throws {
    let context = try await billingClient(forceRefresh: false).restorePurchases()
    apply(context)
  }

  private func performLoading(_ operation: () async throws -> Void) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      try await operation()
    } catch let error as BillingHTTPClient.Error where error.isUnauthorized {
      do {
        let context = try await billingClient(forceRefresh: true).fetchContext()
        apply(context)
      } catch {
        errorMessage = error.localizedDescription
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func billingClient(forceRefresh: Bool) async throws -> BillingHTTPClient {
    let token = forceRefresh
      ? try await authSessionManager.refreshAccessToken()
      : try await authSessionManager.validAccessToken()
    return BillingHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      authTokenProvider: { token }
    )
  }

  private func apply(_ context: BillingContextResponse) {
    self.context = context
    UserDefaults.standard.set(context.entitlementLevel, forKey: Keys.entitlementLevel)
    UserDefaults.standard.set(
      context.isPremium || context.entitlementLevel == "pro" || context.entitlementLevel.hasPrefix("pro_"),
      forKey: Keys.isPro
    )
    UserDefaults.standard.set(context.generatedAt, forKey: Keys.generatedAt)
  }

  private func loadCachedEntitlement() {
    guard UserDefaults.standard.object(forKey: Keys.isPro) != nil else { return }
  }
}
