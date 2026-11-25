import SwiftUI

/// A labelled figure on a solid tile: label, value, optional caption (DS 2.0 P2b).
///
/// Tone colours the value only. Direction is never carried by the colour
/// alone, so a signed value or an arrow belongs in `value` itself.
struct MetricTile: View {
  enum Tone {
    case neutral, gain, loss, warning
  }

  let label: LocalizedStringKey
  let value: String
  /// Shown verbatim: the caller passes it already formatted or localized.
  let caption: String?
  let tone: Tone

  init(_ label: LocalizedStringKey, value: String, caption: String? = nil, tone: Tone = .neutral) {
    self.label = label
    self.value = value
    self.caption = caption
    self.tone = tone
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
        .typography(.metricNumber)
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
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(AppTheme.Spacing.md)
    .background(
      AppTheme.Colors.elevatedCardBackground,
      in: RoundedRectangle(cornerRadius: AppTheme.Radius.control)
    )
    .accessibilityElement(children: .combine)
  }
}
