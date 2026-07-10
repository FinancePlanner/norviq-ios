import SwiftUI

/// The single press-feedback style for tappable cards, rows, and buttons.
/// Replaces the former `CardButtonStyle` and `PressEffectStyle` so every
/// pressable element in the app responds the same way.
struct PressableStyle: ButtonStyle {
  var scale: CGFloat = 0.97

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? scale : 1.0)
      .opacity(configuration.isPressed ? 0.9 : 1.0)
      .animation(AppMotion.press, value: configuration.isPressed)
  }
}
