import Foundation
import StockPlanShared

/// Display formatting for terminal positions. Amounts use the API's `currency`;
/// the app has no global base currency.
enum TerminalFormat {
  /// Compact for big amounts ($10.00T, $1.0M), whole units below a million.
  static func money(_ value: Double, currency: String, locale: Locale = .current) -> String {
    StockMetricFormatter.compactStatementCurrency(value, code: currency, locale: locale)
  }

  /// A per-share price, always two decimals.
  static func price(_ value: Double, currency: String, locale: Locale = .current) -> String {
    StockMetricFormatter.currencyText(value, code: currency, decimals: 2, locale: locale)
  }

  /// Shares, optionally rounded down to whole shares (display only, never stored).
  static func shares(_ value: Double, roundDown: Bool, locale: Locale = .current) -> String {
    if roundDown {
      return TerminalMath.wholeShares(value).formatted(.number.precision(.fractionLength(0)).locale(locale))
    }
    return value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
  }

  /// A share count such as 10.6B.
  static func count(_ value: Double, locale: Locale = .current) -> String {
    StockMetricFormatter.compactNumber(value, locale: locale)
  }

  static func progress(_ fraction: Double, locale: Locale = .current) -> String {
    fraction.formatted(.percent.precision(.fractionLength(0...2)).locale(locale))
  }
}

/// Contract copy. Computed so a language switch takes effect without a relaunch.
enum TerminalCopy {
  static var title: String {
    String(localized: "Terminal position sizing")
  }

  static var subtitle: String {
    String(localized: "Decide the future market cap and share count. Norviq tells you how many shares that target is.")
  }

  static var disclaimer: String {
    String(localized: "Terminal prices are your assumptions, not forecasts. Not financial advice.")
  }
}
