import SwiftUI

public struct GlowingButtonStyle: ButtonStyle {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 15)
      .appGlassEffect(
        .rect(cornerRadius: 16),
        tint: AppTheme.Colors.tint(for: colorScheme),
        interactive: true
      )
      .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.98 : 1)
      .opacity(configuration.isPressed ? 0.9 : 1.0)
      .animation(AppMotion.press, value: configuration.isPressed)
  }
}

public struct GlowingButton: View {
    let title: String
    let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(title, action: action)
            .buttonStyle(GlowingButtonStyle())
            .font(.headline)
            .fontWeight(.bold)
    }
}
