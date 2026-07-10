import Combine
import StockPlanShared
import SwiftUI
import SwiftData

struct WatchlistTab: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var portfolioViewModel: PortfolioViewModel
  @ObservedObject var viewModel: WatchlistViewModel

  @Query(sort: \SDWatchlistItem.symbol) private var items: [SDWatchlistItem]

  @State private var convertingItem: SDWatchlistItem?
  @State private var removePromptItem: SDWatchlistItem?
  @State private var destructiveFeedbackTrigger = 0
  @State private var selectedTradingSymbol: String?
  @State private var isCSVImportPresented = false
  @State private var isCreateListPresented = false
  @State private var isRenameListPresented = false
  @State private var isDeleteListPresented = false
  @State private var listNameDraft = ""
  private let quoteRefreshTimer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

  private var ownedItems: [SDWatchlistItem] {
    let currentUserId = LocalCacheScope.currentOwnerUserId
    return items.filter { LocalCacheScope.isOwnedByCurrentUser($0.ownerUserId, currentUserId: currentUserId) }
  }

  private var scopedItems: [SDWatchlistItem] {
    guard let selectedListId = viewModel.selectedWatchlistListId else {
      return ownedItems
    }
    return ownedItems.filter { ($0.watchlistListId ?? "") == selectedListId }
  }

  init(viewModel: WatchlistViewModel = WatchlistViewModel()) {
    self.viewModel = viewModel
  }

  var body: some View {
    List {
      if let errorMessage = viewModel.errorMessage {
        Section {
          Text(errorMessage)
            .foregroundStyle(AppTheme.Colors.danger)
        }
      }

      watchlistListSection

      if scopedItems.isEmpty {
        emptyWatchlistSection
      }

      ForEach(scopedItems) { item in
        let live = viewModel.liveQuotes[item.symbol.uppercased()]
        WatchlistRow(
          item: item,
          liveQuote: live,
          onAddToPortfolio: { convertingItem = item },
          onQuickTrade: { selectedTradingSymbol = item.symbol }
        )
        .swipeActions {
          Button(role: .destructive) {
            destructiveFeedbackTrigger += 1
            Task {
              await viewModel.removeFromWatchlist(watchlistResponse(from: item))
            }
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .onAppear {
      viewModel.setModelContext(modelContext)
      Task { await viewModel.load(force: true) }
    }
    .onReceive(quoteRefreshTimer) { _ in
      refreshWatchlistQuotesIfActive()
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        refreshWatchlistQuotesIfActive()
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        watchlistActionsMenu
      }
    }
    .sheet(isPresented: $viewModel.isAddWatchlistPresented) {
      AddWatchlistSheet(
        draft: viewModel.addWatchlistDraft,
        isSaving: viewModel.isSaving,
        onSave: { draft in
          await viewModel.saveWatchlist(draft)
        }
      )
    }
    .sheet(isPresented: $isCSVImportPresented) {
      WatchlistCSVImportSheet(
        watchlistListId: viewModel.selectedWatchlistListId,
        listName: selectedList?.name
      ) {
        await viewModel.load(force: true)
      }
    }
    .alert("New theme", isPresented: $isCreateListPresented) {
      TextField("Name", text: $listNameDraft)
      Button("Cancel", role: .cancel) {
        listNameDraft = ""
      }
      Button("Create") {
        Task {
          _ = await viewModel.createWatchlistList(name: listNameDraft)
          listNameDraft = ""
        }
      }
    }
    .alert("Rename theme", isPresented: $isRenameListPresented) {
      TextField("Name", text: $listNameDraft)
      Button("Cancel", role: .cancel) {
        listNameDraft = ""
      }
      Button("Save") {
        guard let selectedList else { return }
        Task {
          _ = await viewModel.renameWatchlistList(id: selectedList.id, name: listNameDraft)
          listNameDraft = ""
        }
      }
    }
    .confirmationDialog("Delete theme?", isPresented: $isDeleteListPresented) {
      Button("Delete", role: .destructive) {
        guard let selectedList else { return }
        Task {
          _ = await viewModel.deleteWatchlistList(id: selectedList.id)
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Symbols move to your default theme.")
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
    .sheet(item: $convertingItem) { item in
      AddPositionSheet(
        title: "Add to Portfolio",
        draft: AddPositionDraft(
          symbol: item.symbol,
          companyName: nil,
          shares: "",
          buyPrice: "",
          buyDate: .now,
          notes: item.note ?? "",
          symbolLocked: true
        ),
        isSaving: viewModel.isSaving,
        onSave: { draft in
          let result = await viewModel.savePosition(
            from: watchlistResponse(from: item),
            draft: draft,
            portfolioListId: portfolioViewModel.selectedPortfolioListId
          )
          if result == nil {
            removePromptItem = item
          }
          return result
        }
      )
    }
    .confirmationDialog(
      "Remove from watchlist?",
      isPresented: Binding(
        get: { removePromptItem != nil },
        set: { if !$0 { removePromptItem = nil } }
      ),
      presenting: removePromptItem
    ) { item in
      Button("Remove", role: .destructive) {
        destructiveFeedbackTrigger += 1
        Task {
          await viewModel.removeFromWatchlist(watchlistResponse(from: item))
        }
      }
      Button("Keep", role: .cancel) {
        removePromptItem = nil
      }
    } message: { item in
      Text("\(item.symbol) was added to your portfolio.")
    }
    .task { await viewModel.load() }
    .refreshable { await viewModel.load(force: true) }
    .appSensoryFeedback(destructive: destructiveFeedbackTrigger)
  }

  private func refreshWatchlistQuotesIfActive() {
    guard scenePhase == .active else { return }
    Task { await viewModel.refreshLiveQuotes() }
  }

  private var selectedList: WatchlistListDTOResponse? {
    viewModel.watchlistLists.first { $0.id == viewModel.selectedWatchlistListId }
  }

  private var watchlistListSection: some View {
    Section("Themes") {
      if viewModel.watchlistLists.isEmpty {
        Text("No themes yet.")
          .foregroundStyle(.secondary)
      } else {
        Picker("Theme", selection: selectedListBinding) {
          ForEach(viewModel.watchlistLists) { list in
            Text(list.name).tag(list.id)
          }
        }
      }
    }
  }

  private var selectedListBinding: Binding<String> {
    Binding(
      get: { viewModel.selectedWatchlistListId ?? viewModel.watchlistLists.first?.id ?? "" },
      set: { listId in
        Task { await viewModel.selectWatchlistList(listId) }
      }
    )
  }

  private var watchlistActionsMenu: some View {
    Menu {
      Button {
        viewModel.isAddWatchlistPresented = true
      } label: {
        Label("Add symbol", systemImage: "plus")
      }

      Button {
        isCSVImportPresented = true
      } label: {
        Label("Import CSV", systemImage: "square.and.arrow.down.on.square")
      }
      .disabled(viewModel.selectedWatchlistListId == nil)

      Button {
        listNameDraft = ""
        isCreateListPresented = true
      } label: {
        Label("New theme", systemImage: "folder.badge.plus")
      }

      Button {
        listNameDraft = selectedList?.name ?? ""
        isRenameListPresented = true
      } label: {
        Label("Rename theme", systemImage: "pencil")
      }
      .disabled(selectedList == nil)

      Button(role: .destructive) {
        isDeleteListPresented = true
      } label: {
        Label("Delete theme", systemImage: "trash")
      }
      .disabled(selectedList?.isDefault ?? true)
    } label: {
      Image(systemName: "plus")
    }
    .buttonStyle(.bordered)
    .accessibilityLabel("Watchlist actions")
  }

  private func watchlistResponse(from item: SDWatchlistItem) -> WatchlistItemResponse {
    WatchlistItemResponse(
      id: item.id,
      symbol: item.symbol,
      note: item.note,
      status: WatchlistStatus(rawValue: item.status) ?? .active,
      nextReviewAt: item.nextReviewAt
    )
  }

  private var emptyWatchlistSection: some View {
    Section {
      ContentUnavailableView {
        Label("No Watchlist Items", systemImage: "star")
      } description: {
        Text("Save names you want to revisit so research and entry timing stay organized.")
      } actions: {
        Button("Add Watchlist Item", action: presentAddWatchlistSheet)
          .buttonStyle(.borderedProminent)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
    }
  }

  private func presentAddWatchlistSheet() {
    viewModel.isAddWatchlistPresented = true
  }
}

private struct WatchlistRow: View {
  let item: SDWatchlistItem
  let liveQuote: QuoteResponse?
  let onAddToPortfolio: () -> Void
  let onQuickTrade: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(item.symbol)
          .typography(.label, weight: .semibold)

        Spacer()

        if let q = liveQuote {
          Text(q.currentPrice.currency)
            .typography(.label, weight: .bold)
            .monospacedDigit()
            .foregroundStyle(.primary)
        }

        Text(item.status.capitalized)
          .typography(.nano, weight: .semibold)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .appGlassEffect(.capsule)
      }

      if let q = liveQuote, let pct = q.percentChange {
        let chg = q.change ?? 0
        Text(StockMetricFormatter.signedCurrencyText(chg) + " (" + StockMetricFormatter.signedPercentText(pct) + ")")
          .typography(.caption)
          .foregroundStyle(chg >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger)
      }

      if let note = item.note, !note.isEmpty {
        Text(note)
          .typography(.small)
          .foregroundStyle(.secondary)
      }

      HStack {
        if let nextReviewAt = item.nextReviewAt {
          Text("Review \(nextReviewAt)")
            .typography(.nano)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button("Add to portfolio", action: onAddToPortfolio)
          .buttonStyle(.borderedProminent)
          .controlSize(.small)

        if let onQuickTrade {
          Button("Trade", action: onQuickTrade)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
      }
    }
    .padding(.vertical, 6)
    .contentShape(Rectangle())
    .onTapGesture {
      onQuickTrade?()
    }
  }
}
