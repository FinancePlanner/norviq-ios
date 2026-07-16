import StockPlanShared
import SwiftUI

// MARK: - Positions Section

struct PortfolioPositionsSection: View {
  let stocks: [SDPortfolioStock]
  let liveQuotes: [String: QuoteResponse]
  let targetAlertProvider: (String) -> TargetResponse?
  let onAddPosition: () -> Void
  let onEditStock: (StockResponse) -> Void
  let onDeleteStock: (String) -> Void
  let onPresentTargetAlert: (SDPortfolioStock) -> Void
  let onLoadMore: (() -> Void)?

  var body: some View {
    Group {
      if stocks.isEmpty {
        ContentUnavailableView {
          Label("Nothing under watch yet", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
          Text("Add your first holding, or change your filter.")
        } actions: {
          Button("Add Position", action: onAddPosition)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("portfolio.addPositionButton")
        }
        .padding(.vertical, 24)
      } else {
        ForEach(stocks) { stock in
          PortfolioStockLinkRow(
            stock: stock,
            targetAlert: targetAlertProvider(stock.symbol),
            liveQuote: liveQuotes[stock.symbol.uppercased()],
            onEdit: onEditStock,
            onDelete: onDeleteStock,
            onPresentTargetAlert: onPresentTargetAlert
          )
          .transition(.opacity.combined(with: .scale(scale: 0.98)))
          .onAppear {
            if let last = stocks.last, last.id == stock.id {
              onLoadMore?()
            }
          }
        }
      }
    }
    .appAnimation(AppMotion.structural, value: stocks.map(\.id))
  }
}

// MARK: - Stock Link Row

struct PortfolioStockLinkRow: View {
  let stock: SDPortfolioStock
  let targetAlert: TargetResponse?
  let liveQuote: QuoteResponse?
  let onEdit: (StockResponse) -> Void
  let onDelete: (String) -> Void
  let onPresentTargetAlert: (SDPortfolioStock) -> Void

  private var editableStock: StockResponse {
    StockResponse.editableDraft(from: stock)
  }

  var body: some View {
    NavigationLink {
      StockDetailScreen(stockId: stock.id, initialSymbol: stock.symbol)
    } label: {
      PortfolioRow(stock: stock, targetAlert: targetAlert, liveQuote: liveQuote)
        .accessibilityIdentifier("portfolio.stockRow.\(stock.symbol)")
    }
    .buttonStyle(PressableStyle())
    .contextMenu {
      Button(
        targetAlert == nil ? "Add price alert" : "Edit price alert",
        systemImage: targetAlert == nil ? "bell.badge" : "bell.fill"
      ) {
        onPresentTargetAlert(stock)
      }

      Button("Edit", systemImage: "pencil") {
        onEdit(editableStock)
      }

      Button("Delete", systemImage: "trash", role: .destructive) {
        onDelete(stock.id)
      }
    }
  }
}

// MARK: - Row Card

struct PortfolioRow: View {
  let stock: SDPortfolioStock
  let targetAlert: TargetResponse?
  let liveQuote: QuoteResponse?

  private var displayPrice: Double {
    liveQuote?.currentPrice ?? stock.buyPrice
  }

  private var marketValue: Double {
    stock.shares * displayPrice
  }

  private var trendText: String {
    guard let q = liveQuote else { return "No trend" }
    let ch = q.change ?? 0
    let pct = q.percentChange ?? 0
    let sign = ch >= 0 ? "+" : ""
    let pctSign = pct >= 0 ? "+" : ""
    return "\(sign)\(ch.currency) (\(pctSign)\(String(format: "%.2f", pct))%)"
  }

  private var trendColor: Color {
    guard let q = liveQuote else { return .secondary }
    return (q.change ?? 0) >= 0 ? .green : .red
  }

  var body: some View {
    GlassCard(cornerRadius: AppTheme.Radius.hero) {
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
          Text(marketValue.currency)
            .font(.headline)
            .foregroundStyle(.primary)

          Text(trendText)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(trendColor)
        }
      }
      .padding(.vertical, 4)
    }
  }
}
