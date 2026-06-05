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
  typealias BillingClientFactory = @MainActor @Sendable (URL, String?) -> BillingHTTPClient

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
  var selectedProductID = Constants.annualProductID
  var selectedPackage: Package? {
    packages.first { $0.storeProduct.productIdentifier == selectedProductID }
  }
  var isLoading = false
  var isPurchasing = false
  var isRestoring = false
  var isRedeemingCoupon = false
  var errorMessage: String?
  var couponRedemptionMessage: String?

  private let environmentManager: AppEnvironmentManager
  private let authSessionManager: AuthSessionManaging
  private let sessionStore: AuthSessionStoring
  private let billingClientFactory: BillingClientFactory
  private var configuredUserID: String?
  private var didConfigureRevenueCat = false
  private var hasUserSelectedProduct = false
  private let uiTestBillingTier: String?

  init(
    environmentManager: AppEnvironmentManager,
    authSessionManager: AuthSessionManaging,
    sessionStore: AuthSessionStoring,
    billingClientFactory: @escaping BillingClientFactory = { baseURL, token in
      BillingHTTPClient(
        baseURL: baseURL,
        authTokenProvider: { token }
      )
    }
  ) {
    self.environmentManager = environmentManager
    self.authSessionManager = authSessionManager
    self.sessionStore = sessionStore
    self.billingClientFactory = billingClientFactory
    self.uiTestBillingTier = Self.normalizedUITestBillingTier()
    loadCachedEntitlement()
    applyUITestBillingContextIfNeeded()
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

  func configureAnonymousIfNeeded() {
    guard uiTestBillingTier == nil else { return }
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
    guard uiTestBillingTier == nil else { return }
    Task {
      let userID = await sessionStore.currentUserID.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !userID.isEmpty else { return }
      configureRevenueCat(userID: userID)
    }
  }

  func configureRevenueCat(userID: String) {
    guard uiTestBillingTier == nil else { return }
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
    guard uiTestBillingTier == nil else {
      applyUITestBillingContextIfNeeded()
      return
    }
    await performLoading {
      let context = try await billingClient(forceRefresh: false).fetchContext()
      apply(context)
    }
  }

  func loadOfferings() async {
    let userID = await sessionStore.currentUserID.trimmingCharacters(in: .whitespacesAndNewlines)
    if userID.isEmpty {
      configureAnonymousIfNeeded()
    } else {
      configureRevenueCat(userID: userID)
    }
    
    guard didConfigureRevenueCat else { return }

    do {
      let offerings = try await Purchases.shared.offerings()
      let availablePackages = offerings.current?.availablePackages ?? []
      packages = availablePackages
      if !hasUserSelectedProduct {
        selectedProductID = availablePackages.first { $0.storeProduct.productIdentifier == Constants.annualProductID }
          .map { $0.storeProduct.productIdentifier }
          ?? availablePackages.first?.storeProduct.productIdentifier
          ?? Constants.annualProductID
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func select(productID: String) {
    selectedProductID = productID
    hasUserSelectedProduct = true
  }

  func purchaseSelectedPackage() async -> Bool {
    guard let selectedPackage else {
      errorMessage = "\(selectedPlanDisplayName) plan is currently unavailable. Please try again later."
      return false
    }

    let userID = await sessionStore.currentUserID.trimmingCharacters(in: .whitespacesAndNewlines)
    if userID.isEmpty {
      configureAnonymousIfNeeded()
    } else {
      configureRevenueCat(userID: userID)
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
    guard uiTestBillingTier == nil else {
      applyUITestBillingContextIfNeeded()
      return
    }
    configureForCurrentUser()
    guard didConfigureRevenueCat else { return }

    isRestoring = true
    errorMessage = nil
    defer { isRestoring = false }

    do {
      _ = try await Purchases.shared.restorePurchases()
      try await restoreBackendEntitlement()
      // PostHog: Track successful subscription restore
      PostHogSDK.shared.capture("subscription_restored")
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func redeemCoupon(code: String) async {
    let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedCode.isEmpty else {
      errorMessage = "Enter a coupon code."
      couponRedemptionMessage = nil
      return
    }

    isRedeemingCoupon = true
    errorMessage = nil
    couponRedemptionMessage = nil
    defer { isRedeemingCoupon = false }

    do {
      let response = try await billingClient(forceRefresh: false).redeemCoupon(code: trimmedCode)
      if let context = response.billingContext {
        apply(context)
      }
      couponRedemptionMessage = isPro
        ? "Coupon redeemed. Pro is active."
        : "Coupon redeemed."
    } catch let error as BillingHTTPClient.Error where error.isUnauthorized {
      do {
        let response = try await billingClient(forceRefresh: true).redeemCoupon(code: trimmedCode)
        if let context = response.billingContext {
          apply(context)
        }
        couponRedemptionMessage = isPro
          ? "Coupon redeemed. Pro is active."
          : "Coupon redeemed."
      } catch {
        errorMessage = error.localizedDescription
      }
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
    selectedProductID = Constants.annualProductID
    hasUserSelectedProduct = false
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
    return billingClientFactory(environmentManager.current.apiBaseUrl, token)
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

  private var selectedPlanDisplayName: String {
    switch selectedProductID {
    case Constants.annualProductID:
      return "Annual"
    case Constants.monthlyProductID:
      return "Monthly"
    case Constants.weeklyProductID:
      return "Weekly"
    default:
      return "Selected"
    }
  }

  private func loadCachedEntitlement() {
    guard UserDefaults.standard.object(forKey: Keys.isPro) != nil else { return }
  }

  private static func normalizedUITestBillingTier() -> String? {
    if ProcessInfo.processInfo.arguments.contains("-ui_test_pro_user") {
      return "pro"
    }
    guard let raw = ProcessInfo.processInfo.billingArgumentValue(for: "-ui_test_billing_tier") else {
      return nil
    }
    let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard ["free", "trial", "pro"].contains(normalized) else { return nil }
    return normalized
  }

  private func applyUITestBillingContextIfNeeded() {
    guard let uiTestBillingTier else { return }
    apply(Self.makeUITestBillingContext(tier: uiTestBillingTier))
  }

  private static func makeUITestBillingContext(tier: String) -> BillingContextResponse {
    let isPaid = tier == "trial" || tier == "pro"
    let entitlementLevel = tier == "trial" ? "temporary" : tier
    return BillingContextResponse(
      plan: entitlementLevel,
      entitlementLevel: entitlementLevel,
      isPremium: isPaid,
      subscription: nil,
      features: makeUITestFeatures(available: isPaid),
      usage: makeUITestUsage(hasFreeLimits: !isPaid),
      trialDaysRemaining: tier == "trial" ? 7 : nil,
      isTrialActive: tier == "trial",
      generatedAt: Date()
    )
  }

  private static func makeUITestFeatures(available paidFeaturesAvailable: Bool) -> [BillingFeatureDTO] {
    let proOnlyKeys = Set([
      "broker_sync",
      "valuation_cases",
      "target_alerts",
      "household_partner",
      "recurring_templates",
      "year_overview",
      "smart_suggestions",
      "reports",
      "statistics",
      "market_fundamentals",
      "advanced_research",
      "peer_comparison",
      "earnings_text",
    ])
    let keys = [
      "broker_sync",
      "portfolio_lists",
      "holdings",
      "watchlist_items",
      "valuation_cases",
      "csv_imports",
      "target_alerts",
      "report_generations",
      "expense_planner",
      "household_partner",
      "recurring_templates",
      "year_overview",
      "smart_suggestions",
      "reports",
      "statistics",
      "market_fundamentals",
      "advanced_research",
      "peer_comparison",
      "earnings_text",
    ]
    return keys.map { key in
      let available = !proOnlyKeys.contains(key) || paidFeaturesAvailable
      return BillingFeatureDTO(
        key: key,
        title: key.replacingOccurrences(of: "_", with: " ").capitalized,
        available: available,
        requiredPlan: available ? nil : "pro",
        reason: available ? nil : "Upgrade to Pro to use this feature.",
        limit: nil,
        used: nil,
        remaining: nil
      )
    }
  }

  private static func makeUITestUsage(hasFreeLimits: Bool) -> [BillingUsageDTO] {
    [
      BillingUsageDTO(key: "portfolio_lists", used: 0, limit: hasFreeLimits ? 1 : nil, remaining: hasFreeLimits ? 1 : nil, periodStart: nil),
      BillingUsageDTO(key: "holdings", used: 0, limit: hasFreeLimits ? 5 : nil, remaining: hasFreeLimits ? 5 : nil, periodStart: nil),
      BillingUsageDTO(key: "watchlist_items", used: 0, limit: hasFreeLimits ? 10 : nil, remaining: hasFreeLimits ? 10 : nil, periodStart: nil),
      BillingUsageDTO(key: "csv_imports", used: 0, limit: hasFreeLimits ? 1 : nil, remaining: hasFreeLimits ? 1 : nil, periodStart: Date()),
      BillingUsageDTO(key: "report_generations", used: 0, limit: hasFreeLimits ? 10 : nil, remaining: hasFreeLimits ? 10 : nil, periodStart: Date()),
    ]
  }
}

private extension ProcessInfo {
  func billingArgumentValue(for name: String) -> String? {
    guard let index = arguments.firstIndex(of: name) else {
      return nil
    }
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex) else {
      return nil
    }
    return arguments[valueIndex]
  }
}
