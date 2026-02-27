import SwiftUI

public protocol FontScheme {
  var weight: TypographyFontWeight { get set }
  var isItalic: Bool { get set }
  var size: CGFloat { get set }

  var fontName: String { get }

  init(_ weight: TypographyFontWeight, isItalic: Bool, size: CGFloat)
}

extension FontScheme {
  public var font: Font {
    Font.custom(fontName, size: size)
  }

  public func italic() -> Self {
    configure(self) { $0.isItalic = true }
  }

  public func weight(_ weight: TypographyFontWeight) -> Self {
    configure(self) { $0.weight = weight }
  }
}
