import SwiftUI
import UIKit

public struct TypographyStyle {
  public let type: Typography
  public var weight: TypographyFontWeight
  public var isItalic: Bool

  public init(
    _ type: Typography,
    weight: TypographyFontWeight? = nil,
    isItalic: Bool = false
  ) {
    self.type = type
    self.weight = weight ?? type.defaultWeight
    self.isItalic = isItalic
  }

  // swiftlint:disable switch_case_on_newline
  public var size: CGFloat {
    switch type {
    case .display: 56
    case .heading: 48
    case .displayNumber: 40
    case .hero: 32
    case .metricNumber, .title: 24
    case .headline: 20
    case .body, .numeric: 17
    case .small: 16
    case .mini: 15
    case .nano, .numericSmall: 13
    case .tiny: 13
    case .caption: 12
    case .footnote, .overline: 11
    case .button: 17
    case .label: 16
    case .code: 14
    case .link: 16
    }
  }

  // swiftlint:enable switch_case_on_newline

  public var relativeTextStyle: Font.TextStyle {
    switch type {
    case .display, .heading:
      .largeTitle
    case .displayNumber:
      .largeTitle
    case .hero:
      .title
    case .metricNumber, .title:
      .title2
    case .headline:
      .title3
    case .body, .numeric:
      .body
    case .small, .label, .button, .link:
      .callout
    case .mini, .nano, .numericSmall:
      .subheadline
    case .tiny, .caption:
      .caption
    case .footnote, .overline:
      .footnote
    case .code:
      .body
    }
  }

  public var isMonospaced: Bool {
    type == .code
  }

  public var usesTabularNumbers: Bool {
    switch type {
    case .displayNumber, .metricNumber, .numeric, .numericSmall:
      true
    default:
      false
    }
  }

  /// A system font at the exact `size` from the ladder above, made to scale with the
  /// user's Dynamic Type setting via `UIFontMetrics`. At the default text size the
  /// rendered size is unchanged from the previous fixed fonts, so this only *adds*
  /// accessibility scaling (Apple Guideline 4 — legible typography) without altering
  /// the design at the default setting. The clamp at the app root bounds extreme sizes.
  public var font: Font {
    let uiWeight: UIFont.Weight = isMonospaced ? .regular : weight.uiFontWeight
    let design: UIFontDescriptor.SystemDesign = isMonospaced ? .monospaced : .default

    var descriptor = UIFont.systemFont(ofSize: size, weight: uiWeight).fontDescriptor
    if let designed = descriptor.withDesign(design) {
      descriptor = designed
    }
    if isItalic {
      let traits = descriptor.symbolicTraits.union(.traitItalic)
      if let italicised = descriptor.withSymbolicTraits(traits) {
        descriptor = italicised
      }
    }

    let baseFont = UIFont(descriptor: descriptor, size: size)
    let scaled = UIFontMetrics(forTextStyle: relativeTextStyle.uiTextStyle).scaledFont(for: baseFont)
    return Font(scaled)
  }
}

private extension Font.TextStyle {
  /// Maps the SwiftUI text style used for relative scaling to its UIKit counterpart
  /// so `UIFontMetrics` can scale the custom point sizes.
  var uiTextStyle: UIFont.TextStyle {
    switch self {
    case .largeTitle: .largeTitle
    case .title: .title1
    case .title2: .title2
    case .title3: .title3
    case .headline: .headline
    case .subheadline: .subheadline
    case .body: .body
    case .callout: .callout
    case .footnote: .footnote
    case .caption: .caption1
    case .caption2: .caption2
    @unknown default: .body
    }
  }
}

private extension TypographyFontWeight {
  var uiFontWeight: UIFont.Weight {
    switch self {
    case .thin: .thin
    case .light: .light
    case .regular: .regular
    case .medium: .medium
    case .semibold: .semibold
    case .bold: .bold
    case .extraBold: .heavy
    case .black: .black
    }
  }
}
