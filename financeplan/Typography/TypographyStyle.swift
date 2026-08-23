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
    // 15, not 16. The ladder used to run 17/16/16/16 at the top and
    // 13/13/13/13/12/11 at the bottom, so "one step quieter than body" was a 1pt
    // difference nobody could see — which is how a 13pt title ended up above a
    // 12pt subtitle in the stock metric rows. 17/15/13/12/11 reads as steps.
    case .small, .mini: 15
    case .nano, .numericSmall, .tiny, .code: 13
    case .caption: 12
    case .footnote, .overline: 11
    case .button: 17
    case .label: 15
    case .link: 15
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

  /// Font *design* axis per role. One SF default design for both brands —
  /// no serif accent. Numeric/code roles keep their monospaced treatment as
  /// Vigil's one remaining typographic signature.
  public var fontDesign: UIFontDescriptor.SystemDesign {
    isMonospaced ? .monospaced : .default
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
    TypographyFontCache.shared.font(for: self)
  }

  /// Builds the font from scratch. Only `TypographyFontCache` should call this.
  fileprivate var uncachedFont: Font {
    let uiWeight: UIFont.Weight = isMonospaced ? .regular : weight.uiFontWeight
    let design: UIFontDescriptor.SystemDesign = fontDesign

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

/// Memoises resolved fonts.
///
/// `font` used to rebuild a `UIFontDescriptor`, apply a design trait and run
/// `UIFontMetrics.scaledFont(for:)` on *every* access, across ~660 `.typography(…)`
/// call sites — once per `Text` per body pass. Descriptor construction and metric
/// scaling are both meaningfully more expensive than a dictionary lookup.
///
/// The key includes the content size category because `scaledFont` resolves
/// against it; when the user changes text size the whole cache is dropped rather
/// than returning fonts scaled for the previous setting.
@MainActor
private final class TypographyFontCache {
  static let shared = TypographyFontCache()

  private struct Key: Hashable {
    let type: Typography
    let weight: TypographyFontWeight
    let isItalic: Bool
  }

  private var cache: [Key: Font] = [:]
  private var category: UIContentSizeCategory = .unspecified

  func font(for style: TypographyStyle) -> Font {
    let current = UITraitCollection.current.preferredContentSizeCategory
    if current != category {
      category = current
      cache.removeAll(keepingCapacity: true)
    }

    let key = Key(type: style.type, weight: style.weight, isItalic: style.isItalic)
    if let cached = cache[key] {
      return cached
    }
    let resolved = style.uncachedFont
    cache[key] = resolved
    return resolved
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
