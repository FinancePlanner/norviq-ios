import Foundation
import StockPlanShared

/// The figures on one holding row, finished (spec § 2.0 A3, A6).
///
/// - Every amount is in the instrument's currency: the quote's, else the
///   P/L's label, else none, which prints the number with " —" and never "$".
///   The backend labels every P/L with the portfolio's base currency but
///   does not convert, so its figures are in the instrument's currency.
/// - A price of nil or 0 is "unavailable": no last price, no market value and
///   no gain or loss, because a missing price is not a total loss. The cost
///   is still known, so it is still shown.
struct HoldingRowModel: Equatable {
  let priceText: String?
  /// The value behind `marketValueText`; the hero sums these.
  let marketValue: Double?
  let marketValueText: String?
  /// "+1783,93 US$ (+184,8%)".
  let glText: String?
  let costText: String
  let priceUnavailable: Bool
  /// False until the P/L or a quote has arrived: not known is not unavailable.
  let isLoaded: Bool
  /// "+$12.40 (+0.5%)" for today, when a price and a day change exist.
  let dayChangeText: String?
  /// Sign of the gain or loss and of the day change, for their colour.
  let glDirection: Double?
  let dayDirection: Double?
  let currencyCode: String?

  static func make(
    pnl: PnlBySymbol?,
    quote: QuoteResponse?,
    shares: Double,
    costBasis: Double,
    locale: Locale
  ) -> HoldingRowModel {
    let currency = instrumentCurrency(pnl: pnl, quote: quote)
    let cost = pnl?.costBasis ?? costBasis
    let costText = MoneyFormatter.string(cost, currencyCode: currency, locale: locale)

    // The first positive price: a P/L price of 0 must not hide a live quote.
    let pnlPrice = pnl?.currentPrice.flatMap { $0 > 0 ? $0 : nil }
    let quotePrice = quote.flatMap { $0.currentPrice > 0 ? $0.currentPrice : nil }
    let isLoaded = pnl != nil || quote != nil

    guard let price = pnlPrice ?? quotePrice else {
      return HoldingRowModel(
        priceText: nil,
        marketValue: nil,
        marketValueText: nil,
        glText: nil,
        costText: costText,
        priceUnavailable: isLoaded,
        isLoaded: isLoaded,
        dayChangeText: nil,
        glDirection: nil,
        dayDirection: nil,
        currencyCode: currency
      )
    }

    // The backend's figures only hold when they were priced; otherwise the
    // value and G/L come from the live quote.
    let pricedPnl = pnlPrice == nil ? nil : pnl
    let marketValue = pricedPnl?.marketValue ?? (shares * price)
    let gainLoss = pricedPnl?.unrealizedPnl ?? (marketValue - cost)
    // The backend sends percentages in points (184.76 is 184.76%).
    let gainLossFraction: Double? = pricedPnl?.unrealizedPnlPercent.map { $0 / 100 }
      ?? (cost > 0 ? gainLoss / cost : nil)

    // An unpriced P/L's day change is not about this price either.
    let dayChange = pricedPnl?.dayChange ?? quote?.change.map { $0 * shares }
    let dayFraction: Double? = (pricedPnl?.dayChangePercent ?? quote?.percentChange).map { $0 / 100 }

    return HoldingRowModel(
      priceText: MoneyFormatter.string(price, currencyCode: currency, locale: locale),
      marketValue: marketValue,
      marketValueText: MoneyFormatter.string(marketValue, currencyCode: currency, locale: locale),
      glText: withPercent(MoneyFormatter.signed(gainLoss, currencyCode: currency, locale: locale), gainLossFraction, locale),
      costText: costText,
      priceUnavailable: false,
      isLoaded: true,
      dayChangeText: dayChange.map {
        withPercent(MoneyFormatter.signed($0, currencyCode: currency, locale: locale), dayFraction, locale)
      },
      glDirection: gainLoss,
      dayDirection: dayChange,
      currencyCode: currency
    )
  }

  /// The quote names the instrument's listing currency; the P/L's label is
  /// the portfolio base and only a fallback.
  static func instrumentCurrency(pnl: PnlBySymbol?, quote: QuoteResponse?) -> String? {
    MoneyFormatter.resolvedCode(quote?.currency) ?? MoneyFormatter.resolvedCode(pnl?.currency)
  }

  private static func withPercent(_ amount: String, _ fraction: Double?, _ locale: Locale) -> String {
    guard let fraction else { return amount }
    return "\(amount) (\(MoneyFormatter.percentSigned(fraction, locale: locale)))"
  }
}
