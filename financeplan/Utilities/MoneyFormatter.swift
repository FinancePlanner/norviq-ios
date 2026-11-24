import Foundation

/// The one way to print money (spec § 5.4).
///
/// - The currency comes from the data, never from the device. There is no USD
///   default: a missing or blank code prints the number followed by " —", so a
///   gap in the data is visible instead of being dressed up as dollars.
/// - The locale only decides separators and where the symbol goes. It defaults
///   to the app language (en → en_US, pt-PT → pt_PT), not the phone's region:
///   an English-language phone set to Portugal would otherwise print a third
///   format ("€48 432,05") that neither the web nor the fixtures know.
/// - Output is normalised so every platform matches the shared golden
///   fixtures (`docs/design-system-fixtures/money.json`).
///
/// Call sites never build money strings themselves, and pass the finished
/// string to `Text`: `Text(_, format:)` and `.formatted()` resolve the locale
/// differently, which is how "$0.00 of US$0,00" ended up on one line.
nonisolated enum MoneyFormatter {
  /// NBSP + em dash, appended in place of a currency the data did not give.
  static let missingCurrencySuffix = "\u{00A0}\u{2014}"

  /// The locale implied by the app language the user picked in Settings.
  static var defaultLocale: Locale {
    locale(for: AppLanguage.stored)
  }

  static func locale(for language: AppLanguage) -> Locale {
    switch language {
    case .english: Locale(identifier: "en_US")
    case .portuguesePortugal: Locale(identifier: "pt_PT")
    }
  }

  /// "€124,580.42", "48 432,05 US$". Negative values carry U+2212.
  static func string(_ value: Double, currencyCode: String?, locale: Locale = defaultLocale) -> String {
    let value = cleanZero(value)
    guard let code = resolvedCode(currencyCode) else {
      return normalise(value.formatted(plainNumber.locale(locale))) + missingCurrencySuffix
    }
    return normalise(value.formatted(.currency(code: code).locale(locale)))
  }

  /// A delta: "+€13,480.10", "−168,78 US$", and no sign on zero.
  static func signed(_ value: Double, currencyCode: String?, locale: Locale = defaultLocale) -> String {
    let value = cleanZero(value)
    guard let code = resolvedCode(currencyCode) else {
      let number = value.formatted(
        plainNumber.sign(strategy: .always(includingZero: false)).locale(locale)
      )
      return normalise(number) + missingCurrencySuffix
    }
    return normalise(
      value.formatted(.currency(code: code).sign(strategy: .always(showZero: false)).locale(locale))
    )
  }

  /// A fraction as a signed percent with one decimal: 0.0321 → "+3.2%".
  static func percentSigned(_ fraction: Double, locale: Locale = defaultLocale) -> String {
    normalise(
      cleanZero(fraction).formatted(
        .percent.precision(.fractionLength(1)).sign(strategy: .always(includingZero: false)).locale(locale)
      )
    )
  }

  /// Narrow and thin spaces become NBSP; every hyphen-minus becomes U+2212.
  static func normalise(_ s: String) -> String {
    var out = String.UnicodeScalarView()
    for scalar in s.unicodeScalars {
      switch scalar {
      case "\u{202F}", "\u{2009}": out.append("\u{00A0}")
      case "-": out.append("\u{2212}")
      default: out.append(scalar)
      }
    }
    return String(out)
  }

  /// Nil for a missing or blank code, otherwise the trimmed, uppercased code.
  static func resolvedCode(_ code: String?) -> String? {
    guard let trimmed = code?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
      return nil
    }
    return trimmed.uppercased()
  }

  private static let plainNumber = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))

  /// -0.0 would otherwise print as "−0.00".
  private static func cleanZero(_ value: Double) -> Double {
    value == 0 ? 0 : value
  }
}
