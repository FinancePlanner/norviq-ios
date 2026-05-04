import SwiftUI

public struct GlassCard<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme
  private let cornerRadius: CGFloat
  private let content: Content
  private let backgroundColor: Color?

    public init(cornerRadius: CGFloat = 24, backgroundColor: Color? = nil, @ViewBuilder content: () -> Content) {
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
      }
}
