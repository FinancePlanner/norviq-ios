import SwiftUI

/// The card surface for the app.
///
/// FOUR SYSTEMS, ONE CANONICAL
/// There are currently four ways to get a glassy surface, and they do not agree:
///
///   1. `GlassCard`              — this type. 75 call sites. CANONICAL.
///   2. `.vigilGlassCard()`      — 11 sites (AppTheme.swift). Background modifier,
///                                 adds no padding. Renders differently: under
///                                 Classic it is a FLAT `cardBackground` fill,
///                                 with no stroke, shadow or native glass.
///   3. `.appGlassEffect()`      — the primitive underneath this type. On iOS 26
///                                 it is the native `.glassEffect`; below that a
///                                 fill + separator stroke + shadow fallback.
///                                 Should be called from surface types, not from
///                                 feature code.
///   4. raw `.ultraThinMaterial` — 12 sites, but most are Circles, sheets and the
///                                 tab-bar capsule rather than cards, so they are
///                                 NOT candidates for this type.
///
/// Consolidating 1 and 2 is a VISUAL decision, not a mechanical one: swapping
/// this type's background to `VigilGlassBackground` (as was originally proposed)
/// would drop `appGlassEffect` and flatten Classic cards across all 75 sites —
/// on the brand docs/vigil-identity.md says must stay fully functional. That
/// change needs a screenshot comparison and is deliberately not made here.
///
/// This file's job for now is to make the migration *possible* without a layout
/// shift — see `padding`.
public struct GlassCard<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme
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
        if BrandTheme.current == .vigil {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
              AppTheme.Colors.tint(for: colorScheme).opacity(colorScheme == .dark ? 0.30 : 0.20),
              lineWidth: 1
            )
            .shadow(
              color: AppTheme.Colors.tint(for: colorScheme).opacity(colorScheme == .dark ? 0.18 : 0.08),
              radius: 12
            )
        }
      }
  }
}
