import SwiftUI
import StockPlanShared

struct CryptoWatchlistSection: View {
    @ObservedObject var viewModel: CryptoViewModel
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.watchlist.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.watchlist) { item in
                        NavigationLink(value: CryptoDetailRoute(symbol: item.symbol, name: item.name)) {
                            CryptoWatchlistRow(item: item)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: CGFloat(viewModel.watchlist.count) * 72 + 8)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Your crypto watchlist is empty")
                .font(.headline)
            Text("Track coins you're interested in without adding them to your portfolio.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onAdd) {
                Label("Add a coin", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal)
    }

    private func deleteItems(at offsets: IndexSet) {
        let ids = offsets.map { viewModel.watchlist[$0].id }
        Task {
            for id in ids {
                _ = await viewModel.removeFromWatchlist(itemId: id)
            }
        }
    }
}

private struct CryptoWatchlistRow: View {
    let item: CryptoWatchlistItemResponse

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(item.symbol.prefix(1)))
                        .foregroundStyle(.white)
                        .bold()
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                Text(item.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}
