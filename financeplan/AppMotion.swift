import SwiftUI

/// Central motion tokens. Animations in the app should reference one of these
/// instead of inlining durations and curves, so identical interactions feel
/// identical everywhere.
enum AppMotion {
  /// Press feedback on buttons, cards, and rows.
  static let press: Animation = .easeOut(duration: 0.15)

  /// State changes: selection, toggles, loading crossfades, value updates.
  static let state: Animation = .snappy(duration: 0.25)

  /// Structural motion: step changes, banners, row insertion/removal.
  static let structural: Animation = .spring(response: 0.4, dampingFraction: 0.85)

  /// One-shot data reveals (chart draw-in). Critically damped — financial data
  /// should settle precisely, without overshoot.
  static let dataReveal: Animation = .spring(response: 0.55, dampingFraction: 0.9)

  /// Fallback when Reduce Motion is on: a short fade, no movement.
  static let reduced: Animation = .easeOut(duration: 0.15)

  /// Shared auto-dismiss lifetime for toasts and transient banners.
  static let toastLifetime: Duration = .seconds(3)
}

extension View {
  /// Reduce Motion–aware equivalent of `.animation(_:value:)`. Movement-based
  /// animations collapse to a short fade when the user has Reduce Motion on.
  func appAnimation(_ animation: Animation, value: some Equatable) -> some View {
    modifier(AppAnimationModifier(animation: animation, value: value))
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
