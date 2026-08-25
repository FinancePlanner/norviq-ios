import SwiftUI

/// The card surface for the app. CANONICAL — every card-shaped surface should
/// go through this type.
///
/// `.vigilGlassCard()` (AppTheme.swift) was the other glass system: it rendered
/// as a FLAT `cardBackground` fill under Classic, with no stroke, shadow or
/// native glass, disagreeing with what this type already gave every other card.
/// It has been retired — all 11 of its former call sites now go through
/// `GlassCard`, whose
/// Classic side was left untouched, so this only changed Vigil's background
/// recipe plus the handful of sites where `.vigilGlassCard()` ran unconditionally.
///
/// `.appGlassEffect()` is the primitive underneath this type: the native
/// `.glassEffect` on iOS 26, a fill + separator stroke + shadow fallback below
/// it. Call it from surface types like this one, not from feature code.
///
/// Raw `.ultraThinMaterial` still has ~10 sites, but they are Circles, sheets
/// and the tab-bar capsule rather than cards, so they are not candidates here.
public struct GlassCard<Content: View>: View {
  private let cornerRadius: CGFloat
  private let padding: CGFloat?
  private let content: Content
  private let backgroundColor: Color?

  /// - Parameter padding: inset around `content`. `nil` keeps SwiftUI's adaptive
  ///   default, which is what every existing call site renders today.
  ///
  ///   Pass `0` when converting a `.vigilGlassCard()` site: that modifier adds no
  ///   padding of its own, so adopting the default here would silently inset the
  ///   content and change the layout. This parameter is what lets those 11 sites
  ///   move across with no visual change.
  public init(
    cornerRadius: CGFloat = 20,
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
      .appGlassEffect(.rect(cornerRadius: cornerRadius))
      .overlay {
        // Vigil differs from Classic by a bordered card — same flat shape, no
        // glow shadow.
        //
        // This used to stroke with the accent tint at 0.30/0.20. Across 143 call
        // sites that made neon cyan the outline of every surface in the app,
        // which is not what docs/vigil-identity.md asks for: it gives borders
        // their own token (#C5DBE2 / #14303A). `separator` is that token.
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(AppTheme.Colors.separator, lineWidth: 1)
      }
  }
}
