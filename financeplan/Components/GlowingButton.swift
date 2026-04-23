import SwiftUI

public struct GlowingButtonStyle: ButtonStyle {
  @Environment(\.colorScheme) private var colorScheme

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
      .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
      .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
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
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
        }
        .buttonStyle(GlowingButtonStyle())
    }
}
