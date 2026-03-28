import SwiftUI

public struct GlowingButtonStyle: ButtonStyle {
  @Environment(\.colorScheme) private var colorScheme

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 15)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(AppTheme.Colors.tint(for: colorScheme))
      )
      .shadow(
        color: AppTheme.Colors.tint(for: colorScheme).opacity(configuration.isPressed ? 0.14 : 0.22),
        radius: configuration.isPressed ? 6 : 10,
        x: 0,
        y: configuration.isPressed ? 3 : 6
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
