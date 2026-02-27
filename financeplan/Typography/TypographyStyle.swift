import SwiftUI

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
    case .hero: 32
    case .title: 24
    case .headline: 20
    case .body: 17
    case .small: 16
    case .mini: 15
    case .nano: 13
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
    case .hero:
      .title
    case .title:
      .title2
    case .headline:
      .title3
    case .body:
      .body
    case .small, .label, .button, .link:
      .callout
    case .mini, .nano:
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

  public var font: Font {
    if isMonospaced {
      .system(size: size, weight: .regular, design: .monospaced)
    } else {
      .custom(
        AvenirFontScheme(weight, isItalic: isItalic, size: size).fontName,
        size: size,
        relativeTo: relativeTextStyle
      )
    }
  }
}
