import SwiftUI

extension Font {
  @available(*, deprecated, message: "Use .typography(...) or system typography roles instead.")
  public static func avenir(size: CGFloat = 17, weight: TypographyFontWeight = .regular, isItalic: Bool = false) -> Font {
    let font = Font.system(size: size, weight: weight.fontWeight, design: .default)
    return isItalic ? font.italic() : font
  }
}

private extension TypographyFontWeight {
  var fontWeight: Font.Weight {
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
