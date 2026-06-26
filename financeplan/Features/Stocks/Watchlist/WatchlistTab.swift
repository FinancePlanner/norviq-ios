import StockPlanShared
import SwiftUI
import SwiftData

struct WatchlistTab: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var portfolioViewModel: PortfolioViewModel
  @ObservedObject var viewModel: WatchlistViewModel

  @Query(sort: \SDWatchlistItem.symbol) private var items: [SDWatchlistItem]

  @State private var convertingItem: SDWatchlistItem?
  @State private var removePromptItem: SDWatchlistItem?
  @State private var destructiveFeedbackTrigger = 0
  @State private var selectedTradingSymbol: String?
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
      Task { await viewModel.refreshLiveQuotes() }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          viewModel.isAddWatchlistPresented = true
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Add watchlist item")
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
    .sheet(item: $selectedTradingSymbol) { symbol in
      TradingStockSheet(symbol: symbol)
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
            .animation(.easeInOut(duration: 0.25), value: q.currentPrice)
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
          .animation(.easeInOut(duration: 0.3), value: chg)
          .animation(.easeInOut(duration: 0.3), value: pct)
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
