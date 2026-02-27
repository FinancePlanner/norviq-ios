import SwiftUI

extension View {
  @ViewBuilder
  public func typography(_ style: TypographyStyle) -> some View {
    if style.type == .overline {
      textCase(.uppercase)
        .tracking(1.2)
        .font(style.font)
    } else if style.type == .link {
      foregroundStyle(.tint)
        .underline()
        .font(style.font)
    } else {
      font(style.font)
    }
  }

  public func typography(_ type: Typography, weight: TypographyFontWeight? = nil, isItalic: Bool = false) -> some View {
    typography(TypographyStyle(type, weight: weight, isItalic: isItalic))
  }
}
