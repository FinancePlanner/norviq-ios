import SwiftUI

/// The card surface for the app. CANONICAL — every card-shaped surface should
/// go through this type.
///
/// `.vigilGlassCard()` (AppTheme.swift) was the other glass system: it rendered
/// as a FLAT `cardBackground` fill under Classic, with no stroke, shadow or
/// native glass, disagreeing with what this type already gave every other card.
/// It has been retired — all 11 of its former call sites now go through
/// `GlassCard`.
///
/// DS 2.0: cards are solid. The surface is `.appCardSurface(cornerRadius:)`, a
/// `VigilCardBackground` fill plus a 1pt `VigilSeparator` hairline. Native
/// Liquid Glass is for chrome and controls only, so this type never uses the
/// glass primitive. The name is historical (renamed `NorviqCard` in P5).
///
/// Raw `.ultraThinMaterial` still has ~10 sites, but they are Circles, sheets
/// and the tab-bar capsule rather than cards, so they are not candidates here.
public struct GlassCard<Content: View>: View {
  private let cornerRadius: CGFloat
  private let padding: CGFloat?
  private let content: Content
  private let backgroundColor: Color?

  /// - Parameter cornerRadius: `AppTheme.Radius.card` (16) by default, per spec
  ///   §5.3. Hero cards pass `AppTheme.Radius.hero` explicitly.
  /// - Parameter padding: inset around `content`. `nil` keeps SwiftUI's adaptive
  ///   default, which is what every existing call site renders today.
  ///
  ///   Pass `0` when converting a `.vigilGlassCard()` site: that modifier adds no
  ///   padding of its own, so adopting the default here would silently inset the
  ///   content and change the layout. This parameter is what lets those 11 sites
  ///   move across with no visual change.
  /// - Parameter backgroundColor: an optional tint layered above the solid fill.
  init(
    cornerRadius: CGFloat = AppTheme.Radius.card,
    padding: CGFloat? = nil,
    backgroundColor: Color? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.cornerRadius = cornerRadius
    self.padding = padding
    self.content = content()
    self.backgroundColor = backgroundColor
  }

  // `.padding()` and `.padding(16)` are not equivalent — the no-argument form is
  // adaptive — so the nil case must call it with no argument to stay byte-for-byte
  // identical to the previous behaviour.
  @ViewBuilder private var paddedContent: some View {
    if let padding {
      content.padding(padding)
    } else {
      content.padding()
    }
  }

  public var body: some View {
    paddedContent
      .background {
        if let backgroundColor {
          backgroundColor
            .clipShape(.rect(cornerRadius: cornerRadius))
        }
      }
      .clipShape(.rect(cornerRadius: cornerRadius))
      // Solid fill plus the separator hairline (#C5DBE2 / #14303A, the border
      // token from docs/vigil-identity.md). The stroke lives in appCardSurface,
      // so no second overlay here.
      .appCardSurface(cornerRadius: cornerRadius)
  }
}
