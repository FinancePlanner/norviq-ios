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

  private var hasLiveMark: Bool {
    displayPrice != nil
  }

  private var costBasis: Double {
    pnl?.costBasis ?? (stock.shares * stock.buyPrice)
  }

  private var marketValue: Double {
    if let value = pnl?.marketValue, hasLiveMark {
      return value
    }
    if let price = displayPrice {
      return stock.shares * price
    }
    return costBasis
  }

  private var todayChange: Double? {
    pnl?.dayChange ?? liveQuote?.change.map { $0 * stock.shares }
  }

  private var todayChangePercent: Double? {
    pnl?.dayChangePercent ?? liveQuote?.percentChange
  }

  /// Total G/L needs a live price; cost-basis fallback would report a meaningless 0.
  private var totalGainLoss: Double? {
    guard hasLiveMark else { return nil }
    if let pnl {
      return pnl.unrealizedPnl
    }
    return marketValue - costBasis
  }

  private var totalGainLossPercent: Double? {
    guard hasLiveMark else { return nil }
    if let pct = pnl?.unrealizedPnlPercent {
      return pct
    }
    guard costBasis > 0 else { return nil }
    return ((marketValue - costBasis) / costBasis) * 100
  }

  private var rowSubtitle: String? {
    HoldingRowPresentation.displaySubtitle(
      notes: stock.notes,
      fallback: nil
    )
  }

  private var valueCaption: String {
    hasLiveMark ? "Market value" : "Cost basis"
  }

  private var accessibilitySummary: String {
    var parts = ["\(stock.symbol), \(marketValue.currency)"]
    if let todayChange, let todayChangePercent {
      parts.append(
        "day \(StockMetricFormatter.signedCurrencyText(todayChange)) \(String(format: "%+.2f%%", todayChangePercent))"
      )
    }
    if let totalGainLoss {
      parts.append("total gain loss \(StockMetricFormatter.signedCurrencyText(totalGainLoss))")
    }
    parts.append("\(stock.shares.formatted(.number.precision(.fractionLength(0...2)))) shares")
    return parts.joined(separator: ", ")
  }

  var body: some View {
    GlassCard(cornerRadius: AppTheme.Radius.hero) {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
          VStack(alignment: .leading, spacing: 4) {
            Text(stock.symbol)
              .font(.headline)
              .foregroundStyle(.primary)

            Text(sharesLine)
              .font(.caption)
              .foregroundStyle(.secondary)

            if let rowSubtitle {
              Text(rowSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            if let targetAlert {
              Label(targetAlert.targetPrice.currency, systemImage: "bell.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
                .lineLimit(1)
            }
          }

          Spacer(minLength: 8)

          VStack(alignment: .trailing, spacing: 4) {
            Text(marketValue.currency)
              .font(.headline)
              .foregroundStyle(.primary)
              .contentTransition(.numericText())
              .monospacedDigit()

            Text(valueCaption)
              .font(.caption2)
              .foregroundStyle(.tertiary)

            QuoteChangeLabel(
              absoluteChange: todayChange,
              percentChange: todayChangePercent,
              style: .compact
            )
          }
        }

        HoldingMetricsStrip(
          lastPrice: displayPrice,
          costBasis: costBasis,
          totalGainLoss: totalGainLoss,
          totalGainLossPercent: totalGainLossPercent,
          weightPercent: pnl?.weightPercent
        )
      }
      .padding(.vertical, 4)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilitySummary)
  }

  private var sharesLine: String {
    let shares = stock.shares.formatted(.number.precision(.fractionLength(0...2)))
    return "\(shares) shares"
  }
}

// MARK: - Shared presentation helpers

enum HoldingRowPresentation {
  /// Hide broker-import noise (e.g. IBKR account ids like U16602470) from row subtitles.
  static func displaySubtitle(notes: String?, fallback: String?) -> String? {
    if let notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
      if isBrokerAccountId(notes) {
        return fallback
      }
      return notes
    }
    return fallback
  }

  static func isBrokerAccountId(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    // IBKR-style account numbers, optionally with prefix/suffix noise
    return trimmed.range(of: #"^U\d{5,10}$"#, options: .regularExpression) != nil
  }
}

// MARK: - Quote change label

struct QuoteChangeLabel: View {
  enum Style {
    case compact
    case detailed
  }

  let absoluteChange: Double?
  let percentChange: Double?
  /// When true, `percentChange` is already 0–100 point scale (backend PnL / some quote fields).
  var percentIsPointScale: Bool = true
  var style: Style = .compact

  private var tone: Color {
    guard let absoluteChange else { return .secondary }
    if absoluteChange > 0 { return AppTheme.Colors.success }
    if absoluteChange < 0 { return AppTheme.Colors.danger }
    return .secondary
  }

  var body: some View {
    if absoluteChange == nil && percentChange == nil {
      EmptyView()
    } else {
      Text(labelText)
        .font(style == .compact ? .caption.weight(.semibold) : .subheadline.weight(.medium))
        .foregroundStyle(tone)
        .monospacedDigit()
        .contentTransition(.numericText())
    }
  }

  private var labelText: String {
    var parts: [String] = []
    if let absoluteChange {
      parts.append(StockMetricFormatter.signedCurrencyText(absoluteChange))
    }
    if let percentChange {
      let display = percentIsPointScale ? percentChange : percentChange * 100
      parts.append(String(format: "(%+.2f%%)", display))
    }
    return parts.joined(separator: " ")
  }
}

// MARK: - Shared metrics strip

struct HoldingMetricsStrip: View {
  let lastPrice: Double?
  let costBasis: Double?
  let totalGainLoss: Double?
  let totalGainLossPercent: Double?
  let weightPercent: Double?

  private var items: [MetricItem] {
    var result: [MetricItem] = []
    if let lastPrice {
      result.append(MetricItem(title: "Last", value: lastPrice.currency, color: .primary))
    }
    if let costBasis {
      result.append(MetricItem(title: "Cost", value: costBasis.currency, color: .primary))
    }
    if let totalGainLoss {
      result.append(
        MetricItem(
          title: "Total G/L",
          value: totalText(totalGainLoss, percent: totalGainLossPercent),
          color: totalGainLoss >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger
        )
      )
    }
    if let weightPercent, weightPercent > 0 {
      result.append(
        MetricItem(
          title: "% Acct",
          value: String(format: "%.1f%%", weightPercent),
          color: .primary
        )
      )
    }
    return result
  }

  var body: some View {
    if items.isEmpty {
      EmptyView()
    } else {
      HStack(alignment: .top, spacing: 10) {
        ForEach(items) { item in
          VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
              .font(.caption2)
              .foregroundStyle(.secondary)
            Text(item.value)
              .font(.caption.weight(.semibold))
              .monospacedDigit()
              .foregroundStyle(item.color)
              .contentTransition(.numericText())
              .lineLimit(1)
              .minimumScaleFactor(0.75)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(.top, 2)
      .accessibilityElement(children: .combine)
    }
  }

  private func totalText(_ gainLoss: Double, percent: Double?) -> String {
    var text = StockMetricFormatter.signedCurrencyText(gainLoss)
    if let percent {
      text += " (\(String(format: "%+.1f%%", percent)))"
    }
    return text
  }

  private struct MetricItem: Identifiable {
    var id: String { title }
    let title: String
    let value: String
    let color: Color
  }
}
