import StockPlanShared
import SwiftUI

// MARK: - Positions Section

struct PortfolioPositionsSection: View {
  let stocks: [SDPortfolioStock]
  let liveQuotes: [String: QuoteResponse]
  let pnlProvider: (String) -> PnlBySymbol?
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
            pnl: pnlProvider(stock.symbol),
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
  let pnl: PnlBySymbol?
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
      PortfolioRow(stock: stock, targetAlert: targetAlert, liveQuote: liveQuote, pnl: pnl)
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
  let pnl: PnlBySymbol?

  private var displayPrice: Double? {
    pnl?.currentPrice ?? liveQuote?.currentPrice
  }

  private var costBasis: Double {
    pnl?.costBasis ?? (stock.shares * stock.buyPrice)
  }

  private var marketValue: Double {
    pnl?.marketValue ?? (stock.shares * (displayPrice ?? stock.buyPrice))
  }

  private var todayChange: Double? {
    pnl?.dayChange ?? liveQuote?.change.map { $0 * stock.shares }
  }

  private var todayChangePercent: Double? {
    pnl?.dayChangePercent ?? liveQuote?.percentChange
  }

  // Total G/L needs a live price; the backend's cost-basis fallback would
  // report a meaningless 0 when quotes are down.
  private var totalGainLoss: Double? {
    guard let pnl, pnl.currentPrice != nil else { return nil }
    return pnl.unrealizedPnl
  }

  private var trendText: String {
    guard let change = todayChange else { return "No trend" }
    let pct = todayChangePercent ?? 0
    return "\(StockMetricFormatter.signedCurrencyText(change)) (\(String(format: "%+.2f%%", pct)))"
  }

  private var trendColor: Color {
    guard let change = todayChange else { return .secondary }
    return change >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger
  }

  var body: some View {
    GlassCard(cornerRadius: AppTheme.Radius.hero) {
      VStack(alignment: .leading, spacing: 12) {
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
              .contentTransition(.numericText())

            Text(trendText)
              .font(.subheadline.weight(.medium))
              .foregroundStyle(trendColor)
              .contentTransition(.numericText())
          }
        }

        PortfolioRowMetricsStrip(
          lastPrice: displayPrice,
          costBasis: costBasis,
          totalGainLoss: totalGainLoss,
          totalGainLossPercent: pnl?.unrealizedPnlPercent,
          weightPercent: pnl?.weightPercent
        )
      }
      .padding(.vertical, 4)
    }
  }
}

// MARK: - Row Metrics Strip

private struct PortfolioRowMetricsStrip: View {
  let lastPrice: Double?
  let costBasis: Double
  let totalGainLoss: Double?
  let totalGainLossPercent: Double?
  let weightPercent: Double?

  // Backend percent fields are 0–100 point scale; StockMetricFormatter.percentText
  // expects fractions, so format point-scale values directly.
  private var totalText: String {
    guard let totalGainLoss else { return "—" }
    var text = StockMetricFormatter.signedCurrencyText(totalGainLoss)
    if let totalGainLossPercent {
      text += " (\(String(format: "%+.2f%%", totalGainLossPercent)))"
    }
    return text
  }

  private var totalColor: Color {
    guard let totalGainLoss else { return .primary }
    return totalGainLoss >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      metric("Last", lastPrice.map(\.currency) ?? "—")
      metric("Cost", costBasis.currency)
      metric("Total G/L", totalText, color: totalColor)
      metric("% Acct", weightPercent.map { String(format: "%.1f%%", $0) } ?? "—")
    }
  }

  private func metric(_ title: String, _ value: String, color: Color = .primary) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.caption.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(color)
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
