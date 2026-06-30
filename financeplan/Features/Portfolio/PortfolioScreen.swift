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
  @EnvironmentObject private var viewModel: PortfolioViewModel
  @InjectedObservable(\Container.billingManager) private var billingManager
  @Binding var pendingOpenSymbol: String?

  @Query(sort: \SDPortfolioStock.symbol) private var stocks: [SDPortfolioStock]

  @State private var isAddPositionPresented = false
  @State private var isCSVImportPresented = false
  @State private var destructiveFeedbackTrigger = 0
  @State private var selectedTimeRange: TimeRange = .month
  @State private var selectedAssetFilter: AssetFilter = .all
  @State private var chartData: [ChartDataPoint] = []
  @State private var pushNavigationRoute: PushNavigationRoute?
  @State private var pushFallbackMessage: String?
  @State private var pushFallbackMessageToken: UUID?
  @State private var targetAlertStock: TargetAlertDraftStock?
  @State private var isPaywallPresented = false
  @State private var isEarningsCalendarPresented = false
  @State private var isSectorGainsPresented = false
  @State private var selectedTradingSymbol: String?

  private let quoteRefreshTimer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

  enum TimeRange: String, CaseIterable, Identifiable {
      case day = "1D"
      case week = "1W"
      case month = "1M"
      case threeMonths = "3M"
      case year = "1Y"
      case all = "ALL"
      var id: String { rawValue }
  }

  enum AssetFilter: String, CaseIterable, Identifiable {
      case all = "All Assets"
      case stocks = "Stocks"
      case etfs = "ETFs"
      case crypto = "Crypto"
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

  private var ownedStocks: [SDPortfolioStock] {
    stocks.filter { LocalCacheScope.isOwnedByCurrentUser($0.ownerUserId, currentUserId: currentOwnerUserId) }
  }

  private var scopedStocks: [SDPortfolioStock] {
    guard let selectedListId = viewModel.selectedPortfolioListId else {
      return ownedStocks
    }
    return ownedStocks.filter { ($0.portfolioListId ?? "") == selectedListId }
  }

  private var holdingsValue: Double {
    scopedStocks.reduce(0) { total, stock in
      let price = viewModel.liveQuotes[stock.symbol.uppercased()]?.currentPrice ?? stock.buyPrice
      return total + (stock.shares * price)
    }
  }

  private var cashBalance: Double {
    viewModel.cashBalance
  }

  private var totalValue: Double {
    holdingsValue + cashBalance
  }

  private var filteredStocks: [SDPortfolioStock] {
      switch selectedAssetFilter {
      case .all: return scopedStocks
      case .stocks: return scopedStocks.filter { ($0.category ?? AssetCategory.stock.rawValue) == AssetCategory.stock.rawValue }
      case .etfs: return scopedStocks.filter { ($0.category ?? AssetCategory.stock.rawValue) == AssetCategory.etf.rawValue }
      case .crypto: return scopedStocks.filter { ($0.category ?? AssetCategory.stock.rawValue) == AssetCategory.crypto.rawValue }
      }
  }

  private var totalShares: Double {
    scopedStocks.reduce(0) { $0 + $1.shares }
  }

  private var averagePositionValue: Double {
    guard !scopedStocks.isEmpty else { return 0 }
    return holdingsValue / Double(scopedStocks.count)
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
    .animation(.smooth(duration: 0.3), value: viewModel.isLoading)
    .onAppear(perform: prepareScreen)
    .onChange(of: totalValue) { _, _ in
      rebuildChartData()
    }
    .onChange(of: selectedTimeRange) { _, _ in
      rebuildChartData()
    }
    .onChange(of: viewModel.selectedPortfolioListId) { _, _ in
      rebuildChartData()
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        refreshPortfolioQuotesIfActive()
      }
    }
    .refreshable {
      await reloadPortfolio(force: true)
    }
    .onReceive(NotificationCenter.default.publisher(for: .portfolioDataDidChange)) { _ in
      Task { await reloadPortfolio(force: true) }
    }
    .onChange(of: pendingOpenSymbol) { _, _ in
      consumePendingOpenSymbolIfNeeded()
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        portfolioActionsMenu
      }
    }
    .sheet(isPresented: isEditSheetPresented) {
      editSheetContent
    }
    .sheet(isPresented: $isAddPositionPresented) {
      addPositionSheetContent
    }
    .sheet(isPresented: $isCSVImportPresented) {
      PortfolioCSVImportSheet(portfolioListId: viewModel.selectedPortfolioListId) {
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
    .sheet(
      isPresented: Binding(
        get: { selectedTradingSymbol != nil },
        set: { isPresented in
          if !isPresented {
            selectedTradingSymbol = nil
          }
        }
      )
    ) {
      if let selectedTradingSymbol {
        TradingStockSheet(symbol: selectedTradingSymbol)
      }
    }
    .navigationDestination(item: $pushNavigationRoute) { route in
      StockDetailScreen(stockId: route.stockID, initialSymbol: route.symbol)
    }
    .overlay(alignment: .top) {
      if let pushFallbackMessage {
        ToastBanner(message: pushFallbackMessage, style: .info)
          .padding(.top, 8)
          .padding(.horizontal, 16)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .appSensoryFeedback(destructive: destructiveFeedbackTrigger)
  }

  private func rebuildChartData() {
    chartData = Self.makeChartData(totalValue: totalValue, timeRange: selectedTimeRange)
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
      PortfolioRow(stock: stock, targetAlert: targetAlert, liveQuote: nil)
        .accessibilityIdentifier("portfolio.stockRow.\(stock.symbol)")
    }
    .buttonStyle(CardButtonStyle())
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
      VStack(spacing: 16) {
        PortfolioHeroCard(
          colorScheme: colorScheme,
          heroLabel: heroLabel,
          totalValue: totalValue,
          heroSubtitle: heroSubtitle,
          chartData: chartData,
          selectedTimeRange: selectedTimeRange,
          totalShares: totalShares,
          averagePositionValue: averagePositionValue,
          cashBalance: cashBalance,
          onSelectTimeRange: selectTimeRange
        )

        PortfolioAssetFilters(
          colorScheme: colorScheme,
          selectedAssetFilter: selectedAssetFilter,
          onSelectFilter: selectAssetFilter
        )

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

        PortfolioPositionsSection(
          stocks: filteredStocks,
          liveQuotes: viewModel.liveQuotes,
          targetAlertProvider: viewModel.targetAlert(for:),
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
        selectedTradingSymbol = "AAPL" // Demo: opens polished trading sheet with candle chart
      } label: {
        Label("Quick Trade (Sheet)", systemImage: "chart.candlestick")
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
    rebuildChartData()
    consumePendingOpenSymbolIfNeeded()
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
      // PostHog: Track successful position edit
      PostHogSDK.shared.capture("position_edited", properties: [
        "symbol": updated.symbol,
        "shares": updated.shares,
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

  private func loadMoreIfAvailable() {
    Task { await viewModel.loadMoreIfAvailable() }
  }

  private func allocationImpact(for draft: AddPositionDraft) -> PortfolioAllocationImpact? {
    guard
      let shares = Double(draft.shares),
      let buyPrice = Double(draft.buyPrice)
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
    withAnimation {
      selectedTimeRange = range
    }
  }

  private func selectAssetFilter(_ filter: AssetFilter) {
    withAnimation {
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
    withAnimation(.easeInOut(duration: 0.2)) {
      pushFallbackMessage = message
    }

    let token = UUID()
    pushFallbackMessageToken = token

    Task { @MainActor in
      try? await Task.sleep(for: .seconds(4))
      guard pushFallbackMessageToken == token else { return }
      withAnimation(.easeInOut(duration: 0.2)) {
        pushFallbackMessage = nil
      }
    }
  }

  private static func makeChartData(totalValue: Double, timeRange: TimeRange) -> [ChartDataPoint] {
    let calendar = Calendar.current
    let today = Date()
    guard totalValue > 0 else {
      return []
    }
    let baseValue = totalValue

    let (count, component): (Int, Calendar.Component) = {
      switch timeRange {
      case .day:
        return (24, .hour)
      case .week:
        return (7, .day)
      case .month:
        return (30, .day)
      case .threeMonths:
        return (90, .day)
      case .year:
        return (52, .weekOfYear)
      case .all:
        return (60, .month)
      }
    }()

    return (0..<count).compactMap { i in
      let offset = count - 1 - i
      guard let date = calendar.date(byAdding: component, value: -offset, to: today) else {
        return nil
      }

      let phase = Double(i)
      let seasonal = sin(phase * 0.45) * baseValue * 0.018
      let secondaryWave = cos(phase * 0.19) * baseValue * 0.007
      let trend = phase * (baseValue * 0.0012)
      let value = max(0, baseValue * 0.78 + seasonal + secondaryWave + trend)

      return ChartDataPoint(date: date, value: value)
    }
  }
}
