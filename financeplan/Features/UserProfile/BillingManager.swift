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
  typealias RevenueCatAPIKeyProvider = @MainActor @Sendable () -> String?
  typealias SubscriptionURLOpener = @MainActor @Sendable (URL) -> Void

  private enum Keys {
    static let entitlementLevel = "billing.entitlement_level"
    static let isPro = "billing.is_pro"
    static let generatedAt = "billing.generated_at"
    static let pendingBackendSync = "billing.pending_backend_sync"
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
  var errorMessage: String?
  var restoreStatusMessage: String?
  var restoreStatusIsSuccess = false

  private let environmentManager: AppEnvironmentManager
  private let authSessionManager: AuthSessionManaging
  private let sessionStore: AuthSessionStoring
  private let billingClientFactory: BillingClientFactory
  private let revenueCatAPIKeyProvider: RevenueCatAPIKeyProvider
  private let subscriptionURLOpener: SubscriptionURLOpener
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
    },
    revenueCatAPIKeyProvider: @escaping RevenueCatAPIKeyProvider = {
      Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String
    },
    subscriptionURLOpener: @escaping SubscriptionURLOpener = { url in
      UIApplication.shared.open(url)
    }
  ) {
    self.environmentManager = environmentManager
    self.authSessionManager = authSessionManager
    self.sessionStore = sessionStore
    self.billingClientFactory = billingClientFactory
    self.revenueCatAPIKeyProvider = revenueCatAPIKeyProvider
    self.subscriptionURLOpener = subscriptionURLOpener
    self.uiTestBillingTier = Self.normalizedUITestBillingTier()
    loadCachedEntitlement()
    applyUITestBillingContextIfNeeded()
  }

  var isPro: Bool {
    if ProcessInfo.processInfo.arguments.contains("-ui_test_pro_user") {
      return true
    }
    return context.map(Self.isPremiumContext)
      ?? UserDefaults.standard.bool(forKey: Keys.isPro)
  }

  var trialDaysRemaining: Int? {
    context?.trialDaysRemaining
  }

  var currentPlanID: String {
    context?.subscription?.plan ?? context?.plan ?? selectedProductID
  }

  var currentPlanDisplayName: String {
    Self.planDisplayName(for: currentPlanID)
  }

  var subscriptionRenewsOrExpiresAt: Date? {
    context?.subscription?.renewsOrExpiresAt
  }

  var subscriptionAccessEndsAt: Date? {
    context?.subscription?.accessEndsAt ?? context?.subscription?.periodEndsAt
  }

  var isCancelledButActive: Bool {
    context?.subscription?.isCancelledButActive ?? false
  }

  var hasBillingIssue: Bool {
    context?.subscription?.hasBillingIssue ?? false
  }

  var pendingPlanDisplayName: String? {
    guard let pendingPlan = context?.subscription?.pendingPlan, !pendingPlan.isEmpty else {
      return nil
    }
    return Self.planDisplayName(for: pendingPlan)
  }

  var pendingPlanEffectiveAt: Date? {
    context?.subscription?.pendingPlanEffectiveAt
  }

  var availableUpgradePlanOptions: [BillingPlanOptionDTO] {
    let options = context?.planOptions.isEmpty == false
      ? context?.planOptions ?? []
      : Self.fallbackPlanOptions(currentPlan: currentPlanID, isPremium: isPro)
    return options.filter { $0.changeKind == "upgrade" }
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

  /// True when the selected StoreKit product includes a free-trial introductory offer.
  var selectedPlanHasFreeTrial: Bool {
    guard let intro = selectedPackage?.storeProduct.introductoryDiscount else { return false }
    return intro.paymentMode == .freeTrial
  }

  /// Primary paywall button title — trial wording only when StoreKit confirms a free trial.
  var purchaseCTATitle: String {
    guard selectedPackage != nil else {
      return "Subscriptions Unavailable"
    }
    guard selectedPlanHasFreeTrial, let trialDays = selectedPlanFreeTrialDays else {
      return "Subscribe"
    }
    return trialDays == 1 ? "Start Free Trial" : "Start \(trialDays)-Day Free Trial"
  }

  var canPurchaseSelectedPackage: Bool {
    selectedPackage != nil
  }

  /// Auto-renew disclosure required near the subscribe button (Guideline 3.1.2).
  var subscriptionDisclosureText: String {
    guard let product = selectedPackage?.storeProduct else {
      return "Subscriptions are currently unavailable. Please try again later."
    }

    let price = product.localizedPriceString
    let periodLabel = Self.subscriptionPeriodLabel(for: product)

    if selectedPlanHasFreeTrial, let trialDays = selectedPlanFreeTrialDays {
      return
        "After your \(trialDays)-day free trial, you will be charged \(price)\(periodLabel) unless you cancel. \(Self.defaultSubscriptionDisclosure)"
    }

    return "\(price)\(periodLabel) will be charged to your Apple ID account at confirmation of purchase. \(Self.defaultSubscriptionDisclosure)"
  }

  func configureAnonymousIfNeeded() {
    guard uiTestBillingTier == nil else { return }
    guard !didConfigureRevenueCat else { return }
    guard let apiKey = revenueCatAPIKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
          !apiKey.isEmpty,
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

    guard let apiKey = revenueCatAPIKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
          !apiKey.isEmpty,
          !apiKey.contains("$(") else {
      errorMessage = "RevenueCat API key is not configured."
      return
    }

    if didConfigureRevenueCat {
      Task {
        await performRevenueCatLogin(userID: userID)
      }
    } else {
      Purchases.configure(withAPIKey: apiKey, appUserID: userID)
      didConfigureRevenueCat = true
    }
  }

  /// Links RevenueCat identity after sign-in and syncs entitlements with the backend.
  /// Call after authentication and when reconciling anonymous pre-login purchases.
  func linkCurrentUserAndSyncEntitlements() async {
    guard uiTestBillingTier == nil else { return }

    let userID = await sessionStore.currentUserID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !userID.isEmpty else { return }

    if configuredUserID != userID {
      configureRevenueCat(userID: userID)
    } else if didConfigureRevenueCat, Purchases.shared.isAnonymous {
      await performRevenueCatLogin(userID: userID)
    }

    await reconcilePendingBackendSyncIfNeeded()
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
    clearRestoreStatus()
    defer { isPurchasing = false }

    do {
      let result = try await Purchases.shared.purchase(package: selectedPackage)
      guard !result.userCancelled else { return false }
      PostHogSDK.shared.capture("subscription_purchased", properties: [
        "product_id": selectedPackage.storeProduct.productIdentifier,
      ])

      if result.customerInfo.entitlements[Constants.entitlementID]?.isActive == true {
        applyOptimisticPro(from: result.customerInfo)
      }

      await syncBackendEntitlement()
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  func restorePurchases() async {
    guard uiTestBillingTier == nil else {
      applyUITestBillingContextIfNeeded()
      recordRestoreResult(foundActiveRevenueCatEntitlement: isPro, syncedContext: context)
      return
    }
    await configureRevenueCatForCurrentSession()
    guard didConfigureRevenueCat else {
      if errorMessage == nil {
        errorMessage = "Subscriptions are currently unavailable. Please try again later."
      }
      return
    }

    isRestoring = true
    errorMessage = nil
    clearRestoreStatus()
    defer { isRestoring = false }

    do {
      let customerInfo = try await Purchases.shared.restorePurchases()
      let foundActiveEntitlement = customerInfo.entitlements[Constants.entitlementID]?.isActive == true
      if foundActiveEntitlement {
        applyOptimisticPro(from: customerInfo)
      }
      let syncedContext = await syncBackendEntitlement()
      recordRestoreResult(foundActiveRevenueCatEntitlement: foundActiveEntitlement, syncedContext: syncedContext)
      if restoreStatusIsSuccess {
        PostHogSDK.shared.capture("subscription_restored")
      } else {
        PostHogSDK.shared.capture("subscription_restore_no_active_purchase")
      }
    } catch {
      errorMessage = error.localizedDescription
      clearRestoreStatus()
    }
  }

  private func configureRevenueCatForCurrentSession() async {
    let userID = await sessionStore.currentUserID.trimmingCharacters(in: .whitespacesAndNewlines)
    if userID.isEmpty {
      configureAnonymousIfNeeded()
    } else {
      configureRevenueCat(userID: userID)
    }
  }

  func manageSubscription() async {
    guard uiTestBillingTier == nil else {
      openAppleSubscriptionManagement()
      return
    }

    let userID = await sessionStore.currentUserID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !userID.isEmpty else {
      openAppleSubscriptionManagement()
      return
    }

    errorMessage = nil
    clearRestoreStatus()
    do {
      let response = try await billingClient(forceRefresh: false).createManagementURL()
      subscriptionURLOpener(response.managementURL)
    } catch let error as BillingHTTPClient.Error where error.isUnauthorized {
      do {
        let response = try await billingClient(forceRefresh: true).createManagementURL()
        subscriptionURLOpener(response.managementURL)
      } catch {
        errorMessage = "Could not open subscription management. Please try again."
      }
    } catch {
      errorMessage = "Could not open subscription management. Please try again."
    }
  }

  func clearCache() {
    context = nil
    packages = []
    selectedProductID = Constants.annualProductID
    hasUserSelectedProduct = false
    configuredUserID = nil
    clearRestoreStatus()
    UserDefaults.standard.removeObject(forKey: Keys.entitlementLevel)
    UserDefaults.standard.removeObject(forKey: Keys.isPro)
    UserDefaults.standard.removeObject(forKey: Keys.generatedAt)
    UserDefaults.standard.removeObject(forKey: Keys.pendingBackendSync)
  }

  func reconcilePendingBackendSyncIfNeeded() async {
    guard uiTestBillingTier == nil else { return }
    guard UserDefaults.standard.bool(forKey: Keys.pendingBackendSync) else { return }
    await syncBackendEntitlement()
  }

  private func restoreBackendEntitlement(forceRefresh: Bool = false) async throws -> BillingContextResponse {
    let context = try await billingClient(forceRefresh: forceRefresh).restorePurchases()
    apply(context)
    return context
  }

  @discardableResult
  private func syncBackendEntitlement(maxAttempts: Int = 3) async -> BillingContextResponse? {
    let userID = await sessionStore.currentUserID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !userID.isEmpty else { return nil }

    var delayNanoseconds: UInt64 = 500_000_000

    for attempt in 1...maxAttempts {
      do {
        let context = try await restoreBackendEntitlement()
        clearPendingBackendSync()
        return context
      } catch let error as BillingHTTPClient.Error where error.isUnauthorized {
        do {
          let context = try await restoreBackendEntitlement(forceRefresh: true)
          clearPendingBackendSync()
          return context
        } catch {
          if attempt == maxAttempts {
            markPendingBackendSync()
            return nil
          }
        }
      } catch {
        if attempt == maxAttempts {
          markPendingBackendSync()
          return nil
        }
      }

      try? await Task.sleep(nanoseconds: delayNanoseconds)
      delayNanoseconds *= 2
    }

    return nil
  }

  private func performRevenueCatLogin(userID: String) async {
    do {
      let (customerInfo, _) = try await Purchases.shared.logIn(userID)
      if customerInfo.entitlements[Constants.entitlementID]?.isActive == true {
        applyOptimisticPro(from: customerInfo)
      }
      await syncBackendEntitlement()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func applyOptimisticPro(from customerInfo: CustomerInfo) {
    guard customerInfo.entitlements[Constants.entitlementID]?.isActive == true else { return }

    let productID = customerInfo.entitlements[Constants.entitlementID]?.productIdentifier
      ?? selectedProductID
    let entitlementLevel = productID.hasPrefix("pro_") ? productID : "pro"

    apply(
      BillingContextResponse(
        plan: entitlementLevel,
        entitlementLevel: entitlementLevel,
        isPremium: true,
        subscription: nil,
        features: context?.features ?? [],
        usage: context?.usage ?? [],
        trialDaysRemaining: context?.trialDaysRemaining,
        isTrialActive: context?.isTrialActive ?? false,
        generatedAt: Date()
      )
    )
  }

  private func markPendingBackendSync() {
    UserDefaults.standard.set(true, forKey: Keys.pendingBackendSync)
  }

  private func clearPendingBackendSync() {
    UserDefaults.standard.removeObject(forKey: Keys.pendingBackendSync)
  }

  func recordRestoreResult(
    foundActiveRevenueCatEntitlement: Bool,
    syncedContext: BillingContextResponse?
  ) {
    if let syncedContext {
      apply(syncedContext)
    }

    let restoredPremium = foundActiveRevenueCatEntitlement || syncedContext.map(Self.isPremiumContext) == true
    restoreStatusIsSuccess = restoredPremium
    restoreStatusMessage = restoredPremium
      ? "Purchases restored. Pro is active."
      : "No active purchases found for this account."
  }

  private func clearRestoreStatus() {
    restoreStatusMessage = nil
    restoreStatusIsSuccess = false
  }

  private static let defaultSubscriptionDisclosure =
    "Payment will be charged to your Apple ID account. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions in your App Store account settings."

  private var selectedPlanFreeTrialDays: Int? {
    guard let intro = selectedPackage?.storeProduct.introductoryDiscount,
          intro.paymentMode == .freeTrial else {
      return nil
    }
    return Self.trialDays(from: intro.subscriptionPeriod)
  }

  private static func trialDays(from period: SubscriptionPeriod) -> Int {
    switch period.unit {
    case .day:
      return period.value
    case .week:
      return period.value * 7
    case .month:
      return period.value * 30
    case .year:
      return period.value * 365
    @unknown default:
      return period.value
    }
  }

  private static func subscriptionPeriodLabel(for product: StoreProduct) -> String {
    guard let period = product.subscriptionPeriod else { return "" }

    switch period.unit {
    case .day where period.value == 7:
      return "/wk"
    case .day:
      return "/\(period.value)d"
    case .week:
      return period.value == 1 ? "/wk" : "/\(period.value)wks"
    case .month:
      return period.value == 1 ? "/mo" : "/\(period.value)mo"
    case .year:
      return period.value == 1 ? "/yr" : "/\(period.value)yr"
    @unknown default:
      return ""
    }
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

  private func openAppleSubscriptionManagement() {
    guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
    subscriptionURLOpener(url)
  }

  private func apply(_ context: BillingContextResponse) {
    self.context = context
    UserDefaults.standard.set(context.entitlementLevel, forKey: Keys.entitlementLevel)
    UserDefaults.standard.set(Self.isPremiumContext(context), forKey: Keys.isPro)
    UserDefaults.standard.set(context.generatedAt, forKey: Keys.generatedAt)
  }

  private static func isPremiumContext(_ context: BillingContextResponse) -> Bool {
    context.isPremium || context.entitlementLevel == "pro" || context.entitlementLevel.hasPrefix("pro_")
  }

  private var selectedPlanDisplayName: String {
    Self.planDisplayName(for: selectedProductID).replacingOccurrences(of: " Plan", with: "")
  }

  static func planDisplayName(for productID: String) -> String {
    switch productID {
    case Constants.annualProductID:
      return "Annual Plan"
    case Constants.monthlyProductID:
      return "Monthly Plan"
    case Constants.weeklyProductID:
      return "Weekly Plan"
    case "free":
      return "Free Plan"
    case "pro":
      return "Pro"
    default:
      return "Pro"
    }
  }

  private static func fallbackPlanOptions(currentPlan: String, isPremium: Bool) -> [BillingPlanOptionDTO] {
    let currentRank = planRank(currentPlan)
    return [
      makePlanOption(productID: Constants.weeklyProductID, displayName: "Weekly", interval: "weekly", rank: 1, currentRank: currentRank, isPremium: isPremium, badge: nil),
      makePlanOption(productID: Constants.monthlyProductID, displayName: "Monthly", interval: "monthly", rank: 2, currentRank: currentRank, isPremium: isPremium, badge: "Better value"),
      makePlanOption(productID: Constants.annualProductID, displayName: "Annual", interval: "annual", rank: 3, currentRank: currentRank, isPremium: isPremium, badge: "Best value"),
    ]
  }

  private static func makePlanOption(
    productID: String,
    displayName: String,
    interval: String,
    rank: Int,
    currentRank: Int,
    isPremium: Bool,
    badge: String?
  ) -> BillingPlanOptionDTO {
    let changeKind: String
    if rank == currentRank {
      changeKind = "current"
    } else if !isPremium {
      changeKind = "subscribe"
    } else if currentRank > 0, rank > currentRank {
      changeKind = "upgrade"
    } else if currentRank > 0, rank < currentRank {
      changeKind = "downgrade"
    } else {
      changeKind = "subscribe"
    }
    return BillingPlanOptionDTO(
      productId: productID,
      plan: productID,
      displayName: displayName,
      interval: interval,
      rank: rank,
      badge: badge,
      isCurrent: changeKind == "current",
      changeKind: changeKind
    )
  }

  private static func planRank(_ plan: String) -> Int {
    switch plan {
    case Constants.weeklyProductID:
      return 1
    case Constants.monthlyProductID:
      return 2
    case Constants.annualProductID:
      return 3
    default:
      return 0
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
