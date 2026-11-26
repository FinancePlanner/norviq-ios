import StockPlanShared
import SwiftUI

// MARK: - Positions Section

struct PortfolioPositionsSection: View {
  let stocks: [SDPortfolioStock]
  let liveQuotes: [String: QuoteResponse]
  let pnlProvider: (String) -> PnlBySymbol?
  let targetAlertProvider: (String) -> TargetResponse?
  /// Defaults to "no reading" so callers that do not supply sentiment keep
  /// compiling and simply render the absence treatment.
  var sentimentProvider: (String) -> SymbolSentiment? = { _ in nil }
  let onAddPosition: () -> Void
  let onImportFromBroker: () -> Void
  let onEditStock: (StockResponse) -> Void
  let onDeleteStock: (String) -> Void
  let onPresentTargetAlert: (SDPortfolioStock) -> Void
  let onLoadMore: (() -> Void)?

  var body: some View {
    Group {
      if stocks.isEmpty {
        ContentUnavailableView {
          Label("No positions yet", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
          Text("Add your first holding, or change your filter.")
        } actions: {
          Button("Add Position", action: onAddPosition)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("portfolio.addPositionButton")
            .guidedTarget(.holdingAdd, in: .portfolio)
          Button("Import from broker", action: onImportFromBroker)
            .buttonStyle(.bordered)
            .accessibilityIdentifier("portfolio.importFromBrokerButton")
        }
        .padding(.vertical, 24)
      } else {
        ForEach(stocks) { stock in
          PortfolioStockLinkRow(
            stock: stock,
            targetAlert: targetAlertProvider(stock.symbol),
            liveQuote: liveQuotes[stock.symbol.uppercased()],
            pnl: pnlProvider(stock.symbol),
            sentiment: sentimentProvider(stock.symbol),
            onEdit: onEditStock,
            onDelete: onDeleteStock,
            onPresentTargetAlert: onPresentTargetAlert
          )
          .transition(.opacity.combined(with: .scale(scale: 0.98)))
          .onAppear {
            // Rows live in the parent's LazyVStack, so this only runs when
            // the row actually scrolls into view.
            if PortfolioPaginationSentinel.shouldLoadMore(appearing: stock.id, lastID: stocks.last?.id) {
              onLoadMore?()
            }
          }
        }
      }
    }
    .appAnimation(AppMotion.structural, value: orderFingerprint)
  }

  /// Hash of the row order; changes whenever rows are added, removed or
  /// re-sorted without allocating an id array on every body pass.
  private var orderFingerprint: Int {
    var hasher = Hasher()
    for stock in stocks {
      hasher.combine(stock.id)
    }
    return hasher.finalize()
  }
}

// MARK: - Pagination sentinel

/// Decides whether a row appearing should request the next page: only the
/// last row of the currently loaded list is a sentinel.
nonisolated enum PortfolioPaginationSentinel {
  static func shouldLoadMore<ID: Equatable>(appearing id: ID, lastID: ID?) -> Bool {
    guard let lastID else { return false }
    return id == lastID
  }
}

// MARK: - Stock Link Row

/// Value pushed by a position row; resolved to StockDetailScreen by the
/// `navigationDestination(for:)` registered in PortfolioRoot, so the detail
/// screen is not constructed for every visible row.
struct PortfolioStockRoute: Hashable {
  let stockID: String
  let symbol: String
}

struct PortfolioStockLinkRow: View {
  let stock: SDPortfolioStock
  let targetAlert: TargetResponse?
  let liveQuote: QuoteResponse?
  let pnl: PnlBySymbol?
  var sentiment: SymbolSentiment?
  let onEdit: (StockResponse) -> Void
  let onDelete: (String) -> Void
  let onPresentTargetAlert: (SDPortfolioStock) -> Void

  private var editableStock: StockResponse {
    StockResponse.editableDraft(from: stock)
  }

  var body: some View {
    NavigationLink(value: PortfolioStockRoute(stockID: stock.id, symbol: stock.symbol)) {
      PortfolioRow(stock: stock, targetAlert: targetAlert, liveQuote: liveQuote, pnl: pnl, sentiment: sentiment)
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
  var sentiment: SymbolSentiment?

  /// Every amount on the row, in the holding's currency (spec § 2.0 A3, A6).
  private var model: HoldingRowModel {
    HoldingRowModel.make(
      pnl: pnl,
      quote: liveQuote,
      shares: stock.shares,
      costBasis: stock.shares * stock.buyPrice,
      locale: MoneyFormatter.defaultLocale
    )
  }

  private var rowSubtitle: String? {
    HoldingRowPresentation.displaySubtitle(
      notes: stock.notes,
      fallback: nil
    )
  }

  private var priceUnavailableText: String {
    String(localized: "Price unavailable")
  }

  private func accessibilitySummary(_ model: HoldingRowModel) -> String {
    var parts = [stock.symbol]
    if let marketValueText = model.marketValueText {
      parts.append(marketValueText)
    } else if model.priceUnavailable {
      parts.append(priceUnavailableText)
    }
    if let dayChangeText = model.dayChangeText {
      parts.append(String(localized: "today \(dayChangeText)"))
    }
    if let glText = model.glText {
      parts.append(String(localized: "total gain or loss \(glText)"))
    }
    parts.append(String(localized: "cost \(model.costText)"))
    parts.append(sharesLine)
    return parts.joined(separator: ", ")
  }

  var body: some View {
    let model = model
    return GlassCard(cornerRadius: AppTheme.Radius.hero) {
      VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
              Text(stock.symbol)
                .font(.headline)
                .foregroundStyle(.primary)
              RetailSentimentBadge(display: RetailSentimentDisplay(sentiment), showsScore: false)
            }

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
              Label(
                MoneyFormatter.string(targetAlert.targetPrice, currencyCode: model.currencyCode),
                systemImage: "bell.fill"
              )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
                .lineLimit(1)
            }
          }

          Spacer(minLength: 8)

          VStack(alignment: .trailing, spacing: 4) {
            if let marketValueText = model.marketValueText {
              // Not animated: a changing value in a list is never animated.
              Text(verbatim: marketValueText)
                .font(.headline)
                .foregroundStyle(.primary)
                .monospacedDigit()

              Text("Market value")
                .font(.caption2)
                .foregroundStyle(.tertiary)

              if let dayChangeText = model.dayChangeText {
                Text(verbatim: dayChangeText)
                  .font(.caption.weight(.semibold))
                  .monospacedDigit()
                  .foregroundStyle(Self.tone(model.dayDirection))
              }
            } else if model.priceUnavailable {
              // A missing price is not a loss: say so, and show no value.
              Text(verbatim: priceUnavailableText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }
        }

        HoldingMetricsStrip(
          priceText: model.priceText,
          costText: model.costText,
          glText: model.glText,
          glTone: Self.tone(model.glDirection),
          weightPercent: model.priceUnavailable ? nil : pnl?.weightPercent
        )
      }
      .padding(.vertical, 4)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilitySummary(model))
  }

  /// Gain and loss colours speak only about money direction; zero is flat.
  static func tone(_ direction: Double?) -> Color {
    guard let direction else { return .secondary }
    if direction > 0 { return AppTheme.Colors.gain }
    if direction < 0 { return AppTheme.Colors.loss }
    return AppTheme.Colors.flat
  }

  private var sharesLine: String {
    let shares = stock.shares.formatted(
      .number.precision(.fractionLength(0...2)).locale(MoneyFormatter.defaultLocale)
    )
    return String(localized: "\(shares) shares")
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

// MARK: - Shared metrics strip

struct HoldingMetricsStrip: View {
  let priceText: String?
  let costText: String?
  let glText: String?
  let glTone: Color
  let weightPercent: Double?

  private var items: [MetricItem] {
    var result: [MetricItem] = []
    if let priceText {
      result.append(MetricItem(title: String(localized: "Last"), value: priceText, color: .primary))
    }
    if let costText {
      result.append(MetricItem(title: String(localized: "Cost"), value: costText, color: .primary))
    }
    if let glText {
      result.append(MetricItem(title: String(localized: "Total G/L"), value: glText, color: glTone))
    }
    if let weightPercent, weightPercent > 0 {
      result.append(
        MetricItem(
          title: String(localized: "% Acct"),
          // Points from the backend; the percent formatter takes a fraction.
          value: (weightPercent / 100).formatted(
            .percent.precision(.fractionLength(1)).locale(MoneyFormatter.defaultLocale)
          ),
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

  private struct MetricItem: Identifiable {
    var id: String { title }
    let title: String
    let value: String
    let color: Color
  }
}
