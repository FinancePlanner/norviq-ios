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
            AppTheme.Colors.separator(for: colorScheme).opacity(colorScheme == .dark ? 0.38 : 0.18),
            lineWidth: 0.8
          )
      )
      .shadow(
        color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.05),
        radius: colorScheme == .dark ? 16 : 12,
        x: 0,
        y: colorScheme == .dark ? 10 : 6
      )
  }
}
