import Combine
import StockPlanShared
import SwiftUI

@MainActor
struct PortfolioScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject private var viewModel: PortfolioViewModel
  @State private var isAddPositionPresented = false
  @State private var destructiveFeedbackTrigger = 0

  var body: some View {
    Group {
      if viewModel.isLoading {
        ProgressView("Loading portfolio...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = viewModel.errorMessage {
        ContentUnavailableView {
          Label("Unable to Load Portfolio", systemImage: "exclamationmark.triangle")
        } description: {
          Text(error)
        } actions: {
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
                Text("Portfolio value")
                  .typography(.small, weight: .semibold)
                  .foregroundStyle(.secondary)

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
                    title: "Avg / position",
                    value: viewModel.averagePositionValue.currency,
                    tint: AppTheme.Colors.tint(for: colorScheme)
                  )
                }
              }
            }

            if viewModel.stocks.isEmpty {
              ContentUnavailableView {
                Label("No Positions Yet", systemImage: "chart.line.uptrend.xyaxis")
              } description: {
                Text("Add your first holding to start tracking cost basis, notes, and valuation work.")
              } actions: {
                Button("Add Position") {
                  isAddPositionPresented = true
                }
                .buttonStyle(.borderedProminent)
              }
              .padding(.vertical, 24)
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
                    destructiveFeedbackTrigger += 1
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
    .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
    .refreshable { await viewModel.load() }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          isAddPositionPresented = true
        } label: {
          Image(systemName: "plus")
        }
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
    .appSensoryFeedback(destructive: destructiveFeedbackTrigger)
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

