import SwiftUI

/// Central motion tokens. Animations in the app should reference one of these
/// instead of inlining durations and curves, so identical interactions feel
/// identical everywhere.
enum AppMotion {
  /// Press feedback on buttons, cards, and rows.
  static let press: Animation = .easeOut(duration: 0.15)

  /// State changes: selection, toggles, loading crossfades, value updates.
  static let state: Animation = .snappy(duration: 0.2)

  /// Structural motion: step changes, banners, row insertion/removal.
  static let structural: Animation = .spring(response: 0.32, dampingFraction: 1)

  /// One-shot data reveals (chart draw-in). Financial data should settle
  /// precisely and without overshoot.
  static let dataReveal: Animation = .easeOut(duration: 0.24)

  /// Fallback when Reduce Motion is on: a short fade, no movement.
  static let reduced: Animation = .easeOut(duration: 0.15)

  /// Shared auto-dismiss lifetime for toasts and transient banners.
  static let toastLifetime: Duration = .seconds(3)
}

extension View {
  /// Reduce Motion–aware equivalent of `.animation(_:value:)`.
  /// Moving transitions must still choose an opacity-only `AppTransition`.
  func appAnimation(_ animation: Animation, value: some Equatable) -> some View {
    modifier(AppAnimationModifier(animation: animation, value: value))
  }
}

enum AppTransition {
  static func move(edge: Edge, reduceMotion: Bool) -> AnyTransition {
    reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
  }

  static func directional(
    insertion: Edge,
    removal: Edge,
    reduceMotion: Bool
  ) -> AnyTransition {
    guard !reduceMotion else { return .opacity }
    return .asymmetric(
      insertion: .move(edge: insertion).combined(with: .opacity),
      removal: .move(edge: removal).combined(with: .opacity)
    )
  }
}

private struct AppAnimationModifier<V: Equatable>: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let animation: Animation
  let value: V

  func body(content: Content) -> some View {
    content.animation(reduceMotion ? AppMotion.reduced : animation, value: value)
  }
}
