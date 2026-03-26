import SwiftUI

public struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let cornerRadius: CGFloat
    private let content: Content

    public init(cornerRadius: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.Colors.cardBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.65),
                                Color.clear,
                                Color.black.opacity(colorScheme == .dark ? 0.08 : 0.04),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08),
                radius: colorScheme == .dark ? 18 : 12,
                x: 0,
                y: 8
            )
    }
}
