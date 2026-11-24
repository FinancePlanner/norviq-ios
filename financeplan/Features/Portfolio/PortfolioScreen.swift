import Combine
import Factory
import OSLog
import PostHog
import StockPlanShared
import SwiftUI
import SwiftData

@MainActor
struct PortfolioScreen: View {
  private static let pushLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "PushNotificationsUX"
  )

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @Environment(PortfolioViewModel.self) private var viewModel
  @Environment(GuidedStartCoordinator.self) private var guided: GuidedStartCoordinator?
  @InjectedObservable(\Container.billingManager) private var billingManager
  @Binding var pendingOpenSymbol: String?
  @Binding var pendingThesisWatchOpen: Bool

  @Query(sort: \SDPortfolioStock.symbol) private var stocks: [SDPortfolioStock]

  @State private var isAddPositionPresented = false
  @State private var isOnePagePresented = false
  @State private var isCSVImportPresented = false
  @State private var isScreenshotImportPresented = false
  @State private var destructiveFeedbackTrigger = 0
  @State private var selectedTimeRange: TimeRange = .month
  @State private var selectedAssetFilter: AssetFilter = .all
  @State private var selectedHoldingsSort: HoldingsSort = .name
  /// Rebuilt only when its inputs change, so a quote refresh does not
  /// reset a chart selection mid-drag.
  @State private var cachedHeroModel: PortfolioHeroModel?
  @State private var pushNavigationRoute: PushNavigationRoute?
  @State private var pushFallbackToast: ToastData?
  @State private var refreshErrorToast: ToastData?
  @State private var targetAlertStock: TargetAlertDraftStock?
  @State private var isPaywallPresented = false
  @State private var isEarningsCalendarPresented = false
  @State private var isSectorGainsPresented = false
  @State private var isThesisWatchPresented = false

  private let quoteRefreshTimer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

  enum TimeRange: String, CaseIterable, Identifiable {
      case day = "1D"
      case week = "1W"
      case month = "1M"
      case threeMonths = "3M"
      case year = "1Y"
      case all = "ALL"
      var id: String { rawValue }

      /// The ranges the portfolio series supports (spec § 5.5). There is no
      /// intraday portfolio series, so 1D is not offered on the hero.
      static let heroRanges: [TimeRange] = [.week, .month, .threeMonths, .year, .all]
  }

  enum AssetFilter: String, CaseIterable, Identifiable {
      case all = "All Assets"
      case stocks = "Stocks"
      case etfs = "ETFs"
      case crypto = "Crypto"
      var id: String { rawValue }
  }

  enum HoldingsSort: String, CaseIterable, Identifiable {
    case name = "Name"
    case gains = "Gains"
    case weight = "% of Portfolio"
    var id: String { rawValue }
  }

  private struct PushNavigationRoute: Identifiable, Hashable {
    let id = UUID()
    let stockID: String
    let symbol: String
  }

  private struct TargetAlertDraftStock: Identifiable, Hashable {
    let id: String
    let symbol: String
    let buyPrice: Double
  }

  private var currentOwnerUserId: String {
    LocalCacheScope.currentOwnerUserId
  }

  // MARK: - Memoised derivation
  //
  // The owned → scoped → filtered/sorted chain plus the holdings totals used
  // to be independent computed properties, each re-filtering `stocks` on
  // every body pass (which the 20 s quote timer triggers). They're now
  // derived once per input change into `derived`; the first frame computes
  // inline so there's no empty flash before `.onChange(initial:)` lands.

  /// Everything the derivation depends on. Cheap to compare relative to the
  /// derivation itself; the stocks fingerprint catches in-place model edits
  /// that keep the same object identities.
  private struct DerivationInputs: Equatable {
    let stocksFingerprint: Int
    let ownerUserId: String
    let selectedListId: String?
    let assetFilter: AssetFilter
    let holdingsSort: HoldingsSort
    let pnlBySymbol: [String: PnlBySymbol]
  }

  private struct DerivedPortfolio {
    var scopedStocks: [SDPortfolioStock] = []
    var filteredStocks: [SDPortfolioStock] = []
  }

  @State private var derived: DerivedPortfolio?

  private var stocksFingerprint: Int {
    var hasher = Hasher()
    hasher.combine(stocks.count)
    for stock in stocks {
      hasher.combine(stock.id)
      hasher.combine(stock.symbol)
      hasher.combine(stock.shares)
      hasher.combine(stock.buyPrice)
      hasher.combine(stock.category)
      hasher.combine(stock.portfolioListId)
      hasher.combine(stock.ownerUserId)
    }
    return hasher.finalize()
  }

  private var derivationInputs: DerivationInputs {
    DerivationInputs(
      stocksFingerprint: stocksFingerprint,
      ownerUserId: currentOwnerUserId,
      selectedListId: viewModel.selectedPortfolioListId,
      assetFilter: selectedAssetFilter,
      holdingsSort: selectedHoldingsSort,
      pnlBySymbol: viewModel.pnlBySymbol
    )
  }

  private var currentDerived: DerivedPortfolio {
    derived ?? Self.derive(stocks: stocks, inputs: derivationInputs)
  }

  private static func derive(stocks: [SDPortfolioStock], inputs: DerivationInputs) -> DerivedPortfolio {
    let owned = stocks.filter {
      LocalCacheScope.isOwnedByCurrentUser($0.ownerUserId, currentUserId: inputs.ownerUserId)
    }
    let scoped: [SDPortfolioStock]
    if let selectedListId = inputs.selectedListId {
      scoped = owned.filter { ($0.portfolioListId ?? "") == selectedListId }
    } else {
      scoped = owned
    }

    let base: [SDPortfolioStock]
    switch inputs.assetFilter {
    case .all: base = scoped
    case .stocks: base = scoped.filter { ($0.category ?? AssetCategory.stock.rawValue) == AssetCategory.stock.rawValue }
    case .etfs: base = scoped.filter { ($0.category ?? AssetCategory.stock.rawValue) == AssetCategory.etf.rawValue }
    case .crypto: base = scoped.filter { ($0.category ?? AssetCategory.stock.rawValue) == AssetCategory.crypto.rawValue }
    }

    let filtered: [SDPortfolioStock]
    switch inputs.holdingsSort {
    case .name:
      filtered = base.sorted { $0.symbol.localizedCaseInsensitiveCompare($1.symbol) == .orderedAscending }
    case .gains:
      filtered = base.sorted {
        (inputs.pnlBySymbol[PortfolioViewModel.normalizedSymbol($0.symbol)]?.unrealizedPnl ?? -.greatestFiniteMagnitude)
          > (inputs.pnlBySymbol[PortfolioViewModel.normalizedSymbol($1.symbol)]?.unrealizedPnl ?? -.greatestFiniteMagnitude)
      }
    case .weight:
      filtered = base.sorted {
        (inputs.pnlBySymbol[PortfolioViewModel.normalizedSymbol($0.symbol)]?.weightPercent ?? -.greatestFiniteMagnitude)
          > (inputs.pnlBySymbol[PortfolioViewModel.normalizedSymbol($1.symbol)]?.weightPercent ?? -.greatestFiniteMagnitude)
      }
    }

    return DerivedPortfolio(
      scopedStocks: scoped,
      filteredStocks: filtered
    )
  }

  private var scopedStocks: [SDPortfolioStock] { currentDerived.scopedStocks }
  private var filteredStocks: [SDPortfolioStock] { currentDerived.filteredStocks }

  private var cashBalance: Double {
    viewModel.cashBalance
  }

  private var performanceKey: PortfolioViewModel.PerformanceKey {
    PortfolioViewModel.PerformanceKey(
      portfolioListId: viewModel.selectedPortfolioListId,
      range: selectedTimeRange.rawValue
    )
  }

  /// Market value per currency, from the backend P/L. Unpriced holdings are
  /// left out; their value is unknown.
  private var holdingsByCurrency: [String: Double] {
    PortfolioHeroModel.holdingsByCurrency(Array(viewModel.pnlBySymbol.values))
  }

  /// The currency cash and the snapshot series are kept in.
  private var baseCurrency: String? {
    MoneyFormatter.resolvedCode(viewModel.summary?.baseCurrency)
      ?? MoneyFormatter.resolvedCode(viewModel.performance(for: performanceKey)?.baseCurrency)
  }

  /// Holdings plus cash, when both are in one currency. Nil until the P/L
  /// has loaded, so the hero never shows cash alone as the total.
  private var liveTotal: Double? {
    let holdings = holdingsByCurrency
    if viewModel.pnlBySymbol.isEmpty, !scopedStocks.isEmpty { return nil }
    guard holdings.count <= 1 else { return nil }
    if let code = holdings.keys.first, let baseCurrency, code != baseCurrency {
      return holdings[code]
    }
    return holdings.values.reduce(0, +) + cashBalance
  }

  private struct HeroInputs: Equatable {
    let performance: PortfolioPerformanceResponse?
    let holdingsByCurrency: [String: Double]
    let range: TimeRange
    let liveTotal: Double?
  }

  private var heroInputs: HeroInputs {
    HeroInputs(
      performance: viewModel.performance(for: performanceKey),
      holdingsByCurrency: holdingsByCurrency,
      range: selectedTimeRange,
      liveTotal: liveTotal
    )
  }

  private static func makeHeroModel(_ inputs: HeroInputs) -> PortfolioHeroModel {
    PortfolioHeroModel.make(
      performance: inputs.performance,
      holdingsByCurrency: inputs.holdingsByCurrency,
      range: inputs.range,
      now: Date(),
      locale: MoneyFormatter.defaultLocale,
      liveTotal: inputs.liveTotal,
      preferLiveTotal: true
    )
  }

  private var heroModel: PortfolioHeroModel {
    cachedHeroModel ?? Self.makeHeroModel(heroInputs)
  }

  /// Average market value of the priced positions, in their one currency.
  /// A mixed-currency portfolio has no meaningful average without a rate.
  private var averagePositionText: String {
    let holdings = holdingsByCurrency
    let pricedCount = viewModel.pnlBySymbol.values.filter { ($0.currentPrice ?? 0) > 0 }.count
    guard holdings.count == 1, let (code, total) = holdings.first.map({ ($0.key, $0.value) }), pricedCount > 0 else {
      return "\u{2014}"
    }
    return MoneyFormatter.string(total / Double(pricedCount), currencyCode: code)
  }

  private var cashText: String {
    MoneyFormatter.string(cashBalance, currencyCode: baseCurrency)
  }

  private var heroLabel: String {
    viewModel.isShowingAllLists ? "All portfolios" : "Portfolio value"
  }

  private var heroSubtitle: String {
    if viewModel.isShowingAllLists {
      let listCount = viewModel.portfolioLists.count
      return "\(scopedStocks.count) positions across \(listCount) list\(listCount == 1 ? "" : "s")"
    }
    return "\(scopedStocks.count) positions"
  }

  private var isShowingLoadingState: Bool {
    viewModel.isLoading && scopedStocks.isEmpty
  }

  private var loadErrorMessage: String? {
    guard scopedStocks.isEmpty else { return nil }
    return viewModel.errorMessage
  }

  private var isEditSheetPresented: Binding<Bool> {
    Binding(
      get: { viewModel.editingStock != nil },
      set: { if !$0 { dismissEditSheet() } }
    )
  }

  var body: some View {
    ZStack {
      mainContent
    }
    .onAppear(perform: prepareScreen)
    .onChange(of: derivationInputs, initial: true) { _, inputs in
      derived = Self.derive(stocks: stocks, inputs: inputs)
    }
    .onChange(of: heroInputs, initial: true) { _, inputs in
      cachedHeroModel = Self.makeHeroModel(inputs)
    }
    .task(id: performanceKey) {
      // Refetched whenever the range or the list changes; the hero only
      // draws a series fetched for the range it shows.
      await viewModel.loadPerformance(performanceKey)
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        refreshPortfolioQuotesIfActive()
      }
    }
    .refreshable {
      await reloadPortfolio(force: true)
      await viewModel.loadPerformance(performanceKey)
    }
    .onReceive(NotificationCenter.default.publisher(for: .portfolioDataDidChange)) { _ in
      Task { await reloadPortfolio(force: true) }
    }
    .onChange(of: pendingOpenSymbol) { _, _ in
      consumePendingOpenSymbolIfNeeded()
    }
    .onChange(of: pendingThesisWatchOpen) { _, _ in
      consumePendingThesisWatchOpenIfNeeded()
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        portfolioActionsMenu
      }
    }
    .navigationDestination(isPresented: $isOnePagePresented) {
      PortfolioOnePageScreen(viewModel: viewModel)
    }
    .sheet(isPresented: isEditSheetPresented) {
      editSheetContent
    }
    .sheet(isPresented: $isAddPositionPresented, onDismiss: { guided?.noteUserAction(.addHolding) }) {
      addPositionSheetContent
    }
    .sheet(isPresented: $isCSVImportPresented) {
      PortfolioCSVImportSheet(portfolioListId: viewModel.selectedPortfolioListId) {
        await reloadPortfolio(force: true)
      }
    }
    .sheet(isPresented: $isScreenshotImportPresented) {
      PortfolioScreenshotImportSheet(portfolioListId: viewModel.selectedPortfolioListId) {
        await reloadPortfolio(force: true)
      }
    }
    .sheet(item: $targetAlertStock) { stock in
      PortfolioTargetAlertSheet(
        symbol: stock.symbol,
        referencePrice: stock.buyPrice,
        existingAlert: viewModel.targetAlert(for: stock.symbol),
        isSaving: viewModel.isSavingTargetAlert,
        onSave: { price, direction in
          await saveTargetAlert(for: stock.symbol, price: price, direction: direction)
        },
        onDelete: {
          await deleteTargetAlert(for: stock.symbol)
        }
      )
    }
    .sheet(isPresented: $isPaywallPresented) {
      PaywallView(billingManager: billingManager)
    }
    .sheet(isPresented: $isEarningsCalendarPresented) {
      EarningsCalendarScreen()
    }
    .sheet(isPresented: $isSectorGainsPresented) {
      NavigationStack {
        SectorGainsScreen()
      }
    }
    .sheet(isPresented: $isThesisWatchPresented) {
      NavigationStack {
        MarketNewsScreen()
      }
    }
    .navigationDestination(item: $pushNavigationRoute) { route in
      StockDetailScreen(stockId: route.stockID, initialSymbol: route.symbol)
    }
    .toastOverlay($pushFallbackToast)
    .toastOverlay($refreshErrorToast)
    .onChange(of: viewModel.errorMessage) { _, newValue in
      // Full-screen error only covers the empty-cache case; when cached rows
      // are showing, a failed refresh must still be visible.
      guard let newValue, !scopedStocks.isEmpty else { return }
      refreshErrorToast = .error(newValue)
    }
    .onReceive(NotificationCenter.default.publisher(for: .stalePositionPurged)) { note in
      let symbol = note.userInfo?["symbol"] as? String
      refreshErrorToast = .info(
        symbol.map { "\($0) was updated elsewhere — refreshed your portfolio." }
          ?? "Position was updated elsewhere — refreshed your portfolio."
      )
    }
    .onReceive(NotificationCenter.default.publisher(for: .openThesisWatchFromPushNotification)) { _ in
      isThesisWatchPresented = true
    }
    .appSensoryFeedback(destructive: destructiveFeedbackTrigger)
  }

  private func makeEditableStock(from stock: SDPortfolioStock) -> StockResponse {
    StockResponse.editableDraft(from: stock)
  }

  private func portfolioStockRow(_ stock: SDPortfolioStock) -> some View {
    let editableStock = makeEditableStock(from: stock)
    let targetAlert = viewModel.targetAlert(for: stock.symbol)
    return NavigationLink {
      StockDetailScreen(stockId: stock.id, initialSymbol: stock.symbol)
    } label: {
      PortfolioRow(stock: stock, targetAlert: targetAlert, liveQuote: nil, pnl: viewModel.pnl(for: stock.symbol))
        .accessibilityIdentifier("portfolio.stockRow.\(stock.symbol)")
    }
    .buttonStyle(PressableStyle())
    .contextMenu {
      Button(targetAlert == nil ? "Add price alert" : "Edit price alert", systemImage: targetAlert == nil ? "bell.badge" : "bell.fill") {
        presentTargetAlert(for: stock)
      }

      Button("Edit", systemImage: "pencil") {
        beginEditing(editableStock)
      }

      Button("Delete", systemImage: "trash", role: .destructive) {
        deleteStock(id: stock.id)
      }
    }
  }

  @ViewBuilder
  private var mainContent: some View {
    if let loadErrorMessage {
      PortfolioLoadErrorView(error: loadErrorMessage, onRetry: retryLoad)
        .transition(.opacity)
    } else if isShowingLoadingState {
      PortfolioSkeletonView()
        .transition(.opacity)
    } else {
      portfolioScrollContent
        .transition(.opacity)
    }
  }

  private var portfolioScrollContent: some View {
    ScrollView {
      // Lazy so position rows are built as they scroll into view; the
      // last-row `onAppear` sentinel in PortfolioPositionsSection relies on
      // this to fire once per page instead of once per body pass.
      LazyVStack(spacing: 16) {
        VigilPageHeader(
          watch: .wealth,
          title: "Portfolio"
        )

        PortfolioHeroCard(
          heroLabel: heroLabel,
          heroSubtitle: heroSubtitle,
          model: heroModel,
          selectedTimeRange: selectedTimeRange,
          positionCount: scopedStocks.count,
          averagePositionText: averagePositionText,
          cashText: cashText,
          onSelectTimeRange: selectTimeRange
        )

        DcaCapacityCard()

        PortfolioAssetFilters(
          colorScheme: colorScheme,
          selectedAssetFilter: selectedAssetFilter,
          onSelectFilter: selectAssetFilter
        )

        Picker("Sort", selection: $selectedHoldingsSort) {
          ForEach(HoldingsSort.allCases) { sort in
            Text(sort.rawValue).tag(sort)
          }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("portfolio.holdingsSort")
        .onChange(of: selectedHoldingsSort) { _, newValue in
          guard newValue != .name else { return }
          Task { await viewModel.loadAllPagesForSortIfNeeded() }
        }

        if viewModel.isLoadingMore, selectedHoldingsSort != .name {
          HStack(spacing: 8) {
            ProgressView()
            Text("Loading all positions for sort…")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .accessibilityIdentifier("portfolio.sortLoading")
        }

        // Revived from PortfolioSegment.earnings — teaser entry (list free, transcripts Pro)
        Button {
          isEarningsCalendarPresented = true
        } label: {
          HStack {
            Image(systemName: "calendar")
              .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
              Text("Earnings Calendar")
                .typography(.headline, weight: .semibold)
              Text("Upcoming reports & transcripts")
                .typography(.nano)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .foregroundStyle(.secondary)
          }
          .padding()
          .appGlassEffect(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("portfolio.earningsCalendarLink")

        Button {
          isThesisWatchPresented = true
        } label: {
          HStack {
            Image(systemName: "newspaper.fill")
              .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
              Text("Thesis Watch")
                .typography(.headline, weight: .semibold)
              Text("News ranked by holdings, exposure & thesis")
                .typography(.nano)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .foregroundStyle(.secondary)
          }
          .padding()
          .appGlassEffect(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("portfolio.thesisWatchLink")

        Button {
          if billingManager.isPro {
            isSectorGainsPresented = true
          } else {
            PostHogSDK.shared.capture("paywall_viewed", properties: [
              "source": "portfolio_sector_gains",
            ])
            isPaywallPresented = true
          }
        } label: {
          HStack {
            Image(systemName: "chart.bar.fill")
              .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
              Text("Sector Gains")
                .typography(.headline, weight: .semibold)
              Text("Unrealized P/L by sector")
                .typography(.nano)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .foregroundStyle(.secondary)
          }
          .padding()
          .appGlassEffect(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("portfolio.sectorGainsLink")

        if let sentiment = viewModel.portfolioSentiment, sentiment.symbolsTotal > 0 {
          PortfolioSentimentCard(response: sentiment)
            .accessibilityIdentifier("portfolio.sentimentCard")
        }

        PortfolioPositionsSection(
          stocks: filteredStocks,
          liveQuotes: viewModel.liveQuotes,
          pnlProvider: viewModel.pnl(for:),
          targetAlertProvider: viewModel.targetAlert(for:),
          sentimentProvider: viewModel.sentiment(for:),
          onAddPosition: presentAddPositionSheet,
          onEditStock: beginEditing,
          onDeleteStock: deleteStock,
          onPresentTargetAlert: presentTargetAlert,
          onLoadMore: loadMoreIfAvailable
        )
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .onReceive(quoteRefreshTimer) { _ in
        refreshPortfolioQuotesIfActive()
      }
    }
    .vigilScreenBackground()
  }

  private var addPositionSheetContent: some View {
    AddPositionSheet(
      title: "Add Position",
      draft: AddPositionDraft(
        symbol: "",
        companyName: nil,
        shares: "",
        buyPrice: "",
        buyDate: .now,
        notes: "",
        symbolLocked: false
      ),
      isSaving: viewModel.isSaving,
      allocationImpactProvider: allocationImpact(for:),
      onSave: saveNewPosition
    )
  }

  private func presentTargetAlert(for stock: SDPortfolioStock) {
    guard billingManager.isPro else {
      // PostHog: Track paywall shown from portfolio price alert
      PostHogSDK.shared.capture("paywall_viewed", properties: [
        "source": "portfolio_price_alert",
      ])
      isPaywallPresented = true
      return
    }
    targetAlertStock = TargetAlertDraftStock(
      id: stock.id,
      symbol: stock.symbol,
      buyPrice: stock.buyPrice
    )
  }

  private var portfolioActionsMenu: some View {
    Menu {
      Button {
        presentAddPositionSheet()
      } label: {
        Label("Add position", systemImage: "plus")
      }

      Button {
        presentCSVImportSheet()
      } label: {
        Label("Import CSV", systemImage: "square.and.arrow.down.on.square")
      }

      Button {
        presentScreenshotImportSheet()
      } label: {
        Label("Import from screenshots", systemImage: "photo.on.rectangle.angled")
      }

      Button {
        isOnePagePresented = true
      } label: {
        Label("One-page view", systemImage: "list.bullet.rectangle")
      }
    } label: {
      Image(systemName: "plus")
    }
    .accessibilityLabel("Portfolio actions")
    .accessibilityIdentifier("portfolio.actionsMenu")
  }

  private var assetFilters: [AssetFilter] {
    AssetFilter.allCases
  }

  private func prepareScreen() {
    viewModel.setModelContext(modelContext)
    consumePendingOpenSymbolIfNeeded()
    consumePendingThesisWatchOpenIfNeeded()
    Task { await reloadPortfolio() }
  }

  private func reloadPortfolio(force: Bool = false) async {
    await viewModel.load(force: force)
  }

  private func refreshPortfolioQuotesIfActive() {
    guard scenePhase == .active else { return }
    Task { await viewModel.refreshLiveQuotes() }
  }

  private func retryLoad() {
    Task { await reloadPortfolio(force: true) }
  }

  private func dismissEditSheet() {
    viewModel.editingStock = nil
  }

  private func beginEditing(_ stock: StockResponse) {
    viewModel.beginEdit(stock)
  }

  private func saveEditedStock(_ updated: StockResponse) async -> Bool {
    let ok = await viewModel.saveEdit(updated)
    if ok {
      // PostHog: Track successful position edit. Ticker only — no quantities.
      PostHogSDK.shared.capture("position_edited", properties: [
        "symbol": updated.symbol,
      ])
    }
    return ok
  }

  private func deleteEditedStock(id: String) async -> Bool {
    let ok = await viewModel.delete(id: id)
    if ok {
      // PostHog: Track position deletion from edit sheet
      PostHogSDK.shared.capture("position_deleted")
    }
    return ok
  }

  private func saveNewPosition(_ draft: AddPositionDraft) async -> String? {
    let error = await viewModel.saveNewPosition(draft)
    if error == nil {
      // PostHog: Track successful new position addition
      PostHogSDK.shared.capture("position_added", properties: [
        "symbol": draft.symbol,
      ])
    }
    return error
  }

  private func saveTargetAlert(
    for symbol: String,
    price: Double,
    direction: PortfolioTargetAlertDirection
  ) async -> String? {
    await viewModel.saveTargetAlert(symbol: symbol, price: price, direction: direction)
  }

  private func deleteTargetAlert(for symbol: String) async -> String? {
    await viewModel.deleteTargetAlert(symbol: symbol)
  }

  private func presentAddPositionSheet() {
    isAddPositionPresented = true
  }

  private func presentCSVImportSheet() {
    isCSVImportPresented = true
  }

  private func presentScreenshotImportSheet() {
    isScreenshotImportPresented = true
  }

  private func loadMoreIfAvailable() {
    Task { await viewModel.loadMoreIfAvailable() }
  }

  private func allocationImpact(for draft: AddPositionDraft) -> PortfolioAllocationImpact? {
    guard
      let shares = MoneyInputParser.parse(draft.shares),
      let buyPrice = MoneyInputParser.parse(draft.buyPrice)
    else {
      return nil
    }

    return PortfolioAllocationImpactCalculator.preview(
      holdings: allocationHoldings,
      cashBalance: cashBalance,
      change: .newPosition(symbol: draft.symbol, shares: shares, buyPrice: buyPrice)
    )
  }

  private func allocationImpact(for stock: StockResponse) -> PortfolioAllocationImpact? {
    PortfolioAllocationImpactCalculator.preview(
      holdings: allocationHoldings,
      cashBalance: cashBalance,
      change: .replacePosition(
        id: stock.id,
        symbol: stock.symbol,
        shares: stock.shares,
        buyPrice: stock.buyPrice
      )
    )
  }

  private var allocationHoldings: [PortfolioAllocationImpactCalculator.Holding] {
    scopedStocks.map {
      PortfolioAllocationImpactCalculator.Holding(
        id: $0.id,
        symbol: $0.symbol,
        shares: $0.shares,
        buyPrice: $0.buyPrice
      )
    }
  }

  private func deleteStock(id: String) {
    destructiveFeedbackTrigger += 1
    Task {
      let ok = await viewModel.delete(id: id)
      if ok {
        // PostHog: Track position deletion from list
        PostHogSDK.shared.capture("position_deleted")
      }
    }
  }

  private func selectTimeRange(_ range: TimeRange) {
    withAnimation(AppMotion.state) {
      selectedTimeRange = range
    }
  }

  private func selectAssetFilter(_ filter: AssetFilter) {
    withAnimation(AppMotion.state) {
      selectedAssetFilter = filter
    }
  }

  @ViewBuilder
  private var editSheetContent: some View {
    if let stock = viewModel.editingStock {
      EditStockPositionSheet(
        stock: stock,
        isSaving: viewModel.isSaving,
        isDeleting: viewModel.isDeletingStock,
        allocationImpactProvider: allocationImpact(for:),
        onCancel: dismissEditSheet,
        onSave: saveEditedStock,
        onDelete: {
          await deleteEditedStock(id: stock.id)
        }
      )
    }
  }

  private func consumePendingOpenSymbolIfNeeded() {
    guard
      let symbol = pendingOpenSymbol?.trimmingCharacters(in: .whitespacesAndNewlines),
      !symbol.isEmpty
    else {
      return
    }

    pendingOpenSymbol = nil
    openStockFromPushNotification(symbol: symbol)
  }

  private func consumePendingThesisWatchOpenIfNeeded() {
    guard pendingThesisWatchOpen else { return }
    pendingThesisWatchOpen = false
    isThesisWatchPresented = true
  }

  private func openStockFromPushNotification(symbol: String) {
    let normalizedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !normalizedSymbol.isEmpty else {
      Self.pushLogger.warning("push.analytics routed_failure destination=stock_detail reason=empty_symbol")
      return
    }

    guard let stock = scopedStocks.first(where: { $0.symbol.uppercased() == normalizedSymbol }) else {
      Self.pushLogger.warning("push.analytics routed_failure destination=stock_detail reason=symbol_not_found symbol=\(normalizedSymbol, privacy: .public)")
      showPushFallbackMessage("No holding found for \(normalizedSymbol). Open Portfolio to review positions.")
      return
    }

    Self.pushLogger.info("push.analytics routed_success destination=stock_detail symbol=\(stock.symbol, privacy: .public) stock_id=\(stock.id, privacy: .public)")
    pushNavigationRoute = PushNavigationRoute(stockID: stock.id, symbol: stock.symbol)
  }

  private func showPushFallbackMessage(_ message: String) {
    pushFallbackToast = .info(message)
  }
}
