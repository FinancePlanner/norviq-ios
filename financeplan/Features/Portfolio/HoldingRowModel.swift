import Foundation
import StockPlanShared

/// The figures on one holding row, finished (spec § 2.0 A3, A6).
///
/// - Every amount is in the holding's currency: the backend P/L's, else the
///   quote's, else none, which prints the number with " —" and never "$".
/// - A price of nil or 0 is "unavailable": no last price, no market value and
///   no gain or loss, because a missing price is not a total loss. The cost
///   is still known, so it is still shown.
struct HoldingRowModel: Equatable {
  let priceText: String?
  let marketValueText: String?
  /// "+1783,93 US$ (+184,8%)".
  let glText: String?
  let costText: String
  let priceUnavailable: Bool
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
    let currency = MoneyFormatter.resolvedCode(pnl?.currency) ?? MoneyFormatter.resolvedCode(quote?.currency)
    let cost = pnl?.costBasis ?? costBasis
    let costText = MoneyFormatter.string(cost, currencyCode: currency, locale: locale)

    guard let price = pnl?.currentPrice ?? quote?.currentPrice, price > 0 else {
      return HoldingRowModel(
        priceText: nil,
        marketValueText: nil,
        glText: nil,
        costText: costText,
        priceUnavailable: true,
        dayChangeText: nil,
        glDirection: nil,
        dayDirection: nil,
        currencyCode: currency
      )
    }

    let marketValue = pnl?.marketValue ?? (shares * price)
    let gainLoss = pnl?.unrealizedPnl ?? (marketValue - cost)
    // The backend sends percentages in points (184.76 is 184.76%).
    let gainLossFraction: Double? = pnl?.unrealizedPnlPercent.map { $0 / 100 }
      ?? (cost > 0 ? gainLoss / cost : nil)

    let dayChange = pnl?.dayChange ?? quote?.change.map { $0 * shares }
    let dayFraction: Double? = (pnl?.dayChangePercent ?? quote?.percentChange).map { $0 / 100 }

    return HoldingRowModel(
      priceText: MoneyFormatter.string(price, currencyCode: currency, locale: locale),
      marketValueText: MoneyFormatter.string(marketValue, currencyCode: currency, locale: locale),
      glText: withPercent(MoneyFormatter.signed(gainLoss, currencyCode: currency, locale: locale), gainLossFraction, locale),
      costText: costText,
      priceUnavailable: false,
      dayChangeText: dayChange.map {
        withPercent(MoneyFormatter.signed($0, currencyCode: currency, locale: locale), dayFraction, locale)
      },
      glDirection: gainLoss,
      dayDirection: dayChange,
      currencyCode: currency
    )
  }

  private static func withPercent(_ amount: String, _ fraction: Double?, _ locale: Locale) -> String {
    guard let fraction else { return amount }
    return "\(amount) (\(MoneyFormatter.percentSigned(fraction, locale: locale)))"
  }
}
