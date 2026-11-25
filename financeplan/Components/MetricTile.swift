import SwiftUI

/// A labelled figure on a solid tile: label, value, optional caption (DS 2.0 P2b).
///
/// Tone colours the value only. Direction is never carried by the colour
/// alone, so a signed value or an arrow belongs in `value` itself.
struct MetricTile: View {
  enum Tone {
    case neutral, gain, loss, warning
  }

  /// `regular` is the 24pt headline figure. `compact` is the ~17pt numeric
  /// style for rows of three or more tiles, where a full money string such as
  /// "48 432,05 US$" must fit in about 80pt without shrinking below legibility.
  enum ValueStyle {
    case regular, compact
  }

  let label: LocalizedStringKey
  let value: String
  /// Shown verbatim: the caller passes it already formatted or localized.
  let caption: String?
  let tone: Tone
  let valueStyle: ValueStyle

  init(
    _ label: LocalizedStringKey,
    value: String,
    caption: String? = nil,
    tone: Tone = .neutral,
    valueStyle: ValueStyle = .regular
  ) {
    self.label = label
    self.value = value
    self.caption = caption
    self.tone = tone
    self.valueStyle = valueStyle
  }

  private var valueTypography: Typography {
    switch valueStyle {
    case .regular: .metricNumber
    case .compact: .numeric
    }
  }

  private var valueColor: Color {
    switch tone {
    case .neutral: AppTheme.Colors.foreground
    case .gain: AppTheme.Colors.gain
    case .loss: AppTheme.Colors.loss
    case .warning: AppTheme.Colors.warning
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
      Text(label)
        .typography(.label)
        .foregroundStyle(AppTheme.Colors.secondaryText)
        .lineLimit(2)
      Text(verbatim: value)
        .typography(valueTypography)
        .monospacedDigit()
        .foregroundStyle(valueColor)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      if let caption {
        Text(verbatim: caption)
          .typography(.caption)
          .foregroundStyle(AppTheme.Colors.tertiaryText)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(AppTheme.Spacing.md)
    .background(
      AppTheme.Colors.elevatedCardBackground,
      in: RoundedRectangle(cornerRadius: AppTheme.Radius.control)
    )
    .accessibilityElement(children: .combine)
  }
}
