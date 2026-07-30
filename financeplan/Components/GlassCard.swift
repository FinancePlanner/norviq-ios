import SwiftUI

public struct GlassCard<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme
  private let cornerRadius: CGFloat
  private let content: Content
  private let backgroundColor: Color?

  public init(
    cornerRadius: CGFloat = 20,
    backgroundColor: Color? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.cornerRadius = cornerRadius
    self.content = content()
    self.backgroundColor = backgroundColor
  }

  public var body: some View {
    content
      .padding()
      .background {
        if let backgroundColor {
          backgroundColor
            .clipShape(.rect(cornerRadius: cornerRadius))
        }
      }
      .clipShape(.rect(cornerRadius: cornerRadius))
      .appGlassEffect(.rect(cornerRadius: cornerRadius))
      .overlay {
        if BrandTheme.current == .vigil {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
              AppTheme.Colors.tint(for: colorScheme).opacity(colorScheme == .dark ? 0.30 : 0.20),
              lineWidth: 1
            )
            .shadow(
              color: AppTheme.Colors.tint(for: colorScheme).opacity(colorScheme == .dark ? 0.18 : 0.08),
              radius: 12
            )
        }
      }
  }
}
