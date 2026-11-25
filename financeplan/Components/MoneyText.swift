import SwiftUI

/// An amount of money, in the currency the data gave (spec § 5.4).
///
/// A nil or non-finite value shows an em dash, read as "Not available". A
/// missing currency prints the number followed by " —", never a dollar sign.
struct MoneyText: View {
  let value: Double?
  let currencyCode: String?
  let signed: Bool

  init(_ value: Double?, currencyCode: String?, signed: Bool = false) {
    self.value = value
    self.currencyCode = currencyCode
    self.signed = signed
  }

  /// The string the view shows. Pure, so tests need no rendering.
  nonisolated static func text(
    _ value: Double?,
    currencyCode: String?,
    signed: Bool = false,
    locale: Locale = MoneyFormatter.defaultLocale
  ) -> String {
    guard let value, value.isFinite else { return "\u{2014}" }
    return signed
      ? MoneyFormatter.signed(value, currencyCode: currencyCode, locale: locale)
      : MoneyFormatter.string(value, currencyCode: currencyCode, locale: locale)
  }

  private var isAvailable: Bool {
    value?.isFinite == true
  }

  var body: some View {
    let shown = Self.text(value, currencyCode: currencyCode, signed: signed)
    Text(verbatim: shown)
      .typography(.numeric)
      .monospacedDigit()
      .accessibilityLabel(isAvailable ? shown : String(localized: "Not available"))
  }
}
