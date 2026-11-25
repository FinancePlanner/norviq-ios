import SwiftUI

// MARK: - Glass Shape

/// Describes which shape the glass effect should use.
enum GlassShape {
  case rect(cornerRadius: CGFloat)
  case capsule
  case circle
}

// MARK: - Backwards-compatible Glass Modifier

/// Glass for chrome and controls only (bars, toolbar items, chips, floating
/// buttons, the toast). Content uses `appCardSurface` instead.
///
/// - Reduce Transparency on: a solid chrome surface (`VigilTopBarBackground`
///   fill plus the separator stroke), on every OS version.
/// - iOS 26+: the native `.glassEffect(_:in:)`.
/// - Earlier: a fill + stroke + shadow fallback.
///
/// This file is the only place allowed to call the native Liquid Glass API
/// (`LiquidGlassTests.testNativeGlassAPIsOnlyInCompat`). It once resolved to a
/// module-level shim (`FutureCompatibility.swift`) that shadowed SwiftUI and
/// drew nothing; that shim is gone, and must not come back.
struct GlassEffectModifier: ViewModifier {
  let shape: GlassShape
  let tint: Color?
  let interactive: Bool

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  func body(content: Content) -> some View {
    if reduceTransparency {
      content
        .modifier(SolidChromeModifier(shape: shape, tint: tint))
    } else if #available(iOS 26, *) {
      content
        .modifier(NativeGlassModifier(shape: shape, tint: tint, interactive: interactive))
    } else {
      content
        .modifier(FallbackGlassModifier(shape: shape, tint: tint, colorScheme: colorScheme))
    }
  }
}

// MARK: - iOS 26+ Native

@available(iOS 26, *)
private struct NativeGlassModifier: ViewModifier {
  let shape: GlassShape
  let tint: Color?
  let interactive: Bool

  private var glass: Glass {
    let base = tint.map { Glass.regular.tint($0) } ?? .regular
    return interactive ? base.interactive() : base
  }

  func body(content: Content) -> some View {
    switch shape {
    case .rect(let cornerRadius):
      content
        .glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
    case .capsule:
      content
        .glassEffect(glass, in: .capsule)
    case .circle:
      content
        .glassEffect(glass, in: .circle)
    }
  }
}

// MARK: - Reduce Transparency

/// Solid chrome: `VigilTopBarBackground` plus the separator hairline. A tint
/// (for example a selected chip) is layered on top so selection stays visible.
private struct SolidChromeModifier: ViewModifier {
  let shape: GlassShape
  let tint: Color?

  func body(content: Content) -> some View {
    switch shape {
    case .rect(let cornerRadius):
      solid(content, RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    case .capsule:
      solid(content, Capsule())
    case .circle:
      solid(content, Circle())
    }
  }

  private func solid<S: Shape>(_ content: Content, _ shape: S) -> some View {
    content
      .background {
        ZStack {
          shape.fill(AppTheme.Colors.topBarBackground)
          if let tint {
            shape.fill(tint)
          }
        }
      }
      .overlay(shape.stroke(AppTheme.Colors.separator, lineWidth: 1))
  }
}

// MARK: - Pre-iOS 26 Fallback

private struct FallbackGlassModifier: ViewModifier {
  let shape: GlassShape
  let tint: Color?
  let colorScheme: ColorScheme

  private var fillColor: Color {
    tint ?? AppTheme.Colors.cardBackground(for: colorScheme)
  }

  private var strokeColor: Color {
    AppTheme.Colors.separator
      .opacity(colorScheme == .dark ? 0.38 : 0.18)
  }

  func body(content: Content) -> some View {
    switch shape {
    case .rect(let cornerRadius):
      content
        .background(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fillColor)
        )
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(strokeColor, lineWidth: 0.8)
        )
        .shadow(
          color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.05),
          radius: colorScheme == .dark ? 16 : 12,
          x: 0,
          y: colorScheme == .dark ? 10 : 6
        )

    case .capsule:
      content
        .background(
          Capsule()
            .fill(fillColor)
        )
        .overlay(
          Capsule()
            .stroke(strokeColor, lineWidth: 0.8)
        )
        .shadow(
          color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04),
          radius: 8, x: 0, y: 3
        )

    case .circle:
      content
        .background(
          Circle()
            .fill(fillColor)
        )
        .overlay(
          Circle()
            .stroke(strokeColor, lineWidth: 0.8)
        )
        .shadow(
          color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04),
          radius: 8, x: 0, y: 3
        )
    }
  }
}

// MARK: - View Extension

extension View {
  /// Glass for chrome and controls, with backwards compatibility and a solid
  /// Reduce Transparency fallback (see `GlassEffectModifier`). Never for
  /// content: cards, panels and rows use `appCardSurface`.
  func appGlassEffect(
    _ shape: GlassShape = .rect(cornerRadius: 24),
    tint: Color? = nil,
    interactive: Bool = false
  ) -> some View {
    modifier(GlassEffectModifier(shape: shape, tint: tint, interactive: interactive))
  }
}

// MARK: - Glass container and morphing IDs

/// `GlassEffectContainer` on iOS 26, so neighbouring glass shapes blend and
/// morph; plain `content` below, where there is nothing to blend.
struct AppGlassContainer<Content: View>: View {
  private let spacing: CGFloat
  private let content: Content

  init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
    self.spacing = spacing
    self.content = content()
  }

  var body: some View {
    if #available(iOS 26, *) {
      GlassEffectContainer(spacing: spacing) {
        content
      }
    } else {
      content
    }
  }
}

private struct GlassEffectIDModifier<ID: Hashable & Sendable>: ViewModifier {
  let id: ID
  let namespace: Namespace.ID

  func body(content: Content) -> some View {
    if #available(iOS 26, *) {
      content.glassEffectID(id, in: namespace)
    } else {
      content
    }
  }
}

extension View {
  /// `glassEffectID(_:in:)` on iOS 26 (glass morphs between elements sharing
  /// the namespace); a no-op below.
  func appGlassEffectID(_ id: some Hashable & Sendable, in ns: Namespace.ID) -> some View {
    modifier(GlassEffectIDModifier(id: id, namespace: ns))
  }
}

// MARK: - Solid content surface

extension View {
  /// The solid surface for content: cards, panels, list rows and sheet
  /// content blocks. A `VigilCardBackground` fill plus a 1pt `VigilSeparator`
  /// hairline, with no material and no shadow.
  ///
  /// DS 2.0 keeps native glass for chrome and controls only (tab bar,
  /// toolbars, the range control, floating controls). Content never uses
  /// `appGlassEffect`; it uses this.
  ///
  /// The hairline is a `strokeBorder` (drawn inside the shape), so a
  /// `.clipShape` after this modifier keeps its full 1pt width.
  func appCardSurface(cornerRadius: CGFloat = AppTheme.Radius.card) -> some View {
    background(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(AppTheme.Colors.cardBackground)
    )
    .overlay(
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .strokeBorder(AppTheme.Colors.separator, lineWidth: 1)
    )
  }
}
