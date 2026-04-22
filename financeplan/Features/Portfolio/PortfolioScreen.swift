import Combine
import OSLog
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
  @EnvironmentObject private var viewModel: PortfolioViewModel
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
    scopedStocks.reduce(0) { $0 + ($1.shares * $1.buyPrice) }
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

  var body: some View {
    rootContent
    .animation(.smooth(duration: 0.3), value: viewModel.isLoading)
    .onAppear {
        viewModel.setModelContext(modelContext)
        Task { await viewModel.load() }
        rebuildChartData()
        consumePendingOpenSymbolIfNeeded()
    }
    .onChange(of: totalValue) { _, _ in
      rebuildChartData()
    }
    .onChange(of: selectedTimeRange) { _, _ in
      rebuildChartData()
    }
    .onChange(of: viewModel.selectedPortfolioListId) { _, _ in
      rebuildChartData()
    }
    .refreshable { await viewModel.load(force: true) }
    .onReceive(NotificationCenter.default.publisher(for: .portfolioDataDidChange)) { _ in
      Task { await viewModel.load(force: true) }
    }
    .onChange(of: pendingOpenSymbol) { _, _ in
      consumePendingOpenSymbolIfNeeded()
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        portfolioActionsMenu
      }
    }
    .sheet(
      isPresented: Binding<Bool>(
        get: { viewModel.editingStock != nil },
        set: { if !$0 { viewModel.editingStock = nil } }
      )
    ) {
      if let stock = viewModel.editingStock {
        EditStockPositionSheet(
          stock: stock,
          isSaving: viewModel.isSaving,
          isDeleting: viewModel.isDeletingStock,
          onCancel: { viewModel.editingStock = nil },
          onSave: { updated in
            await viewModel.saveEdit(updated)
          },
          onDelete: {
            await viewModel.delete(id: stock.id)
          }
        )
      }
    }
    .sheet(isPresented: $isAddPositionPresented) {
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
        onSave: { draft in
          await viewModel.saveNewPosition(draft)
        }
      )
    }
    .sheet(isPresented: $isCSVImportPresented) {
      PortfolioCSVImportSheet {
        await viewModel.load(force: true)
      }
    }
    .sheet(item: $targetAlertStock) { stock in
      PortfolioTargetAlertSheet(
        symbol: stock.symbol,
        referencePrice: stock.buyPrice,
        existingAlert: viewModel.targetAlert(for: stock.symbol),
        isSaving: viewModel.isSavingTargetAlert,
        onSave: { price, direction in
          await viewModel.saveTargetAlert(
            symbol: stock.symbol,
            price: price,
            direction: direction
          )
        },
        onDelete: {
          await viewModel.deleteTargetAlert(symbol: stock.symbol)
        }
      )
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

  private var rootContent: AnyView {
    if viewModel.isLoading && scopedStocks.isEmpty {
      return AnyView(
        PortfolioSkeletonView()
          .transition(.opacity)
      )
    }

    if let error = viewModel.errorMessage, scopedStocks.isEmpty {
      return AnyView(
        ContentUnavailableView {
          Label("Unable to Load Portfolio", systemImage: "exclamationmark.triangle")
        } description: {
          Text(error)
        } actions: {
          Button("Retry") {
            Task { await viewModel.load(force: true) }
          }
          .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      )
    }

    return AnyView(
      ScrollView {
        VStack(spacing: 16) {
          // Hero Chart Card
          GlassCard(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 16) {
              VStack(alignment: .leading, spacing: 4) {
                Text(heroLabel)
                  .typography(.small, weight: .semibold)
                  .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                  Text(totalValue.currency)
                    .typography(.hero, weight: .bold)
                    .contentTransition(.numericText())
                  Text(heroSubtitle)
                    .typography(.small)
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                  Image(systemName: totalValue > 0 ? "arrow.up.right" : "minus")
                  Text(totalValue > 0 ? "+2.31% ($2,816.32)" : "No portfolio trend yet")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(totalValue > 0 ? .green : .secondary)
              }
              .padding(.horizontal, 4)

              InteractiveLineChart(data: chartData, color: .green)
                .frame(minHeight: 160, maxHeight: .infinity)
                .padding(.horizontal, -12) // Bleed to edges of card padding

              // Time range picker
              HStack(spacing: 0) {
                ForEach(Array(TimeRange.allCases), id: \.self) { range in
                  timeRangeButton(range)
                }
              }

              HStack {
                PortfolioMetricPill(
                  title: "Shares",
                  value: totalShares.formatted(.number.precision(.fractionLength(0...2))),
                  tint: AppTheme.Colors.secondaryTint(for: colorScheme)
                )
                PortfolioMetricPill(
                  title: "Avg / position",
                  value: averagePositionValue.currency,
                  tint: AppTheme.Colors.tint(for: colorScheme)
                )
                PortfolioMetricPill(
                  title: "Cash",
                  value: cashBalance.currency,
                  tint: .mint
                )
              }
            }
          }
          .foregroundStyle(.primary)

          // Asset Filter
          HStack(spacing: 0) {
            ForEach(assetFilters.indices, id: \.self) { index in
              assetFilterButton(assetFilters[index])
            }
          }
          .padding(4)
          .background(Color(uiColor: .secondarySystemGroupedBackground))
          .cornerRadius(14)

          portfolioPositionsSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
      }
      .transition(.opacity)
    )
  }

  private func rebuildChartData() {
    chartData = Self.makeChartData(totalValue: totalValue, timeRange: selectedTimeRange)
  }

  private func makeEditableStock(from stock: SDPortfolioStock) -> StockResponse {
    let category = AssetCategory(rawValue: stock.category ?? AssetCategory.stock.rawValue) ?? .stock
    return StockResponse(
      id: stock.id,
      symbol: stock.symbol,
      shares: stock.shares,
      buyPrice: stock.buyPrice,
      buyDate: stock.buyDate,
      notes: stock.notes,
      category: category
    )
  }

  private func portfolioStockRow(_ stock: SDPortfolioStock) -> some View {
    let editableStock = makeEditableStock(from: stock)
    let targetAlert = viewModel.targetAlert(for: stock.symbol)
    return NavigationLink {
      StockDetailScreen(stockId: stock.id, initialSymbol: stock.symbol)
    } label: {
      PortfolioRow(stock: stock, targetAlert: targetAlert)
    }
    .buttonStyle(CardButtonStyle())
    .contextMenu {
      Button(targetAlert == nil ? "Add price alert" : "Edit price alert", systemImage: targetAlert == nil ? "bell.badge" : "bell.fill") {
        presentTargetAlert(for: stock)
      }

      Button("Edit", systemImage: "pencil") {
        viewModel.beginEdit(editableStock)
      }

      Button("Delete", systemImage: "trash", role: .destructive) {
        destructiveFeedbackTrigger += 1
        Task { await viewModel.delete(id: stock.id) }
      }
    }
  }

  private func presentTargetAlert(for stock: SDPortfolioStock) {
    targetAlertStock = TargetAlertDraftStock(
      id: stock.id,
      symbol: stock.symbol,
      buyPrice: stock.buyPrice
    )
  }

  @ViewBuilder
  private var portfolioPositionsSection: some View {
    if filteredStocks.isEmpty {
      ContentUnavailableView {
        Label("No Positions", systemImage: "chart.line.uptrend.xyaxis")
      } description: {
        Text("Add your first holding or change your filter.")
      } actions: {
        Button("Add Position") {
          isAddPositionPresented = true
        }
        .buttonStyle(.borderedProminent)
      }
      .padding(.vertical, 24)
    } else {
      ForEach(filteredStocks) { stock in
        portfolioStockRow(stock)
      }
    }
  }

  private var portfolioActionsMenu: some View {
    Menu {
      Button {
        isAddPositionPresented = true
      } label: {
        Label("Add position", systemImage: "plus")
      }

      Button {
        isCSVImportPresented = true
      } label: {
        Label("Import CSV", systemImage: "square.and.arrow.down.on.square")
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

  private func timeRangeButton(_ range: TimeRange) -> AnyView {
    let isSelected = selectedTimeRange == range
    let button = Button(action: {
      withAnimation { selectedTimeRange = range }
    }) {
      Text(range.rawValue)
        .font(.caption.weight(.semibold))
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.white.opacity(0.15) : Color.clear)
        .cornerRadius(8)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }
    return AnyView(button)
  }

  private func assetFilterButton(_ filter: AssetFilter) -> AnyView {
    let isSelected = selectedAssetFilter == filter
    let button = Button(action: {
      withAnimation { selectedAssetFilter = filter }
    }) {
      Text(filter.rawValue)
        .font(.subheadline.weight(.medium))
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.white.opacity(0.15) : Color.clear)
        .cornerRadius(10)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }
    return AnyView(button)
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

private struct PortfolioRow: View {
  let stock: SDPortfolioStock
  let targetAlert: TargetResponse?

  var body: some View {
    GlassCard(cornerRadius: 22) {
      HStack(spacing: 16) {
        Circle()
          .fill(Color.white.opacity(0.1))
          .frame(width: 48, height: 48)
          .overlay(
            Text(stock.symbol.prefix(1))
              .font(.title2.weight(.bold))
              .foregroundStyle(.white)
          )

        VStack(alignment: .leading, spacing: 4) {
          Text(stock.symbol)
            .font(.headline)
            .foregroundStyle(.primary)

          if let notes = stock.notes, !notes.isEmpty {
            Text(notes)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          } else {
             Text("Holding")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Text("\(stock.shares.formatted(.number.precision(.fractionLength(0...2)))) Shares")
            .font(.caption)
            .foregroundStyle(.secondary)

          if let targetAlert {
            Label(targetAlert.targetPrice.currency, systemImage: "bell.fill")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.orange)
              .lineLimit(1)
          }
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text((stock.shares * stock.buyPrice).currency)
            .font(.headline)
            .foregroundStyle(.primary)

          Text("No trend")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 4)
    }
  }
}

private struct PortfolioTargetAlertSheet: View {
  @Environment(\.dismiss) private var dismiss

  let symbol: String
  let referencePrice: Double
  let existingAlert: TargetResponse?
  let isSaving: Bool
  let onSave: (Double, PortfolioTargetAlertDirection) async -> String?
  let onDelete: () async -> String?

  @State private var isEnabled: Bool
  @State private var priceText: String
  @State private var direction: PortfolioTargetAlertDirection
  @State private var errorMessage: String?

  init(
    symbol: String,
    referencePrice: Double,
    existingAlert: TargetResponse?,
    isSaving: Bool,
    onSave: @escaping (Double, PortfolioTargetAlertDirection) async -> String?,
    onDelete: @escaping () async -> String?
  ) {
    self.symbol = symbol
    self.referencePrice = referencePrice
    self.existingAlert = existingAlert
    self.isSaving = isSaving
    self.onSave = onSave
    self.onDelete = onDelete
    _isEnabled = State(initialValue: existingAlert != nil)
    _priceText = State(initialValue: Self.initialPriceText(existingAlert: existingAlert, referencePrice: referencePrice))
    _direction = State(initialValue: existingAlert.map { PortfolioTargetAlertDirection.fromScenario($0.scenario) } ?? .above)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle(isOn: $isEnabled) {
            Label("Notify at price", systemImage: "bell.badge")
          }

          Picker("Direction", selection: $direction) {
            ForEach(PortfolioTargetAlertDirection.allCases) { direction in
              Text(direction.title).tag(direction)
            }
          }
          .pickerStyle(.segmented)
          .disabled(!isEnabled)

          TextField("Target price", text: $priceText)
            .keyboardType(.decimalPad)
            .disabled(!isEnabled)
        } header: {
          Text(symbol)
        } footer: {
          Text("Reference price: \(referencePrice.currency)")
        }

        if let errorMessage {
          Section {
            Text(errorMessage)
              .foregroundStyle(AppTheme.Colors.danger)
          }
        }
      }
      .navigationTitle("Price Alert")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(isEnabled ? "Save" : "Turn Off") {
            save()
          }
          .disabled(isSaving)
        }
      }
    }
    .presentationDetents([.medium])
  }

  private func save() {
    Task {
      if isEnabled {
        guard let price = MoneyInputParser.parse(priceText), price > 0 else {
          errorMessage = "Enter a valid target price."
          return
        }
        errorMessage = await onSave(price, direction)
      } else {
        errorMessage = await onDelete()
      }

      if errorMessage == nil {
        dismiss()
      }
    }
  }

  private static func initialPriceText(existingAlert: TargetResponse?, referencePrice: Double) -> String {
    let price = existingAlert?.targetPrice ?? referencePrice
    guard price > 0 else { return "" }
    return price.formatted(.number.precision(.fractionLength(0...2)))
  }
}

private struct PortfolioMetricPill: View {
  let title: String
  let value: String
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .typography(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .typography(.small, weight: .semibold)
        .foregroundStyle(.primary)
        .contentTransition(.numericText())
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .appGlassEffect(.rect(cornerRadius: 16), tint: tint.opacity(0.10))
  }
}

// MARK: - Premium UI Helpers

private struct CardButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
      .opacity(configuration.isPressed ? 0.9 : 1.0)
  }
}

private struct PortfolioSkeletonView: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(.gray.opacity(0.12))
          .frame(height: 140)
          .shimmer()

        ForEach(0..<4, id: \.self) { _ in
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.gray.opacity(0.12))
            .frame(height: 110)
            .shimmer()
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
  }
}
