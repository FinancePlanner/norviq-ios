import Combine
import StockPlanShared
import SwiftUI

@MainActor
struct PortfolioScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var viewModel = PortfolioViewModel()
  @State private var isAddPositionPresented = false

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      Group {
        if viewModel.isLoading {
          ProgressView("Loading portfolio...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
          VStack(spacing: 12) {
            Text(error)
              .foregroundStyle(AppTheme.Colors.danger)
              .typography(.small)

            Button("Retry") {
              Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          ScrollView {
            VStack(spacing: 16) {
              GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                  Text("Invested capital")
                    .typography(.small, weight: .semibold)

                  HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(viewModel.totalValue.currency)
                      .typography(.hero, weight: .bold)
                    Text("\(viewModel.stocks.count) positions")
                      .typography(.small)
                      .foregroundStyle(.secondary)
                  }

                  HStack {
                    PortfolioMetricPill(
                      title: "Shares",
                      value: viewModel.totalShares.formatted(.number.precision(.fractionLength(0...2))),
                      tint: AppTheme.Colors.secondaryTint(for: colorScheme)
                    )
                    PortfolioMetricPill(
                      title: "Avg/position",
                      value: viewModel.averagePositionValue.currency,
                      tint: AppTheme.Colors.tint(for: colorScheme)
                    )
                  }
                }
              }

              if viewModel.stocks.isEmpty {
                GlassCard {
                  Text("No positions yet. Add your first stock to start building the portfolio view.")
                    .typography(.small)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
              } else {
                ForEach(viewModel.stocks, id: \.id) { stock in
                  NavigationLink {
                    StockDetailScreen(stockId: stock.id, initialSymbol: stock.symbol)
                  } label: {
                    PortfolioRow(stock: stock)
                  }
                  .buttonStyle(.plain)
                  .contextMenu {
                    Button("Edit", systemImage: "pencil") {
                      viewModel.beginEdit(stock)
                    }

                    Button("Delete", systemImage: "trash", role: .destructive) {
                      Task { await viewModel.delete(id: stock.id) }
                    }
                  }
                }
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
          }
        }
      }
      .background(AppTheme.Colors.pageBackground(for: colorScheme))
      .task { await viewModel.load() }
      .refreshable { await viewModel.load() }
      .sheet(
        isPresented: Binding<Bool>(
          get: { viewModel.editingStock != nil },
          set: { if !$0 { viewModel.editingStock = nil } }
        )
      ) {
        if let stock = viewModel.editingStock {
          EditStockSheet(
            stock: stock,
            isSaving: viewModel.isSaving,
            onCancel: { viewModel.editingStock = nil },
            onSave: { updated in
              Task { await viewModel.saveEdit(updated) }
            }
          )
        }
      }

      PortfolioAddButton {
        isAddPositionPresented = true
      }
      .accessibilityIdentifier("portfolio.fab")
      .padding(.trailing, 16)
      .padding(.bottom, 24)
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
  }
}

private struct PortfolioRow: View {
  let stock: StockResponse

  var body: some View {
    GlassCard(cornerRadius: 22) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 4) {
            Text(stock.symbol)
              .typography(.headline, weight: .bold)
              .foregroundStyle(.primary)

            Text("Purchased \(stock.buyDate)")
              .typography(.nano)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Text((stock.shares * stock.buyPrice).currency)
            .typography(.label, weight: .semibold)
            .foregroundStyle(.primary)
        }

        HStack(spacing: 8) {
          PortfolioMetricPill(
            title: "Qty",
            value: stock.shares.formatted(.number.precision(.fractionLength(0...2))),
            tint: .indigo
          )
          PortfolioMetricPill(
            title: "Avg",
            value: stock.buyPrice.currency,
            tint: Color.indigo.opacity(0.18)
          )
        }

        if let notes = stock.notes, !notes.isEmpty {
          Text(notes)
            .typography(.nano)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
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
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

private struct PortfolioAddButton: View {
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: action) {
      Image(systemName: "plus")
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 56, height: 56)
        .background(AppTheme.Colors.tint(for: colorScheme))
        .clipShape(Circle())
        .shadow(
          color: AppTheme.Colors.tint(for: colorScheme).opacity(0.35),
          radius: 16,
          y: 10
        )
    }
    .buttonStyle(.plain)
  }
}

private struct EditStockSheet: View {
  let stock: StockResponse
  let isSaving: Bool
  let onCancel: () -> Void
  let onSave: (StockResponse) -> Void

  @State private var shares: Double
  @State private var buyPrice: Double
  @State private var notes: String

  init(
    stock: StockResponse,
    isSaving: Bool,
    onCancel: @escaping () -> Void,
    onSave: @escaping (StockResponse) -> Void
  ) {
    self.stock = stock
    self.isSaving = isSaving
    self.onCancel = onCancel
    self.onSave = onSave
    _shares = State(initialValue: stock.shares)
    _buyPrice = State(initialValue: stock.buyPrice)
    _notes = State(initialValue: stock.notes ?? "")
  }

  var body: some View {
    NavigationStack {
      Form {
        HStack {
          Text("Symbol")
          Spacer()
          Text(stock.symbol)
            .foregroundStyle(.secondary)
        }
        TextField("Shares", value: $shares, format: .number)
        TextField("Buy price", value: $buyPrice, format: .number)
        TextField("Notes", text: $notes)
      }
      .navigationTitle("Edit Stock")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onCancel)
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(isSaving ? "Saving..." : "Save") {
            onSave(
              StockResponse(
                id: stock.id,
                symbol: stock.symbol,
                shares: shares,
                buyPrice: buyPrice,
                buyDate: stock.buyDate,
                notes: notes.isEmpty ? nil : notes
              )
            )
          }
          .disabled(isSaving)
        }
      }
    }
  }
}
