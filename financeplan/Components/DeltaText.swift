import SwiftUI

/// A change, always with its sign, a ▲/▼ glyph and (when known) its basis.
///
/// Direction is never carried by colour alone. Nil or non-finite input draws
/// nothing: a change with no number is hidden, not zeroed.
struct DeltaText: View {
  nonisolated enum Tone: Equatable {
    case gain, loss, flat
  }

  nonisolated struct Model: Equatable {
    let glyph: String
    let text: String
    let accessibilityLabel: String
    let tone: Tone

    /// Nil for a nil or non-finite fraction.
    nonisolated static func make(
      fraction: Double?,
      basis: String?,
      amount: Double?,
      currencyCode: String?,
      locale: Locale = MoneyFormatter.defaultLocale
    ) -> Model? {
      guard let fraction, fraction.isFinite else { return nil }

      let percent = MoneyFormatter.percentSigned(fraction, locale: locale)
      // Flat when it rounds to 0.0%: percentSigned prints no sign on zero.
      let isFlat = !percent.hasPrefix("+") && !percent.hasPrefix("\u{2212}")
      let tone: Tone = isFlat ? .flat : (fraction > 0 ? .gain : .loss)
      let glyph = switch tone {
      case .gain: "\u{25B2}"
      case .loss: "\u{25BC}"
      case .flat: "\u{2013}"
      }

      var body = percent
      if let amount, amount.isFinite {
        body += " \u{00B7} " + MoneyFormatter.signed(amount, currencyCode: currencyCode, locale: locale)
      }
      if let basis, !basis.isEmpty {
        body += " \(basis)"
      }

      let word = switch tone {
      case .gain: String(localized: "up")
      case .loss: String(localized: "down")
      case .flat: String(localized: "unchanged")
      }
      return Model(
        glyph: glyph,
        text: "\(glyph) \(body)",
        accessibilityLabel: "\(word) \(body)",
        tone: tone
      )
    }
  }

  let fraction: Double?
  let basis: String?
  let amount: Double?
  let currencyCode: String?

  init(fraction: Double?, basis: String? = nil, amount: Double? = nil, currencyCode: String? = nil) {
    self.fraction = fraction
    self.basis = basis
    self.amount = amount
    self.currencyCode = currencyCode
  }

  private func color(for tone: Tone) -> Color {
    switch tone {
    case .gain: AppTheme.Colors.gain
    case .loss: AppTheme.Colors.loss
    case .flat: AppTheme.Colors.flat
    }
  }

  var body: some View {
    if let model = Model.make(fraction: fraction, basis: basis, amount: amount, currencyCode: currencyCode) {
      Text(verbatim: model.text)
        .typography(.numeric)
        .monospacedDigit()
        .foregroundStyle(color(for: model.tone))
        .accessibilityLabel(model.accessibilityLabel)
    }
  }
}
