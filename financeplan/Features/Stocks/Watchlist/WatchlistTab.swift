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

  private var scopedItems: [SDWatchlistItem] {
    guard let selectedListId = viewModel.selectedWatchlistListId else {
      return items
    }
    return items.filter { ($0.watchlistListId ?? "") == selectedListId }
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
        WatchlistRow(
          item: item,
          onAddToPortfolio: { convertingItem = item }
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
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          viewModel.isAddWatchlistPresented = true
        } label: {
          Image(systemName: "plus")
        }
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
  let onAddToPortfolio: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(item.symbol)
          .typography(.label, weight: .semibold)

        Spacer()

        Text(item.status.capitalized)
          .typography(.nano, weight: .semibold)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .appGlassEffect(.capsule)
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
      }
    }
    .padding(.vertical, 6)
  }
}
