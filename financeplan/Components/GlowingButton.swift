import SwiftUI

public struct GlowingButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.tint(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(
                color: AppTheme.Colors.tint(for: colorScheme).opacity(
                    configuration.isPressed ? 0.3 : 0.6),
                radius: configuration.isPressed ? 10 : 20,
                x: 0,
                y: configuration.isPressed ? 5 : 10
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
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
