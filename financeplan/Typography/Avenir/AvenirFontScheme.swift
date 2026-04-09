import SwiftUI

public struct AvenirFontScheme: FontScheme {
  public var weight: TypographyFontWeight
  public var isItalic: Bool
  public var size: CGFloat

  // swiftlint:disable switch_case_on_newline
  public var fontName: String {
    switch (weight, isItalic) {
    case (.thin, false): "AvenirNext-UltraLight"
    case (.thin, true): "AvenirNext-UltraLightItalic"
    case (.light, false): "AvenirNext-Regular"
    case (.light, true): "AvenirNext-Italic"
    case (.regular, false): "AvenirNext-Regular"
    case (.regular, true): "AvenirNext-Italic"
    case (.medium, false): "AvenirNext-Medium"
    case (.medium, true): "AvenirNext-MediumItalic"
    case (.semibold, false): "AvenirNext-DemiBold"
    case (.semibold, true): "AvenirNext-DemiBoldItalic"
    case (.bold, false): "AvenirNext-Bold"
    case (.bold, true): "AvenirNext-BoldItalic"
    case (.extraBold, false): "AvenirNext-Heavy"
    case (.extraBold, true): "AvenirNext-HeavyItalic"
    case (.black, false): "AvenirNext-Heavy"
    case (.black, true): "AvenirNext-HeavyItalic"
    }
  }

  // swiftlint:enable switch_case_on_newline

  public init(_ weight: TypographyFontWeight = .regular, isItalic: Bool = false, size: CGFloat = 15) {
    self.weight = weight
    self.isItalic = isItalic
    self.size = size
  }
}
