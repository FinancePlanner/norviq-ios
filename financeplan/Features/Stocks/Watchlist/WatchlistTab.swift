import StockPlanShared
import SwiftUI

extension WatchlistItemResponse: Identifiable {}

struct WatchlistTab: View {
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var viewModel = WatchlistViewModel()
  @State private var convertingItem: WatchlistItemResponse?
  @State private var removePromptItem: WatchlistItemResponse?

  var body: some View {
    List {
      if let errorMessage = viewModel.errorMessage {
        Section {
          Text(errorMessage)
            .foregroundStyle(AppTheme.Colors.danger)
        }
      }

      ForEach(viewModel.items, id: \.id) { item in
        WatchlistRow(
          item: item,
          onAddToPortfolio: { convertingItem = item }
        )
        .swipeActions {
          Button(role: .destructive) {
            Task { await viewModel.removeFromWatchlist(item) }
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(AppTheme.Colors.pageBackground(for: colorScheme))
    .overlay(alignment: .bottomTrailing) {
      Button {
        viewModel.isAddWatchlistPresented = true
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 32, height: 32)
          .background(AppTheme.Colors.tint(for: colorScheme))
          .clipShape(Circle())
          .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
      }
      .padding(.trailing, 16)
      .padding(.bottom, 24)
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
          let result = await viewModel.savePosition(from: item, draft: draft)
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
        Task { await viewModel.removeFromWatchlist(item) }
      }
      Button("Keep", role: .cancel) {
        removePromptItem = nil
      }
    } message: { item in
      Text("\(item.symbol) was added to your portfolio.")
    }
    .task { await viewModel.load() }
    .refreshable { await viewModel.load() }
  }
}

private struct WatchlistRow: View {
  let item: WatchlistItemResponse
  let onAddToPortfolio: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(item.symbol)
          .typography(.label, weight: .semibold)

        Spacer()

        Text(item.status.rawValue.capitalized)
          .typography(.nano, weight: .semibold)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.thinMaterial, in: Capsule())
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
